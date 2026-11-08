import 'dart:io';
import 'dart:math' as math;

import 'package:app_insights/app_insights.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/illustrations.dart';
import '../app_scope.dart';
import '../account/community_api.dart';
import '../catalog/achievements.dart';
import '../catalog/log_flow_prefs.dart';
import '../catalog/log_photos.dart';
import '../catalog/productions.dart';
import '../catalog/ticket_scan.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/community_widgets.dart';
import '../widgets/form_parts.dart';
import '../widgets/pon_stamp.dart';
import '../widgets/ticket_stub.dart';
import 'log_edit_screen.dart';
import 'share_card_screen.dart';

enum _Step { title, place, rating, photos }

/// 観た舞台を、題名（チケットの読み取りも）→ いつ・どこで → 評価と感想 → 写真の順に聞いて記録する。題名のあとは、どこからでも半券を切れる
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, this.play, this.showPhotos = true});
  final Play? play;
  final bool showPhotos;

  static Future<void> open(BuildContext context, {Play? play}) async {
    final showPhotos = await LogFlowPrefs.showsPhotos();
    if (!context.mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      // 下に払っただけで入力が消えないようにする。閉じるのは × から
      enableDrag: false,
      backgroundColor: Palette.paper,
      routeSettings: const RouteSettings(name: 'quick_log'),
      builder: (_) => QuickLogSheet(play: play, showPhotos: showPhotos),
    );
  }

  @override
  State<QuickLogSheet> createState() => QuickLogSheetState();
}

class QuickLogSheetState extends State<QuickLogSheet> {
  late final _title = TextEditingController(text: widget.play?.title);
  late Play? _play = widget.play;
  CurrentProduction? _production;
  int? _rating;
  final _note = TextEditingController();
  int _daysAgo = 0;
  DateTime? _pickedDate;

  /// 劇場の画面で選んだ・書いた劇場。無ければ公演かチケットの劇場を使う
  String? _pickedVenue;
  bool _changingVenue = false;
  final _venueQuery = TextEditingController();

  final _photos = <String>[];

  /// 読み取ったチケットの写真。記録の 1 枚目に入れ、写真の画面で外せる
  String? _ticketPhoto;
  bool _addingPhotos = false;
  String? _photoError;
  bool _saved = false;
  bool _photosHidden = false;

  /// チケットから読み取った内容。記録に入れる
  TicketScan? _scan;
  bool _scanning = false;
  String? _scanningPath;
  String? _scanError;
  ImageSource? _lastSource;

  late final List<_Step> _steps = [if (widget.play == null) _Step.title, _Step.place, _Step.rating, if (widget.showPhotos) _Step.photos];
  int _index = 0;
  bool _forward = true;
  _Step get _step => _steps[_index];
  bool get _isLast => _index == _steps.length - 1;
  bool get _hasTitle => _title.text.trim().isNotEmpty;

