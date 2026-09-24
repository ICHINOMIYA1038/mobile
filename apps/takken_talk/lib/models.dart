class ChapterTopic {
  const ChapterTopic({required this.key, required this.title});
  final String key;
  final String title;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.order,
    required this.subject,
    required this.title,
    required this.short,
    required this.free,
    required this.goal,
    required this.examWeight,
    required this.questionCount,
    required this.topics,
  });
  final String id;
  final int order;
  final String subject;
  final String title;
  final String short;
  final bool free;
  final String goal;
  final String examWeight;
  final int questionCount;
  final List<ChapterTopic> topics;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        order: (j['order'] as num).toInt(),
        subject: j['subject'] as String,
        title: j['title'] as String,
        short: j['short'] as String? ?? j['title'] as String,
        free: j['free'] == true,
        goal: j['goal'] as String? ?? '',
        examWeight: j['examWeight'] as String? ?? '',
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
        topics: ((j['topics'] as List?) ?? const [])
            .map((t) => ChapterTopic(key: t['key'] as String, title: t['title'] as String))
            .toList(),
      );
}

class ChapterProgress {
  const ChapterProgress({
    required this.chapterId,
    required this.title,
    required this.total,
    required this.seen,
    required this.mastered,
    required this.accuracy,
  });
  final String chapterId;
  final String title;
  final int total;
  final int seen;
  final int mastered;
  final double? accuracy;

  factory ChapterProgress.fromJson(Map<String, dynamic> j) => ChapterProgress(
        chapterId: j['chapterId'] as String,
        title: j['title'] as String,
        total: (j['total'] as num).toInt(),
        seen: (j['seen'] as num).toInt(),
        mastered: (j['mastered'] as num).toInt(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
      );
}

class ProgressSummary {
  const ProgressSummary({
    required this.chapters,
    required this.totalQuestions,
    required this.seen,
    required this.mastered,
    required this.accuracy,
    required this.passScore,
    required this.daysToExam,
  });
  final List<ChapterProgress> chapters;
  final int totalQuestions;
  final int seen;
  final int mastered;
  final double? accuracy;
  final int passScore;
  final int? daysToExam;

  static const empty = ProgressSummary(
    chapters: [],
    totalQuestions: 0,
    seen: 0,
    mastered: 0,
    accuracy: null,
    passScore: 0,
    daysToExam: null,
  );

  factory ProgressSummary.fromJson(Map<String, dynamic> j) => ProgressSummary(
        chapters: ((j['chapters'] as List?) ?? const [])
            .map((c) => ChapterProgress.fromJson(c as Map<String, dynamic>))
            .toList(),
        totalQuestions: (j['totalQuestions'] as num).toInt(),
        seen: (j['seen'] as num).toInt(),
        mastered: (j['mastered'] as num).toInt(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        passScore: (j['passScore'] as num).toInt(),
        daysToExam: (j['daysToExam'] as num?)?.toInt(),
      );

  ChapterProgress? of(String chapterId) {
    for (final c in chapters) {
      if (c.chapterId == chapterId) return c;
    }
    return null;
  }
}

class PlanInfo {
  const PlanInfo({
    required this.isPro,
    required this.proUntil,
    required this.turnBalance,
    required this.freeUsed,
    required this.freeCap,
  });
  final bool isPro;
  final int? proUntil;
  final int turnBalance;
  final int freeUsed;
  final int freeCap;

  factory PlanInfo.fromJson(Map<String, dynamic> j) => PlanInfo(
        isPro: j['isPro'] == true,
        proUntil: (j['proUntil'] as num?)?.toInt(),
        turnBalance: (j['turnBalance'] as num?)?.toInt() ?? 0,
        freeUsed: (j['freeUsed'] as num?)?.toInt() ?? 0,
        freeCap: (j['freeCap'] as num?)?.toInt() ?? 0,
      );

  int get freeLeft => (freeCap - freeUsed).clamp(0, freeCap);
}

class Me {
  const Me({
    required this.userId,
    required this.nickname,
    required this.examDate,
    required this.plan,
    required this.chapters,
    required this.turnCounts,
    required this.lastChapterId,
    required this.progress,
    required this.live,
  });
  final String userId;
  final String? nickname;
  final String? examDate;
  final PlanInfo plan;
  final List<Chapter> chapters;
  final Map<String, int> turnCounts;
  final String? lastChapterId;
  final ProgressSummary progress;
  final bool live;

