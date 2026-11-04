import 'theater_log.dart';

class Achievement {
  const Achievement({required this.id, required this.title, required this.description, required this.current, required this.goal});
  final String id;
  final String title;
  final String description;
  final int current;
  final int goal;
  bool get earned => current >= goal;
}

/// 記録から計算する。保存はしない（記録を消せばスタンプも戻る）
List<Achievement> achievementsOf(Iterable<TheaterLogEntry> entries) {
  final list = entries.toList();
  final venues = list.map((e) => e.venue).whereType<String>().toSet().length;
  final groups = list.map((e) => e.group).whereType<String>().toSet().length;
  final linked = list.where((e) => e.playId != null).length;
  final notes = list.where((e) => e.note.isNotEmpty).length;
  final months = <String, int>{};
  for (final e in list) {
    final k = '${e.watchedOn.year}-${e.watchedOn.month}';
    months[k] = (months[k] ?? 0) + 1;
  }
  final bestMonth = months.values.fold(0, (a, b) => a > b ? a : b);
  Achievement a(String id, String title, String description, int current, int goal) => Achievement(id: id, title: title, description: description, current: current, goal: goal);
  return [
    a('first', '初日', '最初の半券を切った', list.length, 1),
    a('five', '常連の入口', '5 本観た', list.length, 5),
    a('ten', '客席の住人', '10 本観た', list.length, 10),
    a('thirty', '劇場に住む', '30 本観た', list.length, 30),
    a('hundred', '百本の幕', '100 本観た', list.length, 100),
    a('venue3', '劇場めぐり', '3 つの劇場に行った', venues, 3),
    a('venue10', '旅する観客', '10 の劇場に行った', venues, 10),
    a('group5', '劇団めぐり', '5 つの劇団を観た', groups, 5),
    a('month3', '今月は当たり月', '同じ月に 3 本観た', bestMonth, 3),
    a('script3', '台本にも興味', '戯曲につながる作品を 3 本記録した', linked, 3),
    a('note5', '語りたくなる', '感想を 5 本書いた', notes, 5),
  ];
}

/// 新しく取れたスタンプ
List<Achievement> newlyEarned(Iterable<TheaterLogEntry> before, Iterable<TheaterLogEntry> after) {
  final had = achievementsOf(before).where((x) => x.earned).map((x) => x.id).toSet();
  return achievementsOf(after).where((x) => x.earned && !had.contains(x.id)).toList();
}