  void _rowsChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    ProductionStore.instance.addListener(_rowsChanged);
  }

  @override
  void dispose() {
    ProductionStore.instance.removeListener(_rowsChanged);
    // 記録せずに閉じたら、選んだ写真の控えを消す
    if (!_saved) {
      for (final name in _photos) {
        LogPhotos.delete(name);
      }
    }
    _title.dispose();
    _note.dispose();
    _venueQuery.dispose();
    super.dispose();
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  DateTime get _watchedOn => _pickedDate ?? _scan?.date ?? _today.subtract(Duration(days: _daysAgo));

  String? get _venue {
    if (_pickedVenue != null) return _pickedVenue;
    final p = _production;
    if (p != null && p.venueName.isNotEmpty) return p.venueName;
    return _scan?.venue?.name;
  }

  void _go(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _forward = index > _index;
      _index = index.clamp(0, _steps.length - 1);
    });
  }

  void _goTo(_Step step) {
    final i = _steps.indexOf(step);
    _go(i >= 0 ? i : _index + 1);
  }

  void _next() => _isLast ? _save() : _go(_index + 1);

  void _skip() {
    AppInsights.logEvent('log_flow_skip', parameters: {'step': _step.name});
    _next();
  }

  /// 写真の画面を次から出さない。最後の画面なので、記録は「半券を切る」まで切らない
  Future<void> _hidePhotos() async {
    AppInsights.logEvent('log_flow_hide', parameters: {'step': _Step.photos.name});
    await LogFlowPrefs.showPhotos(false);
    if (mounted) setState(() => _photosHidden = true);
  }

  Future<void> _scanTicket(ImageSource source) async {
    final scope = AppScope.of(context);
    _lastSource = source;
    setState(() => _scanError = null);
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 90);
    } catch (_) {
      if (mounted) setState(() => _scanError = 'カメラや写真を開けませんでした');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _scanningPath = picked!.path);
    final ok = await scanPath(picked.path, scope);
    if (!ok || !mounted) return;
    try {
      final name = await LogPhotos.save(File(picked.path));
      if (mounted) {
        adoptTicketPhoto(name);
      } else {
        LogPhotos.delete(name);
      }
    } catch (_) {
      // 写真を残せなくても、読み取った内容で記録はできる
    }
  }

  /// 読み取ったチケットの写真を 1 枚目に入れる。撮り直したら差し替える。テストからも呼ぶ
  @visibleForTesting
  void adoptTicketPhoto(String name) {
    final old = _ticketPhoto;
    setState(() {
      if (old != null) _photos.remove(old);
      if (_photos.length >= LogPhotos.maxPerEntry) _photos.removeLast();
      _photos.insert(0, name);
      _ticketPhoto = name;
    });
    if (old != null) LogPhotos.delete(old);
  }

  /// 選んだ写真を読み取る。読み取れたら true。テストからも呼ぶ
  @visibleForTesting
  Future<bool> scanPath(String path, AppScope scope) async {
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final lines = await TicketScanner.recognize(path);
      final scan = parseTicket(lines, venues: scope.catalog.venues, productions: ProductionStore.instance.rows, today: _today);
      if (!mounted) return false;
      AppInsights.logEvent('ticket_scan', parameters: {'production': scan.production == null ? 0 : 1, 'date': scan.date == null ? 0 : 1, 'venue': scan.venue == null ? 0 : 1});
      if (scan.isEmpty) {
        setState(() => _scanError = '読み取れませんでした。明るい場所で、チケット全体を撮ってください');
        return false;
      }
      setState(() {
        _scan = scan;
        if (scan.production != null) {
          _production = scan.production;
          _title.text = scan.production!.title;
          _play = null;
        }
      });
      // 公演まで分かれば、劇場の確認へ進む。分からなければ、この画面で題名の候補から選ぶ
      if (scan.production != null) _goTo(_Step.place);
      return true;
    } catch (_) {
      if (mounted) setState(() => _scanError = '読み取れませんでした。明るい場所で、チケット全体を撮ってください');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanningPath = null;
        });
      }
    }
  }

  void _select(CurrentProduction p) {
    HapticFeedback.selectionClick();
    setState(() {
      _production = p;
      _title.text = p.title;
      _play = null;
    });
    _goTo(_Step.place);
  }

  Future<void> _register() async {
    final picked = await showModalBottomSheet<Production>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      routeSettings: const RouteSettings(name: 'production_pick'),
      builder: (_) => ProductionPicker(initialQuery: _title.text.trim()),
    );
    if (picked == null || !mounted) return;
    _select(CurrentProduction(id: picked.id, title: picked.title, venueName: picked.venueName ?? '', groupName: picked.groupName, startDate: picked.startDate, endDate: picked.endDate));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _watchedOn, firstDate: DateTime(1950), lastDate: _today.add(const Duration(days: 1)));
    if (picked != null && mounted) setState(() => _pickedDate = DateUtils.dateOnly(picked));
  }

  void _rate(int i) {
    HapticFeedback.selectionClick();
    setState(() => _rating = _rating == i ? null : i);
  }

  /// 残りの枚数まで、まとめて選べる
  Future<void> _addPhotos() async {
    final room = LogPhotos.maxPerEntry - _photos.length;
    if (room <= 0 || _addingPhotos) return;
    setState(() {
      _addingPhotos = true;
      _photoError = null;
    });
    try {
      final picked = room == 1
          ? [?await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85)]
          : await ImagePicker().pickMultiImage(maxWidth: 2000, imageQuality: 85, limit: room);
      final names = <String>[];
      for (final x in picked.take(room)) {
        names.add(await LogPhotos.save(File(x.path)));
      }
      if (!mounted) {
        for (final n in names) {
          LogPhotos.delete(n);
        }
        return;
      }
      setState(() {
        _photos.addAll(names);
        if (picked.length > room) _photoError = '写真は 1 つの記録に ${LogPhotos.maxPerEntry} 枚までです。先の $room 枚を入れました';
      });
    } catch (_) {
      if (mounted) setState(() => _photoError = '写真を読み込めませんでした。写真へのアクセスを許可しているか確かめてください');
    } finally {
      if (mounted) setState(() => _addingPhotos = false);
    }
  }

  void _removePhoto(String name) {
    setState(() {
      _photos.remove(name);
      if (_ticketPhoto == name) _ticketPhoto = null;
    });
    LogPhotos.delete(name);
  }

  /// 選んだ公演と、今の入力を記録の形にする
  TheaterLogEntry _entry(String id) {
    final title = _title.text.trim();
    final production = _production;
    final plays = AppScope.of(context).catalog.plays;
    final linked = production?.postId == null ? null : plays.where((p) => p.id == production!.postId).firstOrNull;
    final play = linked ?? (_play?.title == title ? _play : null);
    return TheaterLogEntry(
      id: id,
      title: title,
      watchedOn: _watchedOn,
      playId: play?.id,
      author: play?.author,
      group: production?.groupName,
      venue: _venue,
      productionId: production?.id,
      rating: _rating,
      note: _note.text.trim(),
      showTime: _scan?.showTime,
      seat: _scan?.seat,
      price: _scan?.price,
      photos: List.of(_photos),
    );
  }

  Future<void> _save() async {
    if (!_hasTitle || _saved) return;
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final before = scope.log.entries;
    final entry = _entry(DateTime.now().microsecondsSinceEpoch.toString());
    _saved = true;
    await scope.log.upsert(entry);
    HapticFeedback.mediumImpact();
    AppInsights.logEvent('log_flow_save', parameters: {'step': _step.name});
    final earned = newlyEarned(before, scope.log.entries);
    // 劇場が分かれば、劇場スタンプも一緒に押される
    final venue = scope.catalog.venues.where((v) => v.name == entry.venue).firstOrNull;
    final isNewVenue = venue != null && !before.any((e) => e.venue == venue.name);
    navigator.pop();
    navigator.push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'stub_stamped'),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => StubStampedScreen(entry: entry, earned: earned, venue: venue, isNewVenue: isNewVenue),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// 題名を入れたあとで閉じるときは、やめてよいか確かめる
  Future<void> _confirmClose() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('記録をやめますか？'),
        content: const Text('入力した内容は保存されません。'),
        actions: [
          TextButton(key: const Key('flow-quit'), onPressed: () => Navigator.pop(c, true), child: const Text('やめる')),
          TextButton(key: const Key('flow-continue'), onPressed: () => Navigator.pop(c, false), child: const Text('続ける')),
        ],
      ),
    );
    if (quit == true && mounted) {
      _title.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    return PopScope(
      canPop: !_hasTitle || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: SizedBox(
        height: media.size.height * 0.92,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
                    transitionBuilder: (child, animation) {
                      final fade = FadeTransition(opacity: animation, child: child);
                      if (reduceMotion) return fade;
                      // 進むときは右から、戻るときは左から少しだけ寄せる
                      final incoming = child.key == ValueKey(_step);
                      final dx = (_forward == incoming ? 12.0 : -12.0);
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (_, c) => Transform.translate(offset: Offset(dx * (1 - animation.value), 0), child: c),
                        child: fade,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _stepBody()),
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
    child: Row(
      children: [
        IconButton(
          key: const Key('flow-back'),
          tooltip: _index == 0 ? '閉じる' : '戻る',
          icon: Icon(_index == 0 ? Icons.close : Icons.chevron_left),
          onPressed: () => _index == 0 ? Navigator.of(context).maybePop() : _go(_index - 1),
        ),
        Text(
          '${_index + 1} / ${_steps.length}',
          key: const Key('flow-progress'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 2), color: i <= _index ? Palette.sumi : Palette.line),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (_hasTitle && !_isLast)
          TextButton(
            key: const Key('quick-save'),
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Palette.ink, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('ここで半券を切る', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          )
        else
          const SizedBox(width: 8),
      ],
    ),
  );

  Widget _bottomBar() {
    final Widget? left;
    final Widget right;
    final skip = TextButton(
      key: const Key('flow-skip'),
      onPressed: _scanning ? null : _skip,
      style: TextButton.styleFrom(foregroundColor: Palette.ink, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13)),
      child: const Text('スキップ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
    final finish = FilledButton(
      key: const Key('quick-finish'),
      style: FilledButton.styleFrom(backgroundColor: Palette.sumi, padding: const EdgeInsets.symmetric(vertical: 15)),
      onPressed: _hasTitle ? _save : null,
      child: const Text('半券を切る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
    FilledButton nextButton({bool enabled = true}) => FilledButton(
      key: const Key('flow-next'),
      style: FilledButton.styleFrom(backgroundColor: Palette.sumi, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13)),
      onPressed: enabled ? _next : null,
      child: const Text('次へ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
    switch (_step) {
      case _Step.title:
        left = null;
        right = nextButton(enabled: _hasTitle);
      case _Step.place:
        if (_isLast) return _bar(null, finish, full: true);
        left = null;
        right = _venue == null ? skip : nextButton();
      case _Step.rating:
        if (_isLast) return _bar(null, finish, full: true);
        left = null;
        right = _rating == null && _note.text.trim().isEmpty ? skip : nextButton();
      case _Step.photos:
        return _bar(null, finish, full: true);
    }
    return _bar(left, right);
  }

  Widget _bar(Widget? left, Widget right, {bool full = false}) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child: full ? SizedBox(width: double.infinity, child: right) : Row(children: [?left, const Spacer(), right]),
  );

  Widget _stepBody() => switch (_step) {
    _Step.title => _titleStep(),
    _Step.place => _placeStep(),
    _Step.rating => _ratingStep(),
    _Step.photos => _photoStep(),
  };

  // 問いは芝居のビラの太い書体で大きく。入力は罫線 1 本の上に書く（箱に入れない）
  static const _heading = TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 25, height: 1.3, color: Palette.sumi);
  static const _sub = TextStyle(fontSize: 13, height: 1.5, color: Palette.inkSoft);


  /// 題名が決まったあとの画面の上に、何の記録かを 1 行出す。押すと題名に戻る
  Widget _titleLine() {
    final canEdit = _steps.contains(_Step.title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: const Key('flow-title'),
        onTap: canEdit ? () => _goTo(_Step.title) : null,
        child: Text(
          _hasTitle ? '『${_title.text.trim()}』' : '題名はまだです',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft),
        ),
      ),
    );
  }

  /// 題名の画面の下に出す、チケットからの読み取り。任意
  /// 題名の下に置く、チケットからの読み取り。半券の形の枠に、撮る（大）と写真から（小）を並べる
  Widget _ticketPanel() {
    Widget half(Key key, IconData icon, String label, ImageSource src, {bool big = false}) => InkWell(
      key: key,
      onTap: _scanning ? null : () => _scanTicket(src),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: big ? 30 : 22, color: Palette.ink),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: big ? 15 : 12, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ],
        ),
      ),
    );
    return Column(
      key: const Key('quick-scan'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Text(
          'チケットがあれば',
          style: _sub.copyWith(fontWeight: FontWeight.w700, color: Palette.ink),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: CustomPaint(
            painter: const _TicketSlotPainter(split: 0.68),
            child: _scanning
                ? Row(
                    key: const Key('scan-progress'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_scanningPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.file(File(_scanningPath!), width: 44, height: 44, fit: BoxFit.cover, cacheWidth: 132, errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44)),
                        ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.ink)),
                      const SizedBox(width: 10),
                      const Text('読み取っています', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 68, child: half(const Key('scan-camera'), Icons.photo_camera_outlined, 'チケットを撮る', ImageSource.camera, big: true)),
                      Expanded(flex: 32, child: half(const Key('scan-library'), Icons.photo_library_outlined, '写真から', ImageSource.gallery)),
                    ],
                  ),
          ),
        ),
        if (_scanError != null) ...[
          const SizedBox(height: 10),
          Text(
            _scanError!,
            key: const Key('scan-error'),
            style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w700, color: Palette.ink),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('scan-retry'),
              onPressed: () => _scanTicket(_lastSource ?? ImageSource.camera),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('もう一度撮る'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text('題名・日付・劇場・座席を読み取って入れておきます。撮ったチケットは 1 枚目の写真になり、最後の画面で外せます。写真はこの端末の中だけに保存し、送信しません。', style: TextStyle(fontSize: 12, height: 1.6, color: Palette.inkSoft)),
      ],
    );
  }

  Widget _titleStep() {
    final q = _title.text.trim().toLowerCase();
    final plays = AppScope.of(context).catalog.plays;
    final production = _production;
    final selected = production != null || _play?.title == _title.text.trim();
    final hits = q.isEmpty || selected ? const <Play>[] : plays.where((p) => p.title.toLowerCase().contains(q) || p.author.toLowerCase().contains(q)).take(4).toList();
    final productionHits = selected ? const <ProductionHit>[] : suggestProductions(ProductionStore.instance.rows, _title.text, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('何を観ましたか？', style: _heading),
        const SizedBox(height: 8),
        TextField(
          key: const Key('quick-title'),
          controller: _title,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_hasTitle) _next();
          },
          onChanged: (text) => setState(() {
            if (_production != null && _production!.title != text.trim()) _production = null;
          }),
          style: fieldStyle,
          decoration: lineDecoration('公演名、劇団、劇場で探す'),
        ),
        if (_scan != null) _ScanSummary(scan: _scan!, watchedOn: _watchedOn, onClear: () => setState(() => _scan = null)),
        if (_scan != null && production == null && !_hasTitle && _scan!.titleCandidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'チケットから：',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft),
                  ),
                ),
                for (final (i, t) in _scan!.titleCandidates.indexed) ActionChip(key: Key('scan-title-$i'), label: Text(t), onPressed: () => setState(() => _title.text = t)),
              ],
            ),
          ),
        if (production != null) _SelectedProduction(production: production, onClear: () => setState(() => _production = null)),
        // 候補を探している間は候補を広く見せ、読み取りは畳む
        if (q.isEmpty || selected) Expanded(child: SingleChildScrollView(child: _ticketPanel())),
        if (q.isNotEmpty && !selected)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 6),
              children: [
                if (productionHits.any((h) => h.sharedTitle))
                  const Padding(
                    key: Key('production-shared-note'),
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '同じ題名の公演が複数あります。劇場を確かめて選んでください。',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.kaki),
                    ),
                  ),
                for (final h in productionHits) _ProductionTile(hit: h, onTap: () => _select(h.production)),
                if (hits.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '台本から',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft),
                    ),
                  ),
                for (final p in hits)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.title),
                    subtitle: Text(p.author),
                    onTap: () => setState(() {
                      _play = p;
                      _title.text = p.title;
                    }),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('候補になくても、そのまま記録できます。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                      ),
                      TextButton(key: const Key('production-register'), onPressed: _register, child: const Text('公演を登録')),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 「いつ」「どこで」の小見出し
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft),
    ),
  );

  /// 罫線の上に並べた選択肢。選んだものは太字にし、下に墨の線を引く
  Widget _tab(Key key, String text, bool selected, VoidCallback onTap) => InkWell(
    key: key,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      margin: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: selected ? Palette.sumi : Colors.transparent, width: 3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? Palette.sumi : Palette.inkSoft),
      ),
    ),
  );

  Widget _placeStep() {
    final production = _production;
    final outOfRun = production != null && production.includes(_watchedOn) == false;
    final venue = _venue;
    final searching = _changingVenue;
    // 劇場を探している間は、日付を畳んで候補を広く見せる
    final typing = searching && MediaQuery.viewInsetsOf(context).bottom > 0;
    const days = ['今日', '昨日', 'おととい'];
    final fixedDate = _pickedDate ?? _scan?.date;
    const rule = Divider(height: 1, thickness: 1.5, color: Palette.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleLine(),
        const Text('いつ、どこで観ましたか？', style: _heading),
        if (!typing) ...[
          const SizedBox(height: 22),
          _label('いつ'),
          if (fixedDate != null)
            Row(
              key: const Key('flow-date-fixed'),
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${fixedDate.year}年${fixedDate.month}月${fixedDate.day}日${_pickedDate == null && _scan?.showTime != null ? (_scan!.showTime == 'matinee' ? ' 昼の部' : ' 夜の部') : ''}',
                      style: fieldStyle,
                    ),
                  ),
                ),
                if (_pickedDate == null) const Text('チケットから', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                TextButton(key: const Key('flow-date-change'), onPressed: _pickDate, child: const Text('変える')),
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < days.length; i++) _tab(Key('flow-day-$i'), days[i], _daysAgo == i, () => setState(() => _daysAgo = i)),
                _tab(const Key('flow-date-pick'), '日付を選ぶ', false, _pickDate),
              ],
            ),
          rule,
          if (outOfRun)
            Padding(
              key: const Key('production-date-note'),
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'この公演の期間は ${production.dateLabel} です。観た日を確かめてください。',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.kaki),
              ),
            ),
        ],
        const SizedBox(height: 26),
        _label('どこで'),
        if (searching)
          Expanded(child: _venueSearch())
        else ...[
          InkWell(
            key: Key(venue == null ? 'venue-open' : 'flow-venue'),
            onTap: () => setState(() {
              _changingVenue = true;
              _venueQuery.clear();
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.place, size: 20, color: venue == null ? Palette.inkSoft : Palette.kaki),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      venue ?? '劇場を選ぶ',
                      style: venue == null ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFFA3A39D)) : fieldStyle,
                    ),
                  ),
                  if (venue != null)
                    const Text(
                      '変える',
                      key: Key('venue-change'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink),
                    ),
                ],
              ),
            ),
          ),
          rule,
        ],
      ],
    );
  }

  Widget _venueSearch() {
    final scope = AppScope.of(context);
    final recent = scope.log.recent((e) => e.venue).toSet();
    final q = _venueQuery.text.trim().toLowerCase();
    // 何も入れていないときは、最近行った劇場を少しだけ
    final hits = q.isEmpty
        ? scope.catalog.venues.where((v) => recent.contains(v.name)).take(5).toList()
        : scope.catalog.venues.where((v) => v.name.toLowerCase().contains(q) || v.prefecture.contains(q)).take(30).toList();
    final exact = hits.any((v) => v.name.toLowerCase() == q);
    void choose(String name) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _pickedVenue = name;
        _changingVenue = false;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('venue-query'),
          controller: _venueQuery,
          autofocus: true,
          style: fieldStyle,
          onChanged: (_) => setState(() {}),
          decoration: lineDecoration('劇場名か都道府県', prefix: const Icon(Icons.search, size: 20, color: Palette.ink)).copyWith(
            suffixIcon: TextButton(
              key: const Key('venue-cancel'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _changingVenue = false);
              },
              child: const Text('閉じる'),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4),
            children: [
              if (q.isEmpty && hits.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(
                    '最近行った劇場',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft),
                  ),
                ),
              for (final v in hits)
                InkWell(
                  key: Key('venue-hit-${v.id}'),
                  onTap: () => choose(v.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Palette.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.ink),
                          ),
                        ),
                        Text(v.prefecture, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                ),
              if (q.isNotEmpty && !exact)
                InkWell(
                  key: const Key('venue-free'),
                  onTap: () => choose(_venueQuery.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '「${_venueQuery.text.trim()}」と書いて記録',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink),
                        ),
                        const Text('一覧にない劇場は、劇場スタンプが付きません', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingStep() => ListView(
    children: [
      _titleLine(),
      const Text('どうでしたか？', style: _heading),
      const SizedBox(height: 16),
      Row(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              key: Key('quick-star-$i'),
              tooltip: '$i',
              iconSize: 46,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => _rate(i),
              icon: Icon((_rating ?? 0) >= i ? Icons.star : Icons.star_border, color: Palette.vermilion),
            ),
        ],
      ),
      const SizedBox(height: 22),
      _label('ひとこと（なくても大丈夫です）'),
      // 罫線のノートに書くように。行の高さと罫線の間隔をそろえる
      CustomPaint(
        painter: const RuledPainter(lineHeight: 30, lines: 4),
        child: TextField(
          key: const Key('quick-note'),
          controller: _note,
          minLines: 4,
          maxLines: 8,
          maxLength: 2000,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 16, height: 30 / 16, color: Palette.ink),
          decoration: const InputDecoration(
            hintText: '心に残った場面や役者のこと',
            hintStyle: TextStyle(fontSize: 16, height: 30 / 16, color: Color(0xFFA3A39D)),
            filled: false,
            isDense: true,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text('感想は自分だけが見られます。公開したいときは、記録の編集から公開できます。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
    ],
  );

  Widget _photoStep() => ListView(
    children: [
      _titleLine(),
      Row(
        children: [
          const Expanded(child: Text('写真を残す', style: _heading)),
          StageArt.album(key: const Key('art-album'), width: 76),
        ],
      ),
      const SizedBox(height: 4),
      Text(_ticketPhoto != null ? '読み取ったチケットを 1 枚目に入れました。要らなければ × で外せます。チラシや劇場の外観も足せます。' : 'チラシや劇場の外観など。あとからでも足せます。', style: _sub),
      const SizedBox(height: 4),
      const Text(
        '写真はこの端末の中だけに保存します。感想を公開しても、写真は公開・送信されません。',
        key: Key('flow-photo-private'),
        style: TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w600, color: Palette.ink),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, name) in _photos.indexed)
            Stack(
              key: Key('flow-photo-$i'),
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LogPhotoImage(name: name, size: 92),
                ),
                if (name == _ticketPhoto)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      key: const Key('flow-photo-ticket'),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      color: Palette.sumi,
                      child: const Text(
                        'チケット',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: IconButton.filled(
                    key: Key('flow-photo-remove-$i'),
                    tooltip: '外す',
                    iconSize: 14,
                    style: IconButton.styleFrom(backgroundColor: Palette.sumi, minimumSize: const Size(26, 26), padding: EdgeInsets.zero),
                    onPressed: () => _removePhoto(name),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          if (_photos.length < LogPhotos.maxPerEntry)
            SizedBox(
              width: 92,
              height: 92,
              child: OutlinedButton(
                key: const Key('flow-photo-add'),
                onPressed: _addingPhotos ? null : _addPhotos,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.ink,
                  backgroundColor: Palette.card,
                  side: const BorderSide(color: Palette.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.zero,
                ),
                child: _addingPhotos ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
              ),
            ),
        ],
      ),
      if (_photoError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_photoError!, style: const TextStyle(fontSize: 12, color: Palette.ink)),
        ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: _photosHidden
            ? const Text('次回から写真の画面は出しません', style: TextStyle(fontSize: 13, color: Palette.inkSoft))
            : TextButton(
                key: const Key('flow-hide-photos'),
                onPressed: _hidePhotos,
                style: TextButton.styleFrom(foregroundColor: Palette.inkSoft, padding: EdgeInsets.zero),
                child: const Text('次回から出さない', style: TextStyle(fontSize: 13)),
              ),
      ),
    ],
  );
}

