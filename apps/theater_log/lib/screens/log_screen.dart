import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../catalog/log_photos.dart';
import '../catalog/log_stats.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/ticket_stub.dart';
import '../widgets/log_calendar.dart';
import '../widgets/pon_stamp.dart';
import 'account_screen.dart';
import 'log_edit_screen.dart';
import 'quick_log_sheet.dart';
import 'share_card_screen.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  /// 半券帳が写真の全面表示になっているか。下のタブを暗くするのに使う
  static final immersive = ValueNotifier<bool>(false);

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  bool _calendar = false;
  bool _list = false;
  String _query = '';
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _setImmersive(bool v) {
    if (LogScreen.immersive.value == v) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => LogScreen.immersive.value = v);
  }

  void _go(int i, int count) {
    if (i < 0 || i >= count) return;
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _openStory(int i) {
    setState(() {
      _list = false;
      _index = i;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(i);
    });
  }

  Future<void> _showDay(List<TheaterLogEntry> entries, Map<int, Play> byId) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    routeSettings: const RouteSettings(name: 'log_day'),
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 16),
        children: [for (final e in entries) _EntryCard(entry: e, play: byId[e.playId])],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final byId = {for (final p in scope.catalog.plays) p.id: p};
    return ListenableBuilder(
      listenable: scope.log,
      builder: (context, _) {
        final entries = scope.log.entries;
        final story = entries.isNotEmpty && !_list;
        _setImmersive(story);
        if (story) {
          if (_index >= entries.length) _index = entries.length - 1;
          return _Story(
            entries: entries,
            byId: byId,
            controller: _pages,
            index: _index,
            onPage: (i) => setState(() => _index = i),
            onStep: (d) => _go(_index + d, entries.length),
            onList: () => setState(() => _list = true),
          );
        }
        return _listView(scope, byId);
      },
    );
  }

  Widget _listView(AppScope scope, Map<int, Play> byId) {
    return Scaffold(
      floatingActionButton: ListenableBuilder(
        listenable: scope.log,
        builder: (context, _) => scope.log.entries.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                key: const Key('log-add'),
                heroTag: 'log-add',
                onPressed: () => QuickLogSheet.open(context),
                icon: const Icon(Icons.local_activity),
                label: const Text('観た！'),
              ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: scope.log,
          builder: (context, _) {
            final entries = scope.log.entries;
            final shown = entries.where((e) => logMatches(e, _query)).toList();
            final year = DateTime.now().year;
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '半券帳',
                          style: TextStyle(fontFamily: sealFont, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, color: Palette.sumi),
                        ),
                      ),
                      if (entries.isNotEmpty) IconButton(key: const Key('log-view-toggle'), tooltip: '写真で見る', onPressed: () => _openStory(0), icon: const Icon(Icons.photo_outlined)),
                      IconButton(
                        key: const Key('log-calendar-toggle'),
                        tooltip: _calendar ? '一覧で見る' : 'カレンダーで見る',
                        onPressed: () => setState(() => _calendar = !_calendar),
                        icon: Icon(_calendar ? Icons.view_agenda_outlined : Icons.calendar_month_outlined),
                      ),
                      IconButton(key: const Key('open-account'), tooltip: 'アカウント', onPressed: () => AccountScreen.open(context), icon: const Icon(Icons.person_outline)),
                    ],
                  ),
                ),
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text.rich(
                      key: const Key('log-count'),
                      TextSpan(
                        style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                        children: [
                          TextSpan(text: '$year年 '),
                          TextSpan(
                            text: '${scope.log.countInYear(year)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.sumi),
                          ),
                          const TextSpan(text: ' 本　これまで '),
                          TextSpan(
                            text: '${entries.length}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink),
                          ),
                          const TextSpan(text: ' 本'),
                        ],
                      ),
                    ),
                  ),
                if (_calendar) LogCalendar(entries: entries, onDay: (day) => _showDay(day, byId)),
                if (!_calendar && entries.length >= 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      key: const Key('log-search'),
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: '作品・劇団・劇場・感想から探す',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Palette.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Palette.line),
                        ),
                      ),
                    ),
                  ),
                if (entries.isEmpty)
                  const _FirstStub()
                else if (!_calendar)
                  for (final e in shown) _EntryCard(entry: e, play: byId[e.playId], onTap: () => _openStory(entries.indexOf(e))),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.play, this.onTap});
  final TheaterLogEntry entry;
  final Play? play;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TicketStub(
          showSeal: true,
          entry: entry,
          onTap: onTap ?? () => LogEditScreen.open(context, entry: entry),
          trailing: IconButton(
            key: Key('log-card-${entry.id}'),
            tooltip: 'シェアカードを作る',
            icon: const Icon(Icons.ios_share, size: 18, color: Palette.inkSoft),
            onPressed: () => ShareCardScreen.open(context, entry),
          ),
        ),
        if (play != null)
          TextButton.icon(
            key: const Key('log-to-play'),
            style: TextButton.styleFrom(foregroundColor: Palette.moegi, padding: const EdgeInsets.only(left: 8), minimumSize: const Size(0, 32)),
            onPressed: () => launchUrl(play!.siteUrl, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.menu_book_outlined, size: 16),
            label: Text('この作品の台本（${play!.author}）', style: const TextStyle(fontSize: 13)),
          ),
      ],
    ),
  );
}

