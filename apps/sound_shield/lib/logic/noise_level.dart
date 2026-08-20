/// 全体音量から「静か/普通/うるさい」を判定する共通しきい値。
/// 結果画面の状態バッジと対策提案ロジックの両方から参照する。
///
/// 根拠:
/// - 環境省「騒音に係る環境基準」: 専ら住居の用に供される地域(A類型)で
///   昼間55dB以下・夜間45dB以下、特に静穏を要する地域(AA類型)で
///   昼間50dB以下・夜間40dB以下 (https://www.env.go.jp/kijun/oto1-1.html)
/// - 一般的な騒音レベル目安表: 30〜40dBは夜間の住宅地・ホテル客室、
///   40〜50dBは昼間の住宅地・静かな事務所・図書館、50〜60dBは銀行窓口や
///   書店程度の暮らしの中の音、60dB前後から「うるさい」と感じ始めるとされる
///   (https://www.yacmo.co.jp/technology/tips/noiselebel-db-reference/,
///   https://shimojima.jp/staffblog/blog/b-know-decibelstandard/)
///
/// この2つを踏まえ、昼夜を区別しない簡易な計測アプリとして
/// 「夜間の住宅地レベルまでが静か」「日中の住宅地〜生活音の範囲が普通」
/// 「そこを超えたら対策を検討すべきうるさい環境」という3区分にした。
enum NoiseLevel { quiet, moderate, loud }

const quietThresholdDb = 40.0;
const loudThresholdDb = 60.0;

NoiseLevel noiseLevelForDb(double db) {
  if (db < quietThresholdDb) return NoiseLevel.quiet;
  if (db < loudThresholdDb) return NoiseLevel.moderate;
  return NoiseLevel.loud;
}

/// 騒音レベルの目安として画面に示す実例。上記の目安表(yacmo.co.jp)から
/// 各10dB帯を代表する場所を1つずつ選んだもの。
class NoiseReferencePoint {
  const NoiseReferencePoint({required this.db, required this.label});

  final double db;
  final String label;
}

const noiseReferencePoints = <NoiseReferencePoint>[
  NoiseReferencePoint(db: 85, label: 'パチンコ店内'),
  NoiseReferencePoint(db: 75, label: '幹線道路沿い・セミの声'),
  NoiseReferencePoint(db: 65, label: 'バス車内・ファミレス店内'),
  NoiseReferencePoint(db: 55, label: '銀行窓口・書店'),
  NoiseReferencePoint(db: 45, label: '昼の住宅地・図書館'),
  NoiseReferencePoint(db: 35, label: '夜の住宅地・ホテル客室'),
];
