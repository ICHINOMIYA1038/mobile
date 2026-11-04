import 'theater_log.dart';

class LogStats {
  LogStats._(this.count, this.spend, this.perMonth, this.topVenues, this.topGroups, this.averageRating);

  final int count;
  final int spend;

  /// 1 月〜12 月の本数
  final List<int> perMonth;
  final List<MapEntry<String, int>> topVenues;
  final List<MapEntry<String, int>> topGroups;
  final double? averageRating;

  factory LogStats.of(Iterable<TheaterLogEntry> entries, int year) {
    final inYear = entries.where((e) => e.watchedOn.year == year).toList();
    final months = List<int>.filled(12, 0);
    for (final e in inYear) {
      months[e.watchedOn.month - 1]++;
    }
    final ratings = inYear.map((e) => e.rating).whereType<int>().toList();
    return LogStats._(
      inYear.length,
      inYear.map((e) => e.price ?? 0).fold(0, (a, b) => a + b),
      months,
      _top(inYear.map((e) => e.venue)),
      _top(inYear.map((e) => e.group)),
      ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length,
    );
  }

  static List<MapEntry<String, int>> _top(Iterable<String?> values) {
    final counts = <String, int>{};
    for (final v in values.whereType<String>()) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return (counts.entries.toList()..sort((a, b) => b.value - a.value)).take(5).toList();
  }
}

/// 作品名・劇団・劇場・感想から探す
bool logMatches(TheaterLogEntry e, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [e.title, e.author, e.group, e.venue, e.note].whereType<String>().any((v) => v.toLowerCase().contains(q));
}
