import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/log_photos.dart';
import '../catalog/log_stats.dart';
import '../catalog/models.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/log_calendar.dart';
import 'log_edit_screen.dart';
import 'log_stats_screen.dart';
import 'play_screen.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log-add'),
        heroTag: 'log-add',
        backgroundColor: Palette.vermilion,
        foregroundColor: Colors.white,
        onPressed: () => LogEditScreen.open(context),
        icon: const Icon(Icons.edit),
        label: const Text('観劇を記録'),
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
                        child: Text('観劇ノート', style: TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, color: Palette.navy)),
                      ),
                      IconButton(key: const Key('log-calendar-toggle'), tooltip: _calendar ? '一覧で見る' : 'カレンダーで見る', onPressed: () => setState(() => _calendar = !_calendar), icon: Icon(_calendar ? Icons.view_agenda_outlined : Icons.calendar_month_outlined)),
                      IconButton(key: const Key('log-stats'), tooltip: '集計', onPressed: () => LogStatsScreen.open(context), icon: const Icon(Icons.bar_chart)),
                    ],
                  ),
                ),
                Padding(
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
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('観た舞台を記録しましょう。作品を選ぶと、人数や上演時間、台本の掲載先まで確かめられます。', style: TextStyle(height: 1.7, color: Palette.inkSoft)),
                  )
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
  Widget build(BuildContext context) {
    final d = entry.watchedOn;
    final place = [entry.group, entry.venue].whereType<String>().join('／');
    return Card(
      elevation: 0,
      color: Palette.card,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Palette.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => LogEditScreen.open(context, entry: entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${d.year}.${d.month}.${d.day}', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  const Spacer(),
                  if (entry.rating != null) Text('★' * entry.rating!, style: const TextStyle(fontSize: 13, color: Palette.vermilion)),
                  IconButton(
                    key: Key('log-card-${entry.id}'),
                    tooltip: 'シェアカードを作る',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.ios_share, size: 18, color: Palette.inkSoft),
                    onPressed: () => ShareCardScreen.open(context, entry),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(entry.title, style: const TextStyle(fontFamily: titleFont, fontSize: 17, fontWeight: FontWeight.w700, color: Palette.ink)),
              if (place.isNotEmpty) ...[const SizedBox(height: 2), Text(place, style: const TextStyle(fontSize: 13, color: Palette.inkSoft))],
              if (entry.note.isNotEmpty) ...[const SizedBox(height: 8), Text(entry.note, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.ink))],
              if (entry.photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final name in entry.photos)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LogPhotoImage(name: name, size: 72)),
                        ),
                    ],
                  ),
                ),
              ],
              if (play != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('log-to-play'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Palette.vermilion),
                    onPressed: () => PlayScreen.open(context, play!),
                    icon: const Icon(Icons.menu_book_outlined, size: 17),
                    label: Text('この作品の台本情報（${play!.author}）'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
