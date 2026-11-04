import 'package:gikyoku_catalog/gikyoku_catalog.dart';

/// 人数・時間の範囲。max が null なら上限なし
class Range {
  const Range(this.label, this.min, this.max);
  final String label;
  final int min;
  final int? max;

  bool contains(int? v) => v != null && v >= min && (max == null || v <= max!);
}

const castRanges = [Range('1人', 1, 1), Range('2人', 2, 2), Range('3〜5人', 3, 5), Range('6〜10人', 6, 10), Range('11人以上', 11, null)];
const minuteRanges = [Range('30分まで', 1, 30), Range('60分まで', 1, 60), Range('90分まで', 1, 90), Range('91分以上', 91, null)];

class PlayFilter {
  const PlayFilter({this.keyword = '', this.cast, this.minutes, this.categoryIds = const {}, this.readableOnly = false});
  final String keyword;
  final Range? cast;
  final Range? minutes;
  final Set<int> categoryIds;
  final bool readableOnly;

  bool get isEmpty => keyword.trim().isEmpty && cast == null && minutes == null && categoryIds.isEmpty && !readableOnly;

  PlayFilter copyWith({String? keyword, Range? Function()? cast, Range? Function()? minutes, Set<int>? categoryIds, bool? readableOnly}) => PlayFilter(
    keyword: keyword ?? this.keyword,
    cast: cast != null ? cast() : this.cast,
    minutes: minutes != null ? minutes() : this.minutes,
    categoryIds: categoryIds ?? this.categoryIds,
    readableOnly: readableOnly ?? this.readableOnly,
  );

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s　・]'), '');

  bool matches(Play p) {
    final q = _norm(keyword);
    if (q.isNotEmpty && !_norm(p.title).contains(q) && !_norm(p.author).contains(q)) return false;
    if (cast != null && !cast!.contains(p.cast)) return false;
    if (minutes != null && !minutes!.contains(p.minutes)) return false;
    if (categoryIds.isNotEmpty && !p.categoryIds.any(categoryIds.contains)) return false;
    if (readableOnly && p.readUrl == null && p.buyUrl == null) return false;
    return true;
  }

  /// 判断に使える情報がそろった作品を先に出す
  List<Play> apply(List<Play> plays) {
    int score(Play p) => (p.cast != null ? 1 : 0) + (p.minutes != null ? 1 : 0) + (p.synopsis != null ? 1 : 0) + (p.readUrl != null || p.buyUrl != null ? 1 : 0);
    final hits = plays.where(matches).toList();
    final ranked = {for (final p in hits) p.id: score(p)};
    hits.sort((a, b) {
      final d = ranked[b.id]! - ranked[a.id]!;
      return d != 0 ? d : a.id - b.id;
    });
    return hits;
  }
}
