/// 出題される4択問題の1問。assets/questions.json から読み込む静的データ。
class Question {
  const Question({
    required this.id,
    required this.unit,
    required this.question,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
  });

  final String id;
  final String unit;
  final String question;
  final List<String> choices;
  final int answerIndex;
  final String explanation;

  String get answer => choices[answerIndex];

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      unit: json['unit'] as String,
      question: json['question'] as String,
      choices: (json['choices'] as List).cast<String>(),
      answerIndex: (json['answerIndex'] as num).toInt(),
      explanation: json['explanation'] as String,
    );
  }
}
