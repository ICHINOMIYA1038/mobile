import 'dart:io';
import 'dart:math' as math;

import 'package:app_insights/app_insights.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
import '../widgets/pon_stamp.dart';
import '../widgets/ticket_stub.dart';
import 'log_edit_screen.dart';
import 'share_card_screen.dart';

enum _Step { ticket, title, place, rating, photos }

/// 観た舞台を 1 画面に 1 つずつ聞いて記録する。題名のあとは、どこからでも半券を切れる
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, this.play, this.showTicket = true, this.showPhotos = true});
  final Play? play;
  final bool showTicket;
  final bool showPhotos;

  static Future<void> open(BuildContext context, {Play? play}) async {
    final show = await LogFlowPrefs.load();
    if (!context.mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      // 下に払っただけで入力が消えないようにする。閉じるのは × から
      enableDrag: false,
      backgroundColor: Palette.paper,
      routeSettings: const RouteSettings(name: 'quick_log'),
      builder: (_) => QuickLogSheet(play: play, showTicket: show.ticket, showPhotos: show.photos),
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
  int _daysAgo = 0;
  DateTime? _pickedDate;

  /// 劇場の画面で選んだ・書いた劇場。無ければ公演かチケットの劇場を使う
  String? _pickedVenue;
  bool _changingVenue = false;
  final _venueQuery = TextEditingController();

  final _photos = <String>[];
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

  late final List<_Step> _steps = [
    if (widget.showTicket) _Step.ticket,
    if (widget.play == null) _Step.title,
    _Step.place,
    _Step.rating,
    if (widget.showPhotos) _Step.photos,
  ];
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

  Future<void> _hide(_Step step) async {
    AppInsights.logEvent('log_flow_hide', parameters: {'step': step.name});
    if (step == _Step.ticket) await LogFlowPrefs.showTicket(false);
    if (step == _Step.photos) await LogFlowPrefs.showPhotos(false);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('アカウントの「記録の手順」で戻せます')));
    // 写真の画面は最後なので、出さないにしても記録は押すまで切らない
    if (step == _Step.ticket) {
      _next();
    } else {
      setState(() => _photosHidden = true);
    }
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
    await scanPath(picked.path, scope);
  }

  /// 選んだ写真を読み取る。テストからも呼ぶ
  @visibleForTesting
  Future<void> scanPath(String path, AppScope scope) async {
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final lines = await TicketScanner.recognize(path);
      final scan = parseTicket(lines, venues: scope.catalog.venues, productions: ProductionStore.instance.rows, today: _today);
      if (!mounted) return;
      AppInsights.logEvent('ticket_scan', parameters: {'production': scan.production == null ? 0 : 1, 'date': scan.date == null ? 0 : 1, 'venue': scan.venue == null ? 0 : 1});
      if (scan.isEmpty) {
        setState(() => _scanError = '読み取れませんでした。明るい場所で、チケット全体を撮ってください');
        return;
      }
      setState(() {
        _scan = scan;
        if (scan.production != null) {
          _production = scan.production;
          _title.text = scan.production!.title;
          _play = null;
        }
      });
      // 公演まで分かれば、題名は聞かずに劇場の確認へ
      _goTo(scan.production != null || !_steps.contains(_Step.title) ? _Step.place : _Step.title);
    } catch (_) {
      if (mounted) setState(() => _scanError = '読み取れませんでした。明るい場所で、チケット全体を撮ってください');
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
    setState(() => _rating = i);
    if (_isLast) return;
    // 押した星が見えてから次へ
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _step == _Step.rating) _next();
    });
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
    setState(() => _photos.remove(name));
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
        opaque: false,
        barrierColor: Colors.black87,
        settings: const RouteSettings(name: 'stub_stamped'),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => StubStampedScreen(entry: entry, earned: earned, venue: venue, isNewVenue: isNewVenue),
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
        Text('${_index + 1} / ${_steps.length}', key: const Key('flow-progress'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: i <= _index ? Palette.sumi : Palette.line,
                  ),
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
    final skip = OutlinedButton(key: const Key('flow-skip'), onPressed: _scanning ? null : _skip, child: const Text('スキップ'));
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
      case _Step.ticket:
        left = TextButton(key: const Key('flow-hide-ticket'), onPressed: () => _hide(_Step.ticket), style: TextButton.styleFrom(foregroundColor: Palette.inkSoft), child: const Text('次回から出さない', style: TextStyle(fontSize: 13)));
        right = skip;
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
        right = _rating == null ? skip : nextButton();
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
    _Step.ticket => _ticketStep(),
    _Step.title => _titleStep(),
    _Step.place => _placeStep(),
    _Step.rating => _ratingStep(),
    _Step.photos => _photoStep(),
  };

  static const _heading = TextStyle(fontFamily: titleFont, fontSize: 22, fontWeight: FontWeight.w700, color: Palette.navy);
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.inkSoft, decoration: canEdit ? TextDecoration.underline : null, decorationColor: Palette.line),
        ),
      ),
    );
  }

  Widget _ticketStep() {
    Widget source(Key key, IconData icon, String label, ImageSource src) => Expanded(
      child: OutlinedButton(
        key: key,
        onPressed: _scanning ? null : () => _scanTicket(src),
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.ink,
          backgroundColor: Palette.card,
          padding: const EdgeInsets.symmetric(vertical: 22),
          side: const BorderSide(color: Palette.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(children: [Icon(icon, size: 30), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))]),
      ),
    );
    return ListView(
      children: [
        const Text('チケットを撮る', style: _heading),
        const SizedBox(height: 4),
        const Text('読み取った題名・日付・劇場・座席を、次の画面から入れておきます。', style: _sub),
        const SizedBox(height: 20),
        if (_scanning)
          Row(
            key: const Key('scan-progress'),
            children: [
              if (_scanningPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(_scanningPath!), width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 168, errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56)),
                ),
              const SizedBox(width: 12),
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              const Text('読み取っています', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          )
        else
          Row(
            children: [
              source(const Key('scan-camera'), Icons.photo_camera_outlined, '撮る', ImageSource.camera),
              const SizedBox(width: 12),
              source(const Key('scan-library'), Icons.photo_library_outlined, '写真から選ぶ', ImageSource.gallery),
            ],
          ),
        if (_scanError != null) ...[
          const SizedBox(height: 16),
          Text(_scanError!, key: const Key('scan-error'), style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: Palette.ink)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(key: const Key('scan-retry'), onPressed: () => _scanTicket(_lastSource ?? ImageSource.camera), child: const Text('もう一度撮る')),
              TextButton(key: const Key('scan-without'), onPressed: _next, child: const Text('チケットなしで進む')),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const Text('写真はこの端末の中で読むだけです。保存も送信もしません。', style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
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
        const SizedBox(height: 12),
        TextField(
          key: const Key('quick-title'),
          controller: _title,
          autofocus: !_hasTitle,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_hasTitle) _next();
          },
          onChanged: (text) => setState(() {
            if (_production != null && _production!.title != text.trim()) _production = null;
          }),
          decoration: InputDecoration(
            hintText: '公演名、劇団、劇場で探す',
            filled: true,
            fillColor: Palette.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
          ),
        ),
        if (_scan != null) _ScanSummary(scan: _scan!, watchedOn: _watchedOn, onClear: () => setState(() => _scan = null)),
        if (_scan != null && production == null && !_hasTitle && _scan!.titleCandidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('チケットから：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft))),
                for (final (i, t) in _scan!.titleCandidates.indexed) ActionChip(key: Key('scan-title-$i'), label: Text(t), onPressed: () => setState(() => _title.text = t)),
              ],
            ),
          ),
        if (production != null) _SelectedProduction(production: production, onClear: () => setState(() => _production = null)),
        if (q.isNotEmpty && !selected)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 6),
              children: [
                if (productionHits.any((h) => h.sharedTitle))
                  const Padding(
                    key: Key('production-shared-note'),
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('同じ題名の公演が複数あります。劇場を確かめて選んでください。', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.kaki)),
                  ),
                for (final h in productionHits) _ProductionTile(hit: h, onTap: () => _select(h.production)),
                if (hits.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('台本から', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft)),
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
                      const Expanded(child: Text('候補になくても、そのまま記録できます。', style: TextStyle(fontSize: 12, color: Palette.inkSoft))),
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

  Widget _placeStep() {
    final production = _production;
    final outOfRun = production != null && production.includes(_watchedOn) == false;
    final venue = _venue;
    final searching = venue == null || _changingVenue;
    // 劇場を探してキーボードが開いている間は、日付を畳んで候補を広く見せる
    final typing = searching && MediaQuery.viewInsetsOf(context).bottom > 0;
    const days = ['今日', '昨日', 'おととい'];
    final fixedDate = _pickedDate ?? _scan?.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleLine(),
        const Text('いつ、どこで観ましたか？', style: _heading),
        if (!typing) ...[
          const SizedBox(height: 14),
          if (fixedDate != null)
            Row(
              key: const Key('flow-date-fixed'),
              children: [
                Text(
                  '${fixedDate.month}/${fixedDate.day}${_pickedDate == null && _scan?.showTime != null ? (_scan!.showTime == 'matinee' ? ' 昼' : ' 夜') : ''}${_pickedDate == null ? '（チケットから）' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink),
                ),
                TextButton(key: const Key('flow-date-change'), onPressed: _pickDate, child: const Text('変える')),
              ],
            )
          else
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < days.length; i++)
                  ChoiceChip(
                    key: Key('flow-day-$i'),
                    label: Text(days[i], style: TextStyle(color: _daysAgo == i ? Colors.white : Palette.ink)),
                    selected: _daysAgo == i,
                    onSelected: (_) => setState(() => _daysAgo = i),
                  ),
                ActionChip(key: const Key('flow-date-pick'), label: const Text('日付を選ぶ'), onPressed: _pickDate),
              ],
            ),
          if (outOfRun)
            Padding(
              key: const Key('production-date-note'),
              padding: const EdgeInsets.only(top: 6),
              child: Text('この公演の期間は ${production.dateLabel} です。観た日を確かめてください。', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.kaki)),
            ),
        ],
        const SizedBox(height: 16),
        if (!searching)
          Container(
            key: const Key('flow-venue'),
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.line)),
            child: Row(
              children: [
                const Icon(Icons.place, size: 20, color: Palette.kaki),
                const SizedBox(width: 6),
                Expanded(child: Text(venue, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink))),
                TextButton(
                  key: const Key('venue-change'),
                  onPressed: () => setState(() {
                    _changingVenue = true;
                    _venueQuery.clear();
                  }),
                  child: const Text('変える'),
                ),
              ],
            ),
          )
        else
          Expanded(child: _venueSearch()),
      ],
    );
  }

  Widget _venueSearch() {
    final scope = AppScope.of(context);
    final recent = scope.log.recent((e) => e.venue).toSet();
    final q = _venueQuery.text.trim().toLowerCase();
    final hits = scope.catalog.venues.where((v) => q.isEmpty ? recent.contains(v.name) : v.name.toLowerCase().contains(q) || v.prefecture.contains(q)).take(30).toList();
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
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '劇場名か都道府県で探す',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            filled: true,
            fillColor: Palette.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4),
            children: [
              if (q.isEmpty && hits.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 6, bottom: 2), child: Text('最近行った劇場', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.inkSoft))),
              for (final v in hits)
                ListTile(
                  key: Key('venue-hit-${v.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(v.name, style: const TextStyle(fontSize: 15)),
                  subtitle: Text(v.prefecture),
                  trailing: recent.contains(v.name) ? const Icon(Icons.verified, color: Palette.vermilion, size: 18) : null,
                  onTap: () => choose(v.name),
                ),
              if (q.isNotEmpty && !exact)
                ListTile(
                  key: const Key('venue-free'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined, size: 20),
                  title: Text('「${_venueQuery.text.trim()}」で記録'),
                  subtitle: const Text('一覧にない劇場は、スタンプが付きません'),
                  onTap: () => choose(_venueQuery.text.trim()),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titleLine(),
      const Text('どうでしたか？', style: _heading),
      const SizedBox(height: 28),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              key: Key('quick-star-$i'),
              tooltip: '$i',
              iconSize: 48,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: () => _rate(i),
              icon: Icon((_rating ?? 0) >= i ? Icons.star : Icons.star_border, color: Palette.vermilion),
            ),
        ],
      ),
    ],
  );

  Widget _photoStep() => ListView(
    children: [
      _titleLine(),
      const Text('写真を残す', style: _heading),
      const SizedBox(height: 4),
      const Text('チラシや劇場の外観など。この端末の中だけに保存し、あとからでも足せます。', style: _sub),
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
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LogPhotoImage(name: name, size: 92)),
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
                style: OutlinedButton.styleFrom(foregroundColor: Palette.ink, backgroundColor: Palette.card, side: const BorderSide(color: Palette.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: EdgeInsets.zero),
                child: _addingPhotos ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
              ),
            ),
        ],
      ),
      if (_photoError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_photoError!, style: const TextStyle(fontSize: 12, color: Palette.ink))),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: _photosHidden
            ? const Text('次回から写真の画面は出しません', style: TextStyle(fontSize: 13, color: Palette.inkSoft))
            : TextButton(key: const Key('flow-hide-photos'), onPressed: () => _hide(_Step.photos), style: TextButton.styleFrom(foregroundColor: Palette.inkSoft, padding: EdgeInsets.zero), child: const Text('次回から出さない', style: TextStyle(fontSize: 13))),
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
      if (scan.date != null) '${watchedOn.month}/${watchedOn.day}${scan.showTime == null ? '' : scan.showTime == 'matinee' ? ' 昼' : ' 夜'}',
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
    final year = widget.entry.watchedOn.year;
    final nth = log.countInYear(year);
    final stubIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
    );
    final restIn = CurvedAnimation(parent: _c, curve: const Interval(0.65, 1));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: restIn,
                child: Text(
                  '$year年 $nth 本目',
                  key: const Key('stamped-count'),
                  style: const TextStyle(fontFamily: titleFont, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _shake,
                builder: (_, child) => Transform.translate(
                  // 押された勢いで半券が沈んで戻る
                  offset: Offset(0, math.sin(_shake.value * math.pi * 2) * 7 * (1 - _shake.value)),
                  child: child,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ScaleTransition(
                      scale: stubIn,
                      child: TicketStub(entry: widget.entry, textInset: 96),
                    ),
                    Positioned(
                      right: 6,
                      bottom: -44,
                      child: PonStamp(
                        delay: const Duration(milliseconds: 420),
                        wordAt: const Offset(-128, 58),
                        onImpact: () => _shake.forward(from: 0),
                        child: PonSeal(size: 100, label: '観劇済', sub: '${widget.entry.watchedOn.month}.${widget.entry.watchedOn.day}', fontSize: 21),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              FadeTransition(
                opacity: restIn,
                child: Column(
                  children: [
                    for (final a in widget.earned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'スタンプ獲得「${a.title}」',
                          key: Key('earned-${a.id}'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE9A23B)),
                        ),
                      ),
                    if (widget.venue != null)
                      Padding(
                        key: const Key('stamped-venue-auto'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          widget.isNewVenue ? '${widget.venue!.name}のスタンプも押しました\n${widget.venue!.prefecture}の新しい劇場！' : '${widget.venue!.name}のスタンプも押しました',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          key: const Key('stamped-note'),
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            LogEditScreen.open(nav.context, entry: widget.entry);
                          },
                          child: const Text('感想を書く', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            ShareCardScreen.open(nav.context, widget.entry);
                          },
                          child: const Text('シェアする', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('stamped-close'),
                          style: FilledButton.styleFrom(backgroundColor: Palette.paper, foregroundColor: Palette.navy),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