/// まだ 1 枚もないときの案内。やることを 1 つだけ見せる
class _FirstStub extends StatelessWidget {
  const _FirstStub();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    child: Column(
      children: [
        Opacity(
          opacity: 0.55,
          child: TicketStub(
            entry: TheaterLogEntry(id: 'sample', title: 'あなたの最初の一枚', watchedOn: DateTime.now()),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '観た舞台が、半券になって\nたまっていきます',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: titleFont, fontSize: 21, fontWeight: FontWeight.w700, height: 1.5, color: Palette.navy),
        ),
        const SizedBox(height: 10),
        const Text(
          '作品名と星だけ、3 秒で記録できます。\n行った劇場には、スタンプも押せます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Palette.inkSoft),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('first-stub'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
          onPressed: () => QuickLogSheet.open(context),
          child: const Text('最初の半券を切る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// 半券帳の写真表示。1 本につき 1 画面、横にめくって振り返る
class _Story extends StatelessWidget {
  const _Story({required this.entries, required this.byId, required this.controller, required this.index, required this.onPage, required this.onStep, required this.onList});
  final List<TheaterLogEntry> entries;
  final Map<int, Play> byId;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onStep;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final current = entries[index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const Key('log-story'),
              controller: controller,
              itemCount: entries.length,
              onPageChanged: onPage,
              itemBuilder: (context, i) => _StoryPage(entry: entries[i], play: byId[entries[i].playId], onStep: onStep),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Progress(count: entries.length, index: index),
                    Row(
                      children: [
                        const Text(
                          '半券帳',
                          style: TextStyle(fontFamily: sealFont, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${index + 1} / ${entries.length}',
                          key: const Key('story-position'),
                          style: const TextStyle(fontSize: 12, color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        const Spacer(),
                        IconButton(key: const Key('log-view-toggle'), tooltip: '一覧で見る', color: Colors.white, onPressed: onList, icon: const Icon(Icons.view_agenda_outlined)),
                        IconButton(key: const Key('open-account'), tooltip: 'アカウント', color: Colors.white, onPressed: () => AccountScreen.open(context), icon: const Icon(Icons.person_outline)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  IconButton(key: Key('log-card-${current.id}'), tooltip: 'シェアカードを作る', color: Colors.white, onPressed: () => ShareCardScreen.open(context, current), icon: const Icon(Icons.ios_share)),
                  IconButton(
                    key: const Key('story-edit'),
                    tooltip: '記録を直す',
                    color: Colors.white,
                    onPressed: () => LogEditScreen.open(context, entry: current),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('log-add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => QuickLogSheet.open(context),
                    icon: const Icon(Icons.local_activity, size: 18),
                    label: const Text('観た！', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 上の細い線。今どこを見ているか。本数が多いときは 1 本の線にする
class _Progress extends StatelessWidget {
  const _Progress({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    const on = Colors.white, off = Color(0x59FFFFFF);
    if (count > 24) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: (index + 1) / count, minHeight: 2.5, color: on, backgroundColor: off),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(color: i <= index ? on : off, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ],
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.entry, this.play, required this.onStep});
  final TheaterLogEntry entry;
  final Play? play;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final place = [?e.venue, ?e.seat].join('　');
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 左の 3 分の 1 を押すと前へ、それ以外は次へ
        onTapUp: (d) => onStep(d.localPosition.dx < c.maxWidth / 3 ? -1 : 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            e.photos.isNotEmpty ? _Photo(name: e.photos.first) : _TitleCover(entry: e, height: c.maxHeight),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.16, 0.4, 0.82],
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xE6000000)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(storyDate(e), style: const TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  Text(
                    e.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: sealFont, fontSize: 30, fontWeight: FontWeight.w800, height: 1.25, color: Colors.white),
                  ),
                  if (place.isNotEmpty || e.group != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const PonSeal(size: 26, label: 'ポン'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [if (place.isNotEmpty) place, ?e.group].join('　'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if ((e.rating ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Text('★' * e.rating! + '☆' * (5 - e.rating!), style: const TextStyle(fontSize: 14, letterSpacing: 2, color: Color(0xFFF1C24B))),
                  ],
                  if (e.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      e.note.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xE6FFFFFF)),
                    ),
                  ],
                  if (play != null)
                    TextButton.icon(
                      key: const Key('log-to-play'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                      onPressed: () => launchUrl(play!.siteUrl, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.menu_book_outlined, size: 16),
                      label: Text('この作品の台本（${play!.author}）', style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026年11月3日（火）マチネ
String storyDate(TheaterLogEntry e) {
  const w = ['月', '火', '水', '木', '金', '土', '日'];
  final d = e.watchedOn;
  final time = switch (e.showTime) {
    'matinee' => '　マチネ',
    'soiree' => '　ソワレ',
    _ => '',
  };
  return '${d.year}年${d.month}月${d.day}日（${w[d.weekday - 1]}）$time';
}

class _Photo extends StatelessWidget {
  const _Photo({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: LogPhotos.file(name),
    builder: (context, snap) => snap.hasData
        ? Image.file(
            snap.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
          )
        : const ColoredBox(color: Color(0xFF1A1A1A)),
  );
}

/// 写真がない記録の表紙。暗い幕に上からの明かり、題名を縦に組む
class _TitleCover extends StatelessWidget {
  const _TitleCover({required this.entry, required this.height});
  final TheaterLogEntry entry;
  final double height;

  static const _grounds = [Color(0xFF1C2826), Color(0xFF2A1915), Color(0xFF171E33), Color(0xFF241A2B), Color(0xFF22211D)];
  // 縦に組むと向きが変わる文字
  static const _turn = {'ー', '－', '-', '〜', '～', '…', '（', '）', '(', ')', '「', '」', '『', '』', '【', '】', '＝', '='};

  @override
  Widget build(BuildContext context) {
    final ground = _grounds[entry.title.runes.fold<int>(0, (a, r) => a + r) % _grounds.length];
    final chars = entry.title.characters.where((ch) => ch.trim().isNotEmpty).toList();
    final top = MediaQuery.paddingOf(context).top + 84;
    // 上の帯の下から、下の文字の手前まで（下の 45% は題名と感想を載せる）
    final area = height * 0.55 - top;
    final perColumn = (chars.length / (chars.length > 10 ? 2 : 1)).ceil().clamp(4, 10);
    final size = (area / perColumn / 1.12).clamp(26.0, 60.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ground,
        gradient: RadialGradient(center: const Alignment(0.35, -1.1), radius: 1.3, colors: [Color.lerp(ground, Colors.white, 0.16)!, ground]),
      ),
      child: Stack(
        children: [
          Positioned(
            top: top,
            right: 24,
            left: 24,
            height: area,
            child: Wrap(
              direction: Axis.vertical,
              textDirection: TextDirection.rtl,
              spacing: 0,
              runSpacing: size * 0.25,
              clipBehavior: Clip.hardEdge,
              children: [
                for (final ch in chars)
                  SizedBox(
                    width: size * 1.1,
                    height: size * 1.12,
                    child: Center(
                      child: _turn.contains(ch) ? RotatedBox(quarterTurns: 1, child: Text(ch, style: _style(size))) : Text(ch, style: _style(size)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _style(double size) => TextStyle(fontFamily: sealFont, fontSize: size, fontWeight: FontWeight.w800, height: 1, color: const Color(0xE6FFFFFF));
}
