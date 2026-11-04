import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/achievements.dart';
import '../catalog/log_stats.dart';
import '../theme.dart';
import 'log_stats_screen.dart';
import 'recap_screen.dart';
import 'venue_stamps_screen.dart';

class StampBookScreen extends StatelessWidget {
  const StampBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final items = achievementsOf(log.entries);
          final done = items.where((a) => a.earned).length;
          final year = DateTime.now().year;
          final stats = LogStats.of(log.entries, year);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text('スタンプ帳', style: TextStyle(fontFamily: titleFont, fontSize: 26, fontWeight: FontWeight.w700, color: Palette.navy)),
              const SizedBox(height: 12),
              if (log.entries.isNotEmpty) ...[
                FilledButton.icon(
                  key: const Key('open-recap'),
                  style: FilledButton.styleFrom(backgroundColor: Palette.navy, minimumSize: const Size.fromHeight(46)),
                  onPressed: () => RecapScreen.open(context),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('$year年のふりかえりを見る'),
                ),
                const SizedBox(height: 12),
              ],
              const VenueStampSummary(),
              const SizedBox(height: 16),
              const SizedBox(height: 4),
              Text('${items.length} 個のうち $done 個', key: const Key('stamp-count'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: [for (final a in items) _Stamp(a)],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: Palette.card,
                shape: RoundedRectangleBorder(side: const BorderSide(color: Palette.line), borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  key: const Key('open-stats'),
                  title: Text('$year年は ${stats.count} 本'),
                  subtitle: const Text('月ごとの本数、よく行く劇場、よく観る劇団'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => LogStatsScreen.open(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.a);
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final on = a.earned;
    return Tooltip(
      message: a.description,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: on ? Palette.card : const Color(0xFFEFE9DB), border: Border.all(color: on ? Palette.vermilion : Palette.line, width: on ? 2 : 1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(on ? Icons.verified : Icons.lock_outline, color: on ? Palette.vermilion : Palette.inkSoft, size: 28),
            const SizedBox(height: 6),
            Text(a.title, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w700, color: on ? Palette.ink : Palette.inkSoft)),
            const SizedBox(height: 2),
            Text(on ? a.description : '${a.current > a.goal ? a.goal : a.current} / ${a.goal}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.3, color: Palette.inkSoft)),
          ],
        ),
      ),
    );
  }
}
