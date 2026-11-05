import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../account/community_api.dart';
import '../catalog/achievements.dart';
import '../catalog/productions.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/community_widgets.dart';
import '../widgets/pon_stamp.dart';
import '../widgets/ticket_stub.dart';
import 'log_edit_screen.dart';
import 'share_card_screen.dart';
import 'venue_stamps_screen.dart';

/// 3 秒で記録する。作品名と星だけ。細かいことはあとから
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, this.play});
  final Play? play;

  static Future<void> open(BuildContext context, {Play? play}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Palette.paper,
    routeSettings: const RouteSettings(name: 'quick_log'),
    builder: (_) => QuickLogSheet(play: play),
  );

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  late final _title = TextEditingController(text: widget.play?.title);
  late Play? _play = widget.play;
  CurrentProduction? _production;
  int? _rating;
  int _daysAgo = 0;

  void _rowsChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    ProductionStore.instance.addListener(_rowsChanged);
  }

  @override
  void dispose() {
    ProductionStore.instance.removeListener(_rowsChanged);
    _title.dispose();
    super.dispose();
  }

  DateTime get _watchedOn => DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: _daysAgo));

  void _select(CurrentProduction p) {
    HapticFeedback.selectionClick();
    setState(() {
      _production = p;
      _title.text = p.title;
      _play = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
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
      venue: production == null || production.venueName.isEmpty ? null : production.venueName,
      productionId: production?.id,
      rating: _rating,
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final before = scope.log.entries;
    final entry = _entry(DateTime.now().microsecondsSinceEpoch.toString());
    await scope.log.upsert(entry);
    HapticFeedback.mediumImpact();
    final earned = newlyEarned(before, scope.log.entries);
    // 公演を選んだときは、劇場スタンプも一緒に押される
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

  @override
  Widget build(BuildContext context) {
    final q = _title.text.trim().toLowerCase();
    final plays = AppScope.of(context).catalog.plays;
    final production = _production;
    final selected = production != null || _play?.title == _title.text.trim();
    final hits = q.isEmpty || selected ? const <Play>[] : plays.where((p) => p.title.toLowerCase().contains(q) || p.author.toLowerCase().contains(q)).take(4).toList();
    final productionHits = selected ? const <ProductionHit>[] : suggestProductions(ProductionStore.instance.rows, _title.text, DateTime.now());
    final outOfRun = production != null && production.includes(_watchedOn) == false;
    final media = MediaQuery.of(context);
    // キーボードが開いて候補を探している間は、候補を広く見せる。選ぶと星と日付が戻る
    final searching = media.viewInsets.bottom > 0 && q.isNotEmpty && !selected;
    final listHeight = (media.size.height - media.viewInsets.bottom - media.padding.top - (searching ? 240 : 430)).clamp(110.0, 320.0);
    const days = ['今日', '昨日', 'おととい'];
    return SafeArea(
      // 小さな画面やキーボードの開閉の途中でもあふれないよう、スクロールできるようにする
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '何を観ましたか？',
              style: TextStyle(fontFamily: titleFont, fontSize: 22, fontWeight: FontWeight.w700, color: Palette.navy),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quick-title'),
              controller: _title,
              autofocus: widget.play == null,
              textInputAction: TextInputAction.done,
              onChanged: (text) => setState(() {
                if (_production != null && _production!.title != text.trim()) _production = null;
              }),
              decoration: InputDecoration(
                hintText: '公演名、劇団、劇場で探す',
                filled: true,
                fillColor: Palette.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Palette.line),
                ),
              ),
            ),
            if (production != null) _SelectedProduction(production: production, onClear: () => setState(() => _production = null)),
            if (q.isNotEmpty && !selected)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listHeight),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 6),
                  children: [
                    if (productionHits.any((h) => h.sharedTitle))
                      const Padding(
                        key: Key('production-shared-note'),
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '同じ題名の公演が複数あります。劇場を確かめて選んでください。',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.vermilion),
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
            if (!searching) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: Key('quick-star-$i'),
                      tooltip: '$i',
                      iconSize: 34,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = _rating == i ? null : i);
                      },
                      icon: Icon((_rating ?? 0) >= i ? Icons.star : Icons.star_border, color: Palette.vermilion),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < days.length; i++)
                    ChoiceChip(
                      label: Text(days[i], style: TextStyle(color: _daysAgo == i ? Colors.white : Palette.ink)),
                      selected: _daysAgo == i,
                      onSelected: (_) => setState(() => _daysAgo = i),
                    ),
                  ActionChip(
                    key: const Key('quick-more'),
                    label: const Text('くわしく書く'),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      final play = _play?.title == _title.text.trim() ? _play : null;
                      final draft = _entry('draft');
                      final label = _production == null ? null : [_production!.title, _production!.venueName].join('／');
                      navigator.pop();
                      LogEditScreen.open(navigator.context, play: play, draft: draft, productionLabel: label);
                    },
                  ),
                ],
              ),
              if (outOfRun)
                Padding(
                  key: const Key('production-date-note'),
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'この公演の期間は ${production.dateLabel} です。観た日を確かめてください。',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.vermilion),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('quick-save'),
                style: FilledButton.styleFrom(backgroundColor: Palette.vermilion, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _title.text.trim().isEmpty ? null : _save,
                child: const Text('半券を切る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                      const Icon(Icons.place, size: 14, color: Palette.vermilion),
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
                decoration: BoxDecoration(color: Palette.vermilion, borderRadius: BorderRadius.circular(10)),
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
          const Icon(Icons.place, size: 18, color: Palette.vermilion),
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
                    if (widget.entry.venue == null) ...[
                      FilledButton.icon(
                        key: const Key('stamped-venue'),
                        style: FilledButton.styleFrom(backgroundColor: Palette.vermilion),
                        onPressed: () async {
                          final venue = await VenuePickerSheet.open(context);
                          if (venue == null || !context.mounted) return;
                          final before = log.entries;
                          await log.upsert(widget.entry.copyWithVenue(venue.name));
                          if (!context.mounted) return;
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(
                            PageRouteBuilder<void>(
                              opaque: false,
                              barrierColor: Colors.black87,
                              settings: const RouteSettings(name: 'venue_stamped'),
                              pageBuilder: (_, _, _) => VenueStampedScreen(venue: venue, isNew: !before.any((e) => e.venue == venue.name), earned: newlyEarned(before, log.entries)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.place),
                        label: const Text('劇場スタンプを押す'),
                      ),
                      const SizedBox(height: 4),
                    ],
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