/// 候補の 1 行。公演名と劇場名をセットで見せる
class _ProductionTile extends StatelessWidget {
  const _ProductionTile({required this.hit, required this.onTap});
  final ProductionHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = hit.production;
    final sub = [p.groupName, p.dateLabel].whereType<String>().where((t) => t.isNotEmpty).join('・');
    return InkWell(
      key: Key('production-hit-${p.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: Palette.kaki),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          [p.venueName, if (p.prefecture != null) '（${p.prefecture}）'].join(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: hit.sharedTitle ? FontWeight.w800 : FontWeight.w600, color: Palette.navy),
                        ),
                      ),
                    ],
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
                    ),
                ],
              ),
            ),
            if (hit.running)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Palette.moegi, borderRadius: BorderRadius.circular(3)),
                child: const Text(
                  '上演中',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// チケットから読み取った内容。記録の前に確かめられるように並べる
class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.scan, required this.watchedOn, required this.onClear});
  final TicketScan scan;
  final DateTime watchedOn;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (scan.date != null)
        '${watchedOn.month}/${watchedOn.day}${scan.showTime == null
            ? ''
            : scan.showTime == 'matinee'
            ? ' 昼'
            : ' 夜'}',
      if (scan.production == null && scan.venue != null) scan.venue!.name,
      ?scan.seat,
      if (scan.price != null) '${scan.price}円',
    ];
    return Container(
      key: const Key('scan-summary'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
      decoration: BoxDecoration(color: const Color(0xFFEDEDE8), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_outlined, size: 18, color: Palette.ink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              items.isEmpty ? 'チケットから読み取りました' : 'チケットから: ${items.join('・')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.ink),
            ),
          ),
          IconButton(key: const Key('scan-clear'), tooltip: '読み取った内容を外す', icon: const Icon(Icons.close, size: 18), onPressed: onClear),
        ],
      ),
    );
  }
}

