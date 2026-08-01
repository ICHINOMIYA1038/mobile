/// 診断カテゴリの種類。
enum MakerCategory { futatsuna, zensei, nounai }

extension MakerCategoryInfo on MakerCategory {
  String get title => switch (this) {
    MakerCategory.futatsuna => '二つ名メーカー',
    MakerCategory.zensei => '前世メーカー',
    MakerCategory.nounai => '脳内メーカー',
  };

  String get description => switch (this) {
    MakerCategory.futatsuna => '名前を入れると、あなたの中二病な二つ名が判明する。',
    MakerCategory.zensei => '名前を入れると、あなたの前世が判明する。',
    MakerCategory.nounai => '名前を入れると、あなたの頭の中を覗き見る。',
  };

  /// 画像アセットの代わりに使う絵文字アイコン。
  String get emoji => switch (this) {
    MakerCategory.futatsuna => '🗡️',
    MakerCategory.zensei => '⏳',
    MakerCategory.nounai => '🧠',
  };
}

/// 脳内メーカーカテゴリで使うキーワードと、理性/本能の度合い。
/// 0.0に近いほど理性寄り、1.0に近いほど本能寄り。
class NounaiKeyword {
  const NounaiKeyword({required this.label, required this.instinctRatio});

  final String label;
  final double instinctRatio;

  Map<String, Object?> toJson() => {
    'label': label,
    'instinctRatio': instinctRatio,
  };

  static NounaiKeyword fromJson(Map<String, Object?> json) => NounaiKeyword(
    label: json['label']! as String,
    instinctRatio: (json['instinctRatio']! as num).toDouble(),
  );
}

/// 1回の診断で生成される結果。
///
/// [category] + 正規化済みの[input] + rerollNonceが同じであれば、
/// 何度生成しても同じ内容になる(決定的生成)。詳しくは
/// `lib/logic/seeded_random.dart` を参照。
class MakerResult {
  const MakerResult({
    required this.category,
    required this.input,
    required this.headline,
    required this.answer,
    required this.detail,
    required this.shareText,
    this.keywords = const [],
  });

  final MakerCategory category;
  final String input;

  /// 結果の上に添える小さなリード文(例:「『たろう』の二つ名は──」)。
  final String headline;

  /// 画面上で大きく強調表示する、診断結果そのもの(例:「純白の破壊者」)。
  final String answer;

  /// [answer] の下に添える、小さめのフレーバーテキスト。
  final String detail;
  final String shareText;

  /// 脳内メーカーカテゴリでのみ使用する。他カテゴリでは空リスト。
  final List<NounaiKeyword> keywords;

  Map<String, Object?> toJson() => {
    'category': category.name,
    'input': input,
    'headline': headline,
    'answer': answer,
    'detail': detail,
    'shareText': shareText,
    'keywords': [for (final k in keywords) k.toJson()],
  };

  static MakerResult fromJson(Map<String, Object?> json) => MakerResult(
    category: MakerCategory.values.byName(json['category']! as String),
    input: json['input']! as String,
    headline: json['headline']! as String,
    answer: json['answer']! as String,
    detail: json['detail']! as String,
    shareText: json['shareText']! as String,
    keywords: [
      for (final raw in (json['keywords'] as List?) ?? const [])
        NounaiKeyword.fromJson((raw as Map).cast<String, Object?>()),
    ],
  );
}
