import 'dart:math';

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

  /// 選択肢の順番を入れ替えた複製。データでは正解が2番目に偏っている(44%)ため、
  /// 出題時に必ずシャッフルして「2番目を選べば当たる」学習を防ぐ。
  Question shuffled(Random random) {
    final order = List<int>.generate(choices.length, (i) => i)..shuffle(random);
    return Question(
      id: id,
      unit: unit,
      question: question,
      choices: [for (final i in order) choices[i]],
      answerIndex: order.indexOf(answerIndex),
      explanation: explanation,
    );
  }

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
