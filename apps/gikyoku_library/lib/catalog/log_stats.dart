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

/// 年間ふりかえりの中身。記録から計算するだけで、作った数字は入れない
class YearRecap {
  const YearRecap({required this.year, required this.count, required this.venueCount, required this.prefectureCount, required this.bestMonth, required this.bestMonthCount, this.topVenue, this.topGroup, required this.favorites, required this.noteCount});
  final int year;
  final int count;
  final int venueCount;
  final int prefectureCount;
  final int bestMonth;
  final int bestMonthCount;
  final MapEntry<String, int>? topVenue;
  final MapEntry<String, int>? topGroup;
  final List<String> favorites;
  final int noteCount;

  factory YearRecap.of(Iterable<TheaterLogEntry> entries, int year, Map<String, String> prefectureOfVenue) {
    final inYear = entries.where((e) => e.watchedOn.year == year).toList();
    final s = LogStats.of(inYear, year);
    var best = 0;
    for (var m = 1; m < 12; m++) {
      if (s.perMonth[m] > s.perMonth[best]) best = m;
    }
    final venues = inYear.map((e) => e.venue).whereType<String>().toSet();
    final rated = inYear.where((e) => (e.rating ?? 0) >= 5).toList()..sort((a, b) => a.watchedOn.compareTo(b.watchedOn));
    return YearRecap(
      year: year,
      count: inYear.length,
      venueCount: venues.length,
      prefectureCount: venues.map((v) => prefectureOfVenue[v]).whereType<String>().toSet().length,
      bestMonth: best + 1,
      bestMonthCount: s.perMonth[best],
      topVenue: s.topVenues.isEmpty ? null : s.topVenues.first,
      topGroup: s.topGroups.isEmpty ? null : s.topGroups.first,
      favorites: rated.map((e) => e.title).toSet().take(3).toList(),
      noteCount: inYear.where((e) => e.note.isNotEmpty).length,
    );
  }
}
