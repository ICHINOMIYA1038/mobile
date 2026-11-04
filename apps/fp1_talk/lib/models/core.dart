// サイトの API が返す形のうち、いくつもの画面で使うもの。
// 画面ごとにしか使わないものは、その画面で Map のまま読む（サイトの views.ts が正）。

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// ○×問題（答え・解説は含まない。答えると /answer か会話の graded で届く）
class PublicQuestion {
  const PublicQuestion({required this.id, required this.chapterId, required this.topic, required this.statement, required this.difficulty, this.origin});
  final String id;
  final String chapterId;
  final String topic;
  final String statement;

  /// 1〜3
  final int difficulty;

  /// 過去問の出典（例「令和7年度 問4 肢2」）。本試験の論点から作り直した問題だけ
  final String? origin;

  factory PublicQuestion.fromJson(Map<String, dynamic> j) => PublicQuestion(
        id: j['id'] as String,
        chapterId: j['chapterId'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
        statement: j['statement'] as String? ?? '',
        difficulty: _int(j['difficulty']).clamp(1, 3),
        origin: j['origin'] as String?,
      );
}

/// 答え合わせの結果
class Graded {
  const Graded({required this.answer, required this.correct, this.explanation = '', this.reference = ''});

  /// 学習者の答え（true = ○）
  final bool answer;
  final bool correct;
  final String explanation;
  final String reference;

  /// 正しい答え
  bool get rightAnswer => correct ? answer : !answer;

  factory Graded.fromJson(Map<String, dynamic> j, {bool? answer}) => Graded(
        answer: (j['answer'] as bool?) ?? answer ?? false,
        correct: j['correct'] == true,
        explanation: j['explanation'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
      );
}

/// 用語（本文の中で押すと意味が出る）
class Term {
  const Term({required this.name, required this.aliases, required this.short, required this.detail});
  final String name;
  final List<String> aliases;
  final String short;
  final String detail;

  factory Term.fromJson(Map<String, dynamic> j) => Term(
        name: j['name'] as String,
        aliases: ((j['aliases'] as List?) ?? const []).cast<String>(),
        short: j['short'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );

  static List<Term> listFrom(Object? v) => ((v as List?) ?? const []).map((t) => Term.fromJson(t as Map<String, dynamic>)).toList();
}

/// 図。種類（kind）ごとの中身は raw のまま持ち、widgets/figure/ の描き手が読む（型はサイトの src/lib/server/content.ts の Figure）
class FigureData {
  const FigureData({required this.id, required this.kind, required this.title, required this.hint, this.note, this.chapterId = '', required this.raw});
  final String id;

  /// compare / buckets / numbers / flow / nest / relation / timeline / scale / decision / matrix / illust / zones / calc
  final String kind;
  final String title;

  /// どんなときに見る図か（「〜を聞かれたとき」）
  final String hint;

  /// 図の下の「ポイント」
  final String? note;
  final String chapterId;
  final Map<String, dynamic> raw;

  factory FigureData.fromJson(Map<String, dynamic> j) => FigureData(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String? ?? '',
        hint: j['hint'] as String? ?? '',
        note: j['note'] as String?,
        chapterId: j['chapterId'] as String? ?? '',
        raw: j,
      );
}

/// 科目（本試験の配点つき）
class Subject {
  const Subject({required this.key, required this.name, required this.examQuestions, required this.summary, required this.chapterIds});
  final String key;
  final String name;
  final int examQuestions;
  final String summary;
  final List<String> chapterIds;

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        key: j['key'] as String,
        name: j['name'] as String,
        examQuestions: _int(j['examQuestions']),
        summary: j['summary'] as String? ?? '',
        chapterIds: ((j['chapterIds'] as List?) ?? const []).cast<String>(),
      );
}

class TopicSummary {
  const TopicSummary({required this.key, required this.title, required this.questionCount, required this.figureCount, required this.pointCount});
  final String key;
  final String title;
  final int questionCount;
  final int figureCount;
  final int pointCount;

  factory TopicSummary.fromJson(Map<String, dynamic> j) => TopicSummary(
        key: j['key'] as String,
        title: j['title'] as String,
        questionCount: _int(j['questionCount']),
        figureCount: _int(j['figureCount']),
        pointCount: _int(j['pointCount']),
      );
}

/// 章（一覧用）
class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.order,
    required this.subject,
    required this.title,
    required this.short,
    required this.goal,
    required this.examWeight,
    required this.topics,
    required this.questionCount,
    required this.figureCount,
    required this.pointCount,
  });
  final String id;
  final int order;
  final String subject;
  final String title;
  final String short;
  final String goal;
  final String examWeight;
  final List<TopicSummary> topics;
  final int questionCount;
  final int figureCount;
  final int pointCount;

  factory ChapterSummary.fromJson(Map<String, dynamic> j) => ChapterSummary(
        id: j['id'] as String,
        order: _int(j['order']),
        subject: j['subject'] as String? ?? '',
        title: j['title'] as String? ?? '',
        short: j['short'] as String? ?? j['title'] as String? ?? '',
        goal: j['goal'] as String? ?? '',
        examWeight: j['examWeight'] as String? ?? '',
        topics: ((j['topics'] as List?) ?? const []).map((t) => TopicSummary.fromJson(t as Map<String, dynamic>)).toList(),
        questionCount: _int(j['questionCount']),
        figureCount: _int(j['figureCount']),
        pointCount: _int(j['pointCount']),
      );
}
