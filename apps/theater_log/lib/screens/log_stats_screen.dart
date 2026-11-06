import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/log_stats.dart';
import '../theme.dart';

class LogStatsScreen extends StatefulWidget {
  const LogStatsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const LogStatsScreen(), settings: const RouteSettings(name: 'log_stats')),
  );

  @override
  State<LogStatsScreen> createState() => _LogStatsScreenState();
}

class _LogStatsScreenState extends State<LogStatsScreen> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final entries = AppScope.of(context).log.entries;
    final stats = LogStats.of(entries, _year);
    final top = stats.perMonth.fold(1, (a, b) => a > b ? a : b);
    Widget ranking(String title, List<MapEntry<String, int>> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
                const SizedBox(height: 6),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.key, style: const TextStyle(fontSize: 15))),
                        Text('${r.value} 本', style: const TextStyle(fontSize: 14, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('観劇の集計')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              IconButton(tooltip: '前の年', onPressed: () => setState(() => _year--), icon: const Icon(Icons.chevron_left)),
              Text('$_year年', key: const Key('stats-year'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(tooltip: '次の年', onPressed: _year >= DateTime.now().year ? null : () => setState(() => _year++), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Tile('観た本数', '${stats.count} 本')),
              const SizedBox(width: 8),
              Expanded(child: _Tile('チケット代', '¥${stats.spend.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+\b)'), (_) => ',')}')),
              const SizedBox(width: 8),
              Expanded(child: _Tile('平均の評価', stats.averageRating == null ? '−' : '★${stats.averageRating!.toStringAsFixed(1)}')),
            ],
          ),
          const SizedBox(height: 24),
          const Text('月ごとの本数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var m = 0; m < 12; m++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (stats.perMonth[m] > 0) Text('${stats.perMonth[m]}', style: const TextStyle(fontSize: 11, color: Palette.ink)),
                        Container(
                          height: 90.0 * stats.perMonth[m] / top + 2,
                          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          decoration: BoxDecoration(color: stats.perMonth[m] > 0 ? Palette.navy : Palette.line, borderRadius: BorderRadius.circular(2)),
                        ),
                        Text('${m + 1}', style: const TextStyle(fontSize: 11, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ranking('よく行く劇場', stats.topVenues),
          ranking('よく観る劇団', stats.topGroups),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Palette.card, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Palette.inkSoft)),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}
