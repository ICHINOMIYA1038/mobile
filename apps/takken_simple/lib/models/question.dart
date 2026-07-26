/// 出題される一問一答（○×）の1問。assets/questions.json から読み込む静的データ。
class Question {
  const Question({
    required this.id,
    required this.category,
    required this.topic,
    required this.statement,
    required this.answer,
    required this.explanation,
    required this.reference,
    required this.difficulty,
  });

  final String id;
  final String category;
  final String topic;
  final String statement;
  final bool answer;
  final String explanation;
  final String reference;
  final int difficulty;

  /// 分野の中区分（大区分の科目をさらに数個に分類したもの）
  String get mediumCategory {
    if (category == '宅建業法') {
      if (topic.contains('免許') ||
          topic.contains('事務所') ||
          topic.contains('宅建士') ||
          topic.contains('取引士') ||
          topic.contains('登録') ||
          topic.contains('保証金') ||
          topic.contains('保証協会') ||
          topic.contains('届出') ||
          topic.contains('定義') ||
          topic.contains('標識')) {
        return '免許・宅建士・保証制度';
      }
      if (topic.contains('35条') ||
          topic.contains('37条') ||
          topic.contains('説明') ||
          topic.contains('重要事項') ||
          topic.contains('広告') ||
          topic.contains('規制') ||
          topic.contains('明示') ||
          topic.contains('案内所') ||
          topic.contains('帳簿') ||
          topic.contains('名簿') ||
          topic.contains('従業者') ||
          topic.contains('書面')) {
        return '業務上の規制（35条・37条等）';
      }
      return '契約・報酬・8種制限・罰則';
    } else if (category == '権利関係') {
      if (topic.contains('意思表示') ||
          topic.contains('強迫') ||
          topic.contains('虚偽') ||
          topic.contains('心裡留保') ||
          topic.contains('制限行為') ||
          topic.contains('代理') ||
          topic.contains('時効')) {
        return '契約・意思表示・代理';
      }
      if (topic.contains('不履行') ||
          topic.contains('解除') ||
          topic.contains('危険負担') ||
          topic.contains('弁済') ||
          topic.contains('相殺') ||
          topic.contains('保証') ||
          topic.contains('債務') ||
          topic.contains('債権') ||
          topic.contains('不適合') ||
          topic.contains('敷金') ||
          topic.contains('不法行為') ||
          topic.contains('手付') ||
          topic.contains('請負') ||
          topic.contains('相続') ||
          topic.contains('遺留分') ||
          topic.contains('居住権')) {
        return '債権・不法行為・相続';
      }
      return '所有権・借地借家・不動産登記';
    } else if (category == '法令上の制限') {
      if (topic.contains('都市計画') ||
          topic.contains('開発') ||
          topic.contains('用途地域') ||
          topic.contains('地区計画') ||
          topic.contains('地域地区')) {
        return '都市計画法';
      }
      if (topic.contains('建築基準') ||
          topic.contains('建築確認') ||
          topic.contains('建蔽率') ||
          topic.contains('容積率') ||
          topic.contains('高さ') ||
          topic.contains('防火') ||
          topic.contains('接道') ||
          topic.contains('道路')) {
        return '建築基準法';
      }
      return 'その他の法令（農地法等）';
    } else { // 税その他
      if (topic.contains('税') ||
          topic.contains('所得') ||
          topic.contains('印紙') ||
          topic.contains('登記')) {
        return '地方税・国税';
      }
      return '価格公示・鑑定・業務関連';
    }
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      category: json['category'] as String,
      topic: json['topic'] as String,
      statement: json['statement'] as String,
      answer: json['answer'] as bool,
      explanation: json['explanation'] as String,
      reference: json['reference'] as String,
      difficulty: (json['difficulty'] as num).toInt(),
    );
  }
}

/// 本試験の科目。weight は本試験50問中の出題数で、そのまま出題の重み付けに使う。
/// 「合格に効く順」に問題を配るための、このアプリの中心的な設計。
enum Category {
  gyoho('宅建業法', 20),
  kenri('権利関係', 14),
  horei('法令上の制限', 8),
  zei('税その他', 8);

  const Category(this.label, this.weight);

  final String label;

  /// 本試験50問中の出題数。
  final int weight;

  static Category? fromLabel(String label) {
    for (final c in Category.values) {
      if (c.label == label) return c;
    }
    return null;
  }

  /// 本試験に占める配点比率（0.0〜1.0）。
  double get ratio => weight / 50;
}
