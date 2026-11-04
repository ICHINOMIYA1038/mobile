import 'package:flutter/material.dart';

import '../catalog/theater_log.dart';
import '../theme.dart';

/// 観た日に印を付けた月のカレンダー
class LogCalendar extends StatefulWidget {
  const LogCalendar({super.key, required this.entries, required this.onDay});
  final List<TheaterLogEntry> entries;
  final ValueChanged<List<TheaterLogEntry>> onDay;

  @override
  State<LogCalendar> createState() => _LogCalendarState();
}

class _LogCalendarState extends State<LogCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final byDay = <int, List<TheaterLogEntry>>{};
    for (final e in widget.entries) {
      if (e.watchedOn.year == _month.year && e.watchedOn.month == _month.month) (byDay[e.watchedOn.day] ??= []).add(e);
    }
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    // 日曜始まり
    final lead = _month.weekday % 7;
    const week = ['日', '月', '火', '水', '木', '金', '土'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(tooltip: '前の月', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text('${_month.year}年${_month.month}月', key: const Key('calendar-month'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(tooltip: '次の月', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final w in week) Center(child: Text(w, style: const TextStyle(fontSize: 12, color: Palette.inkSoft))),
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++)
                InkWell(
                  key: Key('day-$d'),
                  onTap: byDay[d] == null ? null : () => widget.onDay(byDay[d]!),
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: byDay[d] == null ? null : const BoxDecoration(color: Palette.vermilion, shape: BoxShape.circle),
                      child: Text('$d', style: TextStyle(fontSize: 14, color: byDay[d] == null ? Palette.ink : Colors.white, fontWeight: byDay[d] == null ? FontWeight.normal : FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
