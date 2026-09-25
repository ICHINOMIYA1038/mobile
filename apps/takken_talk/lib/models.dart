class ChapterTopic {
  const ChapterTopic({
    required this.key,
    required this.title,
    required this.questionCount,
    required this.figureCount,
  });
  final String key;
  final String title;
  final int questionCount;
  final int figureCount;

  factory ChapterTopic.fromJson(Map<String, dynamic> j) => ChapterTopic(
        key: j['key'] as String,
        title: j['title'] as String,
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
        figureCount: (j['figureCount'] as num?)?.toInt() ?? 0,
      );
}

/// 本試験の科目。配点(50問中の出題数)が学習順の根拠になる。
class Subject {
  const Subject({
    required this.key,
    required this.name,
    required this.examQuestions,
    required this.summary,
    required this.chapterIds,
  });
  final String key;
  final String name;
  final int examQuestions;
  final String summary;
  final List<String> chapterIds;

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        key: j['key'] as String,
        name: j['name'] as String,
        examQuestions: (j['examQuestions'] as num).toInt(),
        summary: j['summary'] as String? ?? '',
        chapterIds: ((j['chapterIds'] as List?) ?? const []).cast<String>(),
      );
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
    required this.figureCount,
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
  final int figureCount;
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
        figureCount: (j['figureCount'] as num?)?.toInt() ?? 0,
        topics: ((j['topics'] as List?) ?? const [])
            .map((t) => ChapterTopic.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class TopicProgress {
  const TopicProgress({
    required this.key,
    required this.title,
    required this.total,
    required this.seen,
    required this.mastered,
  });
  final String key;
  final String title;
  final int total;
  final int seen;
  final int mastered;

  double get masteryRatio => total == 0 ? 0 : mastered / total;

  factory TopicProgress.fromJson(Map<String, dynamic> j) => TopicProgress(
        key: j['key'] as String,
        title: j['title'] as String,
        total: (j['total'] as num).toInt(),
        seen: (j['seen'] as num).toInt(),
        mastered: (j['mastered'] as num).toInt(),
      );
}

class ChapterProgress {
  const ChapterProgress({
    required this.chapterId,
    required this.title,
    required this.subject,
    required this.total,
    required this.seen,
    required this.mastered,
    required this.accuracy,
    required this.topics,
  });
  final String chapterId;
  final String title;
  final String subject;
  final int total;
  final int seen;
  final int mastered;
  final double? accuracy;
  final List<TopicProgress> topics;

  double get masteryRatio => total == 0 ? 0 : mastered / total;

  TopicProgress? topic(String key) {
    for (final t in topics) {
      if (t.key == key) return t;
    }
    return null;
  }

  factory ChapterProgress.fromJson(Map<String, dynamic> j) => ChapterProgress(
        chapterId: j['chapterId'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String? ?? '',
        total: (j['total'] as num).toInt(),
        seen: (j['seen'] as num).toInt(),
        mastered: (j['mastered'] as num).toInt(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        topics: ((j['topics'] as List?) ?? const [])
            .map((t) => TopicProgress.fromJson(t as Map<String, dynamic>))
            .toList(),
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
    required this.subjects,
    required this.chapters,
    required this.turnCounts,
    required this.currentTopics,
    required this.visitedTopics,
    required this.lastChapterId,
    required this.progress,
    required this.live,
  });
  final String userId;
  final String? nickname;
  final String? examDate;
  final PlanInfo plan;
  final List<Subject> subjects;
  final List<Chapter> chapters;
  final Map<String, int> turnCounts;

  /// 章ID → 最後に話していた小テーマの key
  final Map<String, String> currentTopics;

  /// 「章ID/テーマkey」の集合。一度でも話したテーマ。
  final Set<String> visitedTopics;
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
      subjects: ((j['subjects'] as List?) ?? const [])
          .map((s) => Subject.fromJson(s as Map<String, dynamic>))
          .toList(),
      chapters: ((j['chapters'] as List?) ?? const [])
          .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
          .toList(),
      turnCounts: {
        for (final c in convs) c['chapter_id'] as String: (c['turn_count'] as num).toInt(),
      },
      currentTopics: {
        for (final c in convs)
          if (c['current_topic'] != null) c['chapter_id'] as String: c['current_topic'] as String,
      },
      visitedTopics: ((j['visitedTopics'] as List?) ?? const []).cast<String>().toSet(),
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

/// 図解カード。サーバーで検証済みの内容が来るので、そのまま描けばよい。
class Figure {
  const Figure({
    required this.id,
    required this.chapterId,
    required this.topicKey,
    required this.title,
    required this.kind,
    required this.hint,
    required this.note,
    required this.columns,
    required this.rows,
    required this.groups,
    required this.items,
    required this.steps,
    required this.nodes,
  });
  final String id;
  final String chapterId;
  final String topicKey;
  final String title;
  final String kind; // compare | buckets | numbers | flow | nest
  final String hint;
  final String? note;

  final List<String> columns;
  final List<FigureRow> rows;
  final List<FigureGroup> groups;
  final List<FigureItem> items;
  final List<FigureStep> steps;
  final List<FigureNode> nodes;

  factory Figure.fromJson(Map<String, dynamic> j) => Figure(
        id: j['id'] as String,
        chapterId: j['chapterId'] as String? ?? '',
        topicKey: j['topicKey'] as String? ?? '',
        title: j['title'] as String,
        kind: j['kind'] as String,
        hint: j['hint'] as String? ?? '',
        note: j['note'] as String?,
        columns: ((j['columns'] as List?) ?? const []).cast<String>(),
        rows: ((j['rows'] as List?) ?? const []).map((r) => FigureRow.fromJson(r as Map<String, dynamic>)).toList(),
        groups: ((j['groups'] as List?) ?? const []).map((g) => FigureGroup.fromJson(g as Map<String, dynamic>)).toList(),
        items: ((j['items'] as List?) ?? const []).map((i) => FigureItem.fromJson(i as Map<String, dynamic>)).toList(),
        steps: ((j['steps'] as List?) ?? const []).map((s) => FigureStep.fromJson(s as Map<String, dynamic>)).toList(),
        nodes: ((j['nodes'] as List?) ?? const []).map((n) => FigureNode.fromJson(n as Map<String, dynamic>)).toList(),
      );
}

class FigureRow {
  const FigureRow({required this.label, required this.cells});
  final String label;
  final List<String> cells;
  factory FigureRow.fromJson(Map<String, dynamic> j) =>
      FigureRow(label: j['label'] as String, cells: ((j['cells'] as List?) ?? const []).cast<String>());
}

class FigureGroup {
  const FigureGroup({required this.title, required this.tone, required this.items});
  final String title;
  final String? tone; // yes | no | warn | info
  final List<String> items;
  factory FigureGroup.fromJson(Map<String, dynamic> j) => FigureGroup(
        title: j['title'] as String,
        tone: j['tone'] as String?,
        items: ((j['items'] as List?) ?? const []).cast<String>(),
      );
}

class FigureItem {
  const FigureItem({required this.value, required this.label, required this.note});
  final String value;
  final String label;
  final String? note;
  factory FigureItem.fromJson(Map<String, dynamic> j) =>
      FigureItem(value: j['value'] as String, label: j['label'] as String, note: j['note'] as String?);
}

class FigureStep {
  const FigureStep({required this.title, required this.detail});
  final String title;
  final String? detail;
  factory FigureStep.fromJson(Map<String, dynamic> j) =>
      FigureStep(title: j['title'] as String, detail: (j['detail'] as String?)?.trim().isEmpty ?? true ? null : j['detail'] as String);
}

class FigureNode {
  const FigureNode({required this.title, required this.note, required this.children});
  final String title;
  final String? note;
  final List<FigureNode> children;
  factory FigureNode.fromJson(Map<String, dynamic> j) => FigureNode(
        title: j['title'] as String,
        note: j['note'] as String?,
        children: ((j['children'] as List?) ?? const []).map((c) => FigureNode.fromJson(c as Map<String, dynamic>)).toList(),
      );
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
      case 'figure':
        return FigureEvent(Figure.fromJson(j['figure'] as Map<String, dynamic>));
      case 'topic':
        return TopicEvent(
          chapterId: j['chapterId'] as String,
          topicKey: j['topicKey'] as String,
          title: j['title'] as String,
          index: (j['index'] as num).toInt(),
          total: (j['total'] as num).toInt(),
        );
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

class FigureEvent extends TutorEvent {
  const FigureEvent(this.figure);
  final Figure figure;
}

class TopicEvent extends TutorEvent {
  const TopicEvent({
    required this.chapterId,
    required this.topicKey,
    required this.title,
    required this.index,
    required this.total,
  });
  final String chapterId;
  final String topicKey;
  final String title;
  final int index;
  final int total;
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

/// 本文とカードが出てきた順に並んだ1かたまり。
sealed class MessagePart {
  const MessagePart();
}
class TextPart extends MessagePart {
  TextPart(this.text);
  String text;
}
class CardPart extends MessagePart {
  const CardPart(this.card);

  /// PublicQuestion または Figure
  final Object card;
}

/// 日本語を含まない短い断片は、ツール呼び出し直前にモデルが吐くゴミなので出さない。
final _jaPattern = RegExp(r'[ぁ-んァ-ヶ一-龯０-９、。]');
bool isGarbageText(String t) {
  final s = t.trim();
  return s.isNotEmpty && s.length < 12 && !_jaPattern.hasMatch(s);
}

/// 画面復元用の履歴1件。assistant のときは meta.segments に本文とカードが順番に入る。
class HistoryMessage {
  const HistoryMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.parts,
    required this.topic,
    required this.answer,
  });
  final String id;
  final String role;
  final String text;

  /// 本文とカードが出てきた順の並び
  final List<MessagePart> parts;

  /// assistant のターンで宣言された小テーマ（あれば）
  final TopicEvent? topic;

  /// user 側: カード回答の内容 {questionId, answer, correct}
  final Map<String, dynamic>? answer;

  factory HistoryMessage.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] as Map<String, dynamic>?;
    final parts = <MessagePart>[];
    TopicEvent? topic;

    void addCard(Map<String, dynamic> e) {
      switch (e['type']) {
        case 'question':
          parts.add(CardPart(PublicQuestion.fromJson(e['question'] as Map<String, dynamic>)));
        case 'figure':
          parts.add(CardPart(Figure.fromJson(e['figure'] as Map<String, dynamic>)));
      }
    }

    final segs = meta?['segments'] as List?;
    if (segs != null) {
      for (final e in segs) {
        final m = e as Map<String, dynamic>;
        if (m['type'] == 'text') {
          final t = (m['text'] as String? ?? '').trim();
          if (t.isNotEmpty && !isGarbageText(t)) parts.add(TextPart(t));
        } else {
          addCard(m);
        }
      }
    } else {
      // 旧形式（本文が先、カードが後）。順序の情報がないので本文を先頭に置く。
      final text = (j['text'] as String? ?? '').trim();
      if (text.isNotEmpty) parts.add(TextPart(text));
      for (final e in (meta?['events'] as List?) ?? const []) {
        addCard(e as Map<String, dynamic>);
      }
    }
    final t = meta?['topic'] as Map<String, dynamic>?;
    if (t != null) topic = TutorEvent.fromJson(t) as TopicEvent?;

    return HistoryMessage(
      id: j['id'] as String,
      role: j['role'] as String,
      text: j['text'] as String? ?? '',
      parts: parts,
      topic: topic,
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