  factory Me.fromJson(Map<String, dynamic> j) {
    final convs = ((j['conversations'] as List?) ?? const []);
    return Me(
      userId: j['userId'] as String,
      nickname: j['nickname'] as String?,
      examDate: j['examDate'] as String?,
      plan: PlanInfo.fromJson(j['plan'] as Map<String, dynamic>),
      chapters: ((j['chapters'] as List?) ?? const [])
          .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
          .toList(),
      turnCounts: {
        for (final c in convs) c['chapter_id'] as String: (c['turn_count'] as num).toInt(),
      },
      lastChapterId: convs.isEmpty ? null : convs.first['chapter_id'] as String,
      progress: ProgressSummary.fromJson(j['progress'] as Map<String, dynamic>),
      live: j['live'] == true,
    );
  }

  Chapter? chapter(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class PublicQuestion {
  const PublicQuestion({
    required this.id,
    required this.chapterId,
    required this.topic,
    required this.statement,
    required this.difficulty,
  });
  final String id;
  final String chapterId;
  final String topic;
  final String statement;
  final int difficulty;

  factory PublicQuestion.fromJson(Map<String, dynamic> j) => PublicQuestion(
        id: j['id'] as String,
        chapterId: j['chapterId'] as String,
        topic: j['topic'] as String,
        statement: j['statement'] as String,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
      );
}

class TurnInfo {
  const TurnInfo({
    required this.chargedTo,
    required this.freeUsed,
    required this.freeCap,
    required this.turnBalance,
    required this.isPro,
  });
  final String chargedTo;
  final int freeUsed;
  final int freeCap;
  final int turnBalance;
  final bool isPro;

  factory TurnInfo.fromJson(Map<String, dynamic> j) => TurnInfo(
        chargedTo: j['chargedTo'] as String,
        freeUsed: (j['freeUsed'] as num).toInt(),
        freeCap: (j['freeCap'] as num).toInt(),
        turnBalance: (j['turnBalance'] as num).toInt(),
        isPro: j['isPro'] == true,
      );
}

sealed class TutorEvent {
  const TutorEvent();

  static TutorEvent? fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'text':
        return TextDelta(j['delta'] as String);
      case 'question':
        return QuestionEvent(PublicQuestion.fromJson(j['question'] as Map<String, dynamic>));
      case 'graded':
        return GradedEvent(
          questionId: j['questionId'] as String,
          answer: j['answer'] == true,
          correct: j['correct'] == true,
          explanation: j['explanation'] as String? ?? '',
          reference: j['reference'] as String? ?? '',
        );
      case 'progress':
        return ProgressEvent(ProgressSummary.fromJson(j['progress'] as Map<String, dynamic>));
      case 'done':
        return DoneEvent(TurnInfo.fromJson(j['turn'] as Map<String, dynamic>));
      case 'error':
        return ErrorEvent(j['message'] as String? ?? 'error', j['code'] as String?);
    }
    return null;
  }
}

class TextDelta extends TutorEvent {
  const TextDelta(this.delta);
  final String delta;
}

class QuestionEvent extends TutorEvent {
  const QuestionEvent(this.question);
  final PublicQuestion question;
}

class GradedEvent extends TutorEvent {
  const GradedEvent({
    required this.questionId,
    required this.answer,
    required this.correct,
    required this.explanation,
    required this.reference,
  });
  final String questionId;
  final bool answer;
  final bool correct;
  final String explanation;
  final String reference;
}

class ProgressEvent extends TutorEvent {
  const ProgressEvent(this.progress);
  final ProgressSummary progress;
}

class DoneEvent extends TutorEvent {
  const DoneEvent(this.turn);
  final TurnInfo turn;
}

class ErrorEvent extends TutorEvent {
  const ErrorEvent(this.message, this.code);
  final String message;
  final String? code;
}

/// 画面復元用の履歴1件。assistant のときは meta.events に出題カードが入っている。
class HistoryMessage {
  const HistoryMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.questions,
    required this.answer,
  });
  final String id;
  final String role;
  final String text;
  final List<PublicQuestion> questions;

  /// user 側: カード回答の内容 {questionId, answer, correct}
  final Map<String, dynamic>? answer;

  factory HistoryMessage.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] as Map<String, dynamic>?;
    final qs = <PublicQuestion>[];
    for (final e in (meta?['events'] as List?) ?? const []) {
      if (e['type'] == 'question') qs.add(PublicQuestion.fromJson(e['question'] as Map<String, dynamic>));
    }
    return HistoryMessage(
      id: j['id'] as String,
      role: j['role'] as String,
      text: j['text'] as String? ?? '',
      questions: qs,
      answer: meta?['answer'] as Map<String, dynamic>?,
    );
  }
}

class Entitlement {
  const Entitlement({required this.ok, required this.reason});
  final bool ok;
  final String? reason;
  factory Entitlement.fromJson(Map<String, dynamic> j) =>
      Entitlement(ok: j['ok'] == true, reason: j['reason'] as String?);
}
