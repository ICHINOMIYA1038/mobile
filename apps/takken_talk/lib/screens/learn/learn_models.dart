import '../../models/core.dart';

// 章の会話の画面（学ぶ）だけで使う形。サイトの src/routes/[exam]/learn/[chapter]/+page.svelte の Seg / Item と同じ。

/// 先生の返答の1区切り。届いた順（本文 → 図 → 本文 …）をそのまま並べる
sealed class Seg {}

class TextSeg extends Seg {
  TextSeg(this.text);
  String text;
}

class QuestionSeg extends Seg {
  QuestionSeg(this.question, [this.graded]);
  final PublicQuestion question;

  /// 答えたら入る（同じ問題がもう一度出ても、前の答えは新しいカードに付けない）
  Graded? graded;
}

class FigureSeg extends Seg {
  FigureSeg(this.figure);
  final FigureData figure;
}

class ChoicesSeg extends Seg {
  ChoicesSeg(this.question, this.choices);
  final String question;
  final List<String> choices;
}

Seg? segFromJson(Map<String, dynamic> j) {
  switch (j['type']) {
    case 'text':
      return TextSeg(j['text'] as String? ?? '');
    case 'question':
      final g = j['graded'] as Map<String, dynamic>?;
      return QuestionSeg(PublicQuestion.fromJson(j['question'] as Map<String, dynamic>), g == null ? null : Graded.fromJson(g));
    case 'figure':
      return FigureSeg(FigureData.fromJson(j['figure'] as Map<String, dynamic>));
    case 'choices':
      return ChoicesSeg(j['question'] as String? ?? '', ((j['choices'] as List?) ?? const []).cast<String>());
  }
  return null;
}

/// 画面の1発言
sealed class Item {}

class UserItem extends Item {
  UserItem(this.text);
  final String text;
}

class AssistantItem extends Item {
  AssistantItem({List<Seg>? segments, this.id}) : segments = segments ?? [];
  final List<Seg> segments;

  /// done で届くメッセージの id。報告に使う（届くまでは「この返答を報告」を出さない）
  String? id;
  String? error;

  /// 失敗したときに同じ頼みをもう一度送るためのもの
  Map<String, Object?>? body;
  String? shown;
  bool reported = false;

  void appendText(String delta) {
    final last = segments.isEmpty ? null : segments.last;
    if (last is TextSeg) {
      last.text += delta;
    } else {
      segments.add(TextSeg(delta));
    }
  }
}

/// 論点（目次とテキストに出す）
class OutlinePoint {
  const OutlinePoint({required this.id, required this.title, required this.taught, required this.questionIds, required this.figureIds, required this.summary});
  final String id;
  final String title;
  final bool taught;
  final List<String> questionIds;
  final List<String> figureIds;
  final String summary;

  factory OutlinePoint.fromJson(Map<String, dynamic> j) => OutlinePoint(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        taught: j['taught'] == true,
        questionIds: ((j['questionIds'] as List?) ?? const []).cast<String>(),
        figureIds: ((j['figureIds'] as List?) ?? const []).cast<String>(),
        summary: j['summary'] as String? ?? '',
      );
}

class OutlineTopic {
  const OutlineTopic({required this.key, required this.title, required this.points});
  final String key;
  final String title;
  final List<OutlinePoint> points;

  factory OutlineTopic.fromJson(Map<String, dynamic> j) => OutlineTopic(
        key: j['key'] as String,
        title: j['title'] as String? ?? '',
        points: ((j['points'] as List?) ?? const []).map((p) => OutlinePoint.fromJson(p as Map<String, dynamic>)).toList(),
      );
}

/// GET /api/v1/takken/learn/:chapter の章の部分
class LearnChapter {
  const LearnChapter({required this.id, required this.order, required this.title, required this.short, required this.goal, required this.topics});
  final String id;
  final int order;
  final String title;
  final String short;
  final String goal;
  final List<OutlineTopic> topics;

  List<OutlinePoint> get points => [for (final t in topics) ...t.points];
  OutlinePoint? point(String? id) => id == null ? null : points.where((p) => p.id == id).firstOrNull;

  factory LearnChapter.fromJson(Map<String, dynamic> j) => LearnChapter(
        id: j['id'] as String,
        order: (j['order'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        short: (j['short'] as String?)?.isNotEmpty == true ? j['short'] as String : j['title'] as String? ?? '',
        goal: j['goal'] as String? ?? '',
        topics: ((j['topics'] as List?) ?? const []).map((t) => OutlineTopic.fromJson(t as Map<String, dynamic>)).toList(),
      );
}

/// 前後の章
class Neighbor {
  const Neighbor(this.id, this.title);
  final String id;
  final String title;
  static Neighbor? fromJson(Object? v) => v is Map<String, dynamic> ? Neighbor(v['id'] as String, v['title'] as String? ?? '') : null;
}

/// 進め方（サイトの ChapterOutline.svelte の PACES）
const paces = [
  (key: 'drill', label: 'じっくり演習', note: '論点の○×を全部解いてから次へ'),
  (key: 'standard', label: 'ふつう', note: '1論点2問くらい'),
  (key: 'fast', label: 'テンポよく', note: '1論点1問で先へ'),
];
