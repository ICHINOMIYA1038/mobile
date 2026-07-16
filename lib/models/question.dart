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
