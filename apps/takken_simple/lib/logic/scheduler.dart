import 'dart:math';

import '../models/question.dart';
import '../models/review_state.dart';

/// 出題順と復習間隔を決める頭脳。
///
/// 設計方針: ユーザーにモードを選ばせない。「おまかせ／復習優先／ランダム」のような
/// 選択肢を出した時点でシンプルではなくなるため、以下を全て自動でやる。
///   1. 忘れかけた頃に復習させる（SM-2 を○×2値用に簡略化したもの）
///   2. 本試験の配点比率どおりに科目を配る（宅建業法40%・権利関係28%・法令16%・税16%）
///   3. 間違えた問題ほど早く・何度も出す
class Scheduler {
  Scheduler({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 間違えた直後の再出題までの時間。同じセッション中にもう一度出して定着させる。
  static const Duration _relearnDelay = Duration(minutes: 10);

  static const double _minEase = 1.3;
  static const double _maxEase = 2.8;

  /// 復習間隔の上限。正解を重ねると間隔は指数的に伸びるため、上限がないと
  /// DateTime が扱える範囲を超えて破綻する。宅建は年1回の試験なので1年で頭打ちで足りる。
  static const int _maxIntervalDays = 365;

  /// 回答結果を受けて次回の復習タイミングを計算する。
  ReviewState grade({
    required ReviewState state,
    required bool isCorrect,
    required DateTime now,
  }) {
    if (!isCorrect) {
      // 間違えたら連続正解をリセットし、覚えにくい問題として以後を厚くする。
      return state.copyWith(
        repetition: 0,
        intervalDays: 0,
        easeFactor: max(_minEase, state.easeFactor - 0.2),
        dueAt: now.add(_relearnDelay),
        lastAnsweredAt: now,
        wrongCount: state.wrongCount + 1,
      );
    }

    final repetition = state.repetition + 1;
    final ease = min(_maxEase, state.easeFactor + 0.1);

    // 1日後 → 3日後 → 以降は ease 倍ずつ間隔を広げる。
    final grown = switch (repetition) {
      1 => 1,
      2 => 3,
      _ => max(1, (state.intervalDays * ease).round()),
    };
    final intervalDays = min(grown, _maxIntervalDays);

    return state.copyWith(
      repetition: repetition,
      intervalDays: intervalDays,
      easeFactor: ease,
      dueAt: now.add(Duration(days: intervalDays)),
      lastAnsweredAt: now,
      correctCount: state.correctCount + 1,
    );
  }

  /// 次に出す1問を選ぶ。復習期限が来た問題を優先し、なければ未学習から配点比率に沿って出す。
  ///
  /// [excludeId] は直前に出した問題。2問しか候補がない場面での連続出題を避ける。
  Question? pickNext({
    required List<Question> questions,
    required Map<String, ReviewState> states,
    required DateTime now,
    String? excludeId,
  }) {
    if (questions.isEmpty) return null;

    ReviewState stateOf(Question q) =>
        states[q.id] ?? ReviewState(questionId: q.id);

    var pool = questions.where((q) => stateOf(q).isDue(now)).toList();

    // 全問が復習待ち（今日やることがない）なら、期限が近い順に先取りで演習させる。
    // 「今日はもうやることがありません」で終わらせない。
    if (pool.isEmpty) pool = List.of(questions);

    if (pool.length > 1 && excludeId != null) {
      final filtered = pool.where((q) => q.id != excludeId).toList();
      if (filtered.isNotEmpty) pool = filtered;
    }

    final weights = pool.map((q) => _weight(q, stateOf(q), now)).toList();
    return _weightedPick(pool, weights);
  }

  /// 1問あたりの出題されやすさ。大きいほど出やすい。
  double _weight(Question q, ReviewState state, DateTime now) {
    // 本試験の配点比率。これが全ての土台で、宅建業法は税その他の2.5倍出る。
    final category = Category.fromLabel(q.category);
    var weight = (category?.ratio ?? 0.2) * 100;

    // 期限切れが長いほど優先。忘れかけている可能性が高い。
    final due = state.dueAt;
    if (due != null && due.isBefore(now)) {
      final overdueDays = now.difference(due).inHours / 24.0;
      weight *= 1.0 + min(overdueDays, 30.0) * 0.1;
    }

    // 苦手なほど（ease が低いほど）出やすくする。
    weight *= 1.0 + (_maxEase - state.easeFactor);

    // 未学習を少しだけ優遇して、序盤に手つかずの問題が残り続けないようにする。
    if (state.isNew) weight *= 1.3;

    // 身についた問題は間隔に任せ、出題頻度を落とす。
    if (state.isMastered) weight *= 0.3;

    return max(weight, 0.01);
  }

  T _weightedPick<T>(List<T> items, List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    var threshold = _random.nextDouble() * total;
    for (var i = 0; i < items.length; i++) {
      threshold -= weights[i];
      if (threshold <= 0) return items[i];
    }
    return items.last;
  }
}
