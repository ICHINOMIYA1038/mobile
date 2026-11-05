import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../catalog/log_stats.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/ticket_stub.dart';
import '../widgets/log_calendar.dart';
import 'account_screen.dart';
import 'log_edit_screen.dart';
import 'quick_log_sheet.dart';
import 'share_card_screen.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  bool _calendar = false;
  String _query = '';

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
    return Scaffold(
      floatingActionButton: ListenableBuilder(
        listenable: scope.log,
        builder: (context, _) => scope.log.entries.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                key: const Key('log-add'),
                heroTag: 'log-add',
                backgroundColor: Palette.vermilion,
                foregroundColor: Colors.white,
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
                        child: Text('半券帳', style: TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, color: Palette.navy)),
                      ),
                      IconButton(key: const Key('log-calendar-toggle'), tooltip: _calendar ? '一覧で見る' : 'カレンダーで見る', onPressed: () => setState(() => _calendar = !_calendar), icon: Icon(_calendar ? Icons.view_agenda_outlined : Icons.calendar_month_outlined)),
                      IconButton(key: const Key('open-account'), tooltip: 'アカウント', onPressed: () => AccountScreen.open(context), icon: const Icon(Icons.person_outline)),
                    ],
                  ),
                ),
                if (entries.isNotEmpty) Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text('$year年は ${scope.log.countInYear(year)} 本／これまで ${entries.length} 本', key: const Key('log-count'), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink)),
                ),
                if (_calendar) LogCalendar(entries: entries, onDay: (day) => _showDay(day, byId)),
                if (!_calendar && entries.length >= 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      key: const Key('log-search'),
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(hintText: '作品・劇団・劇場・感想から探す', prefixIcon: const Icon(Icons.search), isDense: true, filled: true, fillColor: Palette.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line))),
                    ),
                  ),
                if (entries.isEmpty)
                  const _FirstStub()
                else if (!_calendar)
                  for (final e in shown) _EntryCard(entry: e, play: byId[e.playId]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.play});
  final TheaterLogEntry entry;
  final Play? play;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TicketStub(
          entry: entry,
          onTap: () => LogEditScreen.open(context, entry: entry),
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
            style: TextButton.styleFrom(foregroundColor: Palette.vermilion, padding: const EdgeInsets.only(left: 8), minimumSize: const Size(0, 32)),
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
          child: TicketStub(entry: TheaterLogEntry(id: 'sample', title: 'あなたの最初の一枚', watchedOn: DateTime.now())),
        ),
        const SizedBox(height: 28),
        const Text('観た舞台が、半券になって\nたまっていきます', textAlign: TextAlign.center, style: TextStyle(fontFamily: titleFont, fontSize: 21, fontWeight: FontWeight.w700, height: 1.5, color: Palette.navy)),
        const SizedBox(height: 10),
        const Text('作品名と星だけ、3 秒で記録できます。\n行った劇場には、スタンプも押せます。', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Palette.inkSoft)),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('first-stub'),
          style: FilledButton.styleFrom(backgroundColor: Palette.vermilion, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
          onPressed: () => QuickLogSheet.open(context),
          child: const Text('最初の半券を切る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