/// 選んだ公演。劇場と劇団がそのまま記録に入る
class _SelectedProduction extends StatelessWidget {
  const _SelectedProduction({required this.production, required this.onClear});
  final CurrentProduction production;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final detail = [production.venueName, production.groupName, production.dateLabel].whereType<String>().where((t) => t.isNotEmpty).join('・');
    return Container(
      key: const Key('production-selected'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, size: 18, color: Palette.kaki),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.navy),
            ),
          ),
          IconButton(key: const Key('production-clear'), tooltip: '公演を外す', icon: const Icon(Icons.close, size: 18), onPressed: onClear),
        ],
      ),
    );
  }
}

/// 半券ができた瞬間。スタンプが押される
class StubStampedScreen extends StatefulWidget {
  const StubStampedScreen({super.key, required this.entry, required this.earned, this.venue, this.isNewVenue = false});
  final TheaterLogEntry entry;
  final List<Achievement> earned;

  /// 公演を選んで、劇場スタンプも一緒に押されたときの劇場
  final Venue? venue;
  final bool isNewVenue;

  @override
  State<StubStampedScreen> createState() => _StubStampedScreenState();
}

class _StubStampedScreenState extends State<StubStampedScreen> with TickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _c.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    final d = widget.entry.watchedOn;
    final nth = log.countInYear(d.year);
    final stubIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
    );
    final restIn = CurvedAnimation(parent: _c, curve: const Interval(0.65, 1));
    String two(int n) => n.toString().padLeft(2, '0');
    const message = TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w700, color: Palette.ink);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Palette.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) => Transform.translate(
                    // 押された勢いで半券が沈んで戻る
                    offset: Offset(0, math.sin(_shake.value * math.pi * 2) * 5 * (1 - _shake.value)),
                    child: child,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FadeTransition(
                        opacity: stubIn,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(stubIn),
                          child: TicketStub(entry: widget.entry, textInset: 20),
                        ),
                      ),
                      // もぎりの日付印。半券の右下にまたがって押す
                      Positioned(
                        right: -4,
                        bottom: -70,
                        child: PonStamp(
                          delay: const Duration(milliseconds: 420),
                          onImpact: () => _shake.forward(from: 0),
                          child: Transform.rotate(
                            angle: -0.16,
                            child: PonSeal(key: const Key('stamped-count'), size: 132, label: '観劇', sub: '${two(d.year % 100)}.${two(d.month)}.${two(d.day)}', bottom: '$nth本目'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 96),
                FadeTransition(
                  opacity: restIn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in widget.earned)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('スタンプ「${a.title}」が貯まりました', key: Key('earned-${a.id}'), textAlign: TextAlign.center, style: message),
                        ),
                      if (widget.venue != null)
                        Text(
                          widget.isNewVenue ? '${widget.venue!.name}のスタンプも押しました。${widget.venue!.prefecture}で初めての劇場です' : '${widget.venue!.name}のスタンプも押しました',
                          key: const Key('stamped-venue-auto'),
                          textAlign: TextAlign.center,
                          style: message.copyWith(fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: restIn,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('stamped-note'),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () {
                                final nav = Navigator.of(context);
                                nav.pop();
                                LogEditScreen.open(nav.context, entry: widget.entry);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('感想を書く'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () {
                                final nav = Navigator.of(context);
                                nav.pop();
                                ShareCardScreen.open(nav.context, widget.entry);
                              },
                              icon: const Icon(Icons.ios_share, size: 18),
                              label: const Text('シェアする'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('stamped-close'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('半券帳へ'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 点線で描いた半券の枠。[split] の位置に切り取り線と上下の切り込みを入れる
class _TicketSlotPainter extends CustomPainter {
  const _TicketSlotPainter({required this.split});
  final double split;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * split;
    const notch = 9.0;
    final body = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notch));
    final shape = Path.combine(PathOperation.difference, body, holes);
    canvas.drawPath(shape, Paint()..color = Palette.card);
    final dash = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final metric in shape.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), dash);
      }
    }
    for (double y = notch + 6; y < size.height - notch - 6; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketSlotPainter old) => old.split != split;
}

