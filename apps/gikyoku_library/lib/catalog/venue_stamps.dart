import 'models.dart';
import 'theater_log.dart';

/// 都道府県ごとの進み具合
class PrefectureStamps {
  const PrefectureStamps(this.prefecture, this.venues, this.visited);
  final String prefecture;
  final List<Venue> venues;
  final Set<String> visited;
  int get total => venues.length;
  int get count => visited.length;
}

/// 記録の劇場名とカタログの劇場名が一致したものをスタンプにする。自由入力の劇場は数えない
Map<String, PrefectureStamps> venueStamps(List<Venue> venues, Iterable<TheaterLogEntry> entries) {
  final seen = entries.map((e) => e.venue).whereType<String>().toSet();
  final byPref = <String, List<Venue>>{};
  for (final v in venues) {
    (byPref[v.prefecture] ??= []).add(v);
  }
  return {for (final e in byPref.entries) e.key: PrefectureStamps(e.key, e.value, e.value.map((v) => v.name).where(seen.contains).toSet())};
}

/// 日本の形に並べた都道府県のタイル（列, 行）
const prefectureTiles = <String, (int, int)>{
  '北海道': (10, 0),
  '青森県': (10, 2), '秋田県': (9, 3), '岩手県': (10, 3),
  '山形県': (9, 4), '宮城県': (10, 4),
  '石川県': (6, 4), '新潟県': (8, 4),
  '福井県': (5, 5), '富山県': (6, 5), '長野県': (7, 5), '群馬県': (8, 5), '栃木県': (9, 5), '福島県': (10, 5),
  '滋賀県': (5, 6), '岐阜県': (6, 6), '山梨県': (7, 6), '埼玉県': (8, 6), '茨城県': (9, 6),
  '島根県': (2, 6), '鳥取県': (3, 6), '京都府': (4, 6),
  '山口県': (1, 7), '広島県': (2, 7), '岡山県': (3, 7), '兵庫県': (4, 7), '大阪府': (5, 7), '愛知県': (6, 7), '静岡県': (7, 7), '東京都': (8, 7), '千葉県': (9, 7),
  '福岡県': (0, 8), '大分県': (1, 8), '愛媛県': (2, 8), '香川県': (3, 8), '奈良県': (5, 8), '三重県': (6, 8), '神奈川県': (8, 8),
  '佐賀県': (0, 9), '熊本県': (1, 9), '高知県': (2, 9), '徳島県': (3, 9), '和歌山県': (5, 9),
  '長崎県': (0, 10), '宮崎県': (1, 10),
  '鹿児島県': (1, 11),
  '沖縄県': (0, 13),
};
