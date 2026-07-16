/// 1問ごとの学習履歴。ユーザーのデータはこれが全て。
class ReviewState {
  const ReviewState({
    required this.questionId,
    this.repetition = 0,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.dueAt,
    this.lastAnsweredAt,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  final String questionId;

  /// 連続正解回数。間違えると0に戻る。
  final int repetition;

  /// 次回出題までの間隔（日）。
  final int intervalDays;

  /// 覚えやすさ係数。間違えるほど下がり、その問題が頻繁に出るようになる。
  final double easeFactor;

  /// この日時を過ぎたら復習対象。null なら未学習。
  final DateTime? dueAt;

  final DateTime? lastAnsweredAt;
  final int correctCount;
  final int wrongCount;

  bool get isNew => lastAnsweredAt == null;

  int get totalAnswered => correctCount + wrongCount;

  /// 正答率（0.0〜1.0）。未回答なら0。
  double get accuracy => totalAnswered == 0 ? 0 : correctCount / totalAnswered;

  /// 「身についた」とみなす基準。3連続正解かつ間隔が21日以上。
  bool get isMastered => repetition >= 3 && intervalDays >= 21;

  bool isDue(DateTime now) {
    final due = dueAt;
    if (due == null) return true;
    return !due.isAfter(now);
  }

  ReviewState copyWith({
    int? repetition,
    int? intervalDays,
    double? easeFactor,
    DateTime? dueAt,
    DateTime? lastAnsweredAt,
    int? correctCount,
    int? wrongCount,
  }) {
    return ReviewState(
      questionId: questionId,
      repetition: repetition ?? this.repetition,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      dueAt: dueAt ?? this.dueAt,
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'repetition': repetition,
        'intervalDays': intervalDays,
        'easeFactor': easeFactor,
        'dueAt': dueAt?.toIso8601String(),
        'lastAnsweredAt': lastAnsweredAt?.toIso8601String(),
        'correctCount': correctCount,
        'wrongCount': wrongCount,
      };

  factory ReviewState.fromJson(Map<String, dynamic> json) {
    return ReviewState(
      questionId: json['questionId'] as String,
      repetition: (json['repetition'] as num?)?.toInt() ?? 0,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      dueAt: _parseDate(json['dueAt']),
      lastAnsweredAt: _parseDate(json['lastAnsweredAt']),
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
