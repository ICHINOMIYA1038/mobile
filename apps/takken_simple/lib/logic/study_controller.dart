// foundation にも Category があるため、こちらの Category と衝突しないよう隠す。
import 'package:flutter/foundation.dart' hide Category;

import '../data/notification_service.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../data/review_prompt_service.dart';
import '../models/question.dart';
import '../models/review_state.dart';
import 'scheduler.dart';

/// 1問ぶんの回答結果。
class AnswerResult {
  const AnswerResult({
    required this.question,
    required this.chose,
    required this.isCorrect,
  });

  final Question question;

  /// ユーザーが選んだ○×。
  final bool chose;
  final bool isCorrect;
}

/// 科目ごとの到達度。成績画面で使う。
class CategoryStats {
  const CategoryStats({
    required this.category,
    required this.total,
    required this.mastered,
    required this.answered,
    required this.accuracy,
    required this.scoreRatio,
    required this.levels,
  });

  final Category category;
  final int total;
  final int mastered;
  final int answered;

  /// この科目の全問の到達度を、問題の並び順で並べたもの。合格グラフのマス目になる。
  /// 要素数＝その科目の問題数なので、マス目の面積がそのまま配点比率を表す。
  final List<MasteryLevel> levels;

  /// 回答した問題の中での正答率。「何割わかっているか」の表示用。
  final double accuracy;

  /// 得点換算に使う到達率。未回答の問題は0点として数えるため、
  /// 1問正解しただけでその科目の配点を満額取れてしまうことがない。
  final double scoreRatio;

  double get masteryRatio => total == 0 ? 0 : mastered / total;
}

/// アプリ全体の状態。画面はこれを見るだけで、出題ロジックは持たない。
class StudyController extends ChangeNotifier {
  static const sessionGoal = 5;

  StudyController({
    QuestionRepository? questions,
    ProgressRepository? progress,
    Scheduler? scheduler,
    NotificationService? notifications,
    ReviewPromptService? reviews,
  }) : _questionRepo = questions ?? QuestionRepository(),
       _progressRepo = progress ?? ProgressRepository(),
       _scheduler = scheduler ?? Scheduler(),
       _notifications = notifications ?? NotificationService(),
       _reviews = reviews ?? ReviewPromptService();

  final QuestionRepository _questionRepo;
  final ProgressRepository _progressRepo;
  final Scheduler _scheduler;
  final NotificationService _notifications;
  final ReviewPromptService _reviews;

  List<Question> _questions = [];
  Map<String, ReviewState> _states = {};
  StreakData _streak = const StreakData();

  bool _isLoading = true;
  bool _remindersEnabled = true;
  Question? _current;
  AnswerResult? _result;
  String? _sessionCategoryLabel;
  String? _sessionMediumCategoryLabel;
  Set<String>? _sessionQuestionIds;

  /// このセッションで解いた問題（結果画面の集計用）。
  final List<AnswerResult> _session = [];

  bool get isLoading => _isLoading;
  Question? get current => _current;

  /// 回答済みで解説を表示中なら非 null。null なら出題中。
  AnswerResult? get result => _result;
  StreakData get streak => _streak;
  List<AnswerResult> get session => List.unmodifiable(_session);
  int get totalQuestions => _questions.length;
  bool get remindersEnabled => _remindersEnabled;
  bool get sessionGoalReached => _session.length >= sessionGoal;
  int get sessionRemaining =>
      (sessionGoal - _session.length).clamp(0, sessionGoal);

  ProgressRepository get progressRepository => _progressRepo;

  /// 今すぐ復習すべき問題数。ホーム画面の「今日の復習」に出す。
  int get dueCount {
    final now = DateTime.now();
    return _questions.where((q) {
      final state = _states[q.id];
      if (state == null || state.isNew) return false;
      return state.isDue(now);
    }).length;
  }

  int get newCount => _questions
      .where((q) => (_states[q.id] ?? ReviewState(questionId: q.id)).isNew)
      .length;

  int get masteredCount =>
      _questions.where((q) => _states[q.id]?.isMastered ?? false).length;

  int get answeredCount => _states.values.where((s) => !s.isNew).length;

  int get correctlyAnsweredCount =>
      _questions.where((q) => (_states[q.id]?.correctCount ?? 0) > 0).length;

  /// 直近の回答が不正解で、まだ正解し直していない問題。
  List<Question> get weakQuestions {
    final questions = _questions.where((question) {
      final state = _states[question.id];
      return state != null && state.wrongCount > 0 && state.repetition == 0;
    }).toList();
    questions.sort((a, b) {
      final aState = _states[a.id]!;
      final bState = _states[b.id]!;
      return bState.wrongCount.compareTo(aState.wrongCount);
    });
    return List.unmodifiable(questions);
  }

  int correctCountForCategory(String category) {
    return _questions
        .where(
          (q) =>
              q.category == category && (_states[q.id]?.correctCount ?? 0) > 0,
        )
        .length;
  }

  int totalCountForCategory(String category) {
    return _questions.where((q) => q.category == category).length;
  }

  int correctCountForMediumCategory(String category, String mediumCategory) {
    return _questions
        .where(
          (q) =>
              q.category == category &&
              q.mediumCategory == mediumCategory &&
              (_states[q.id]?.correctCount ?? 0) > 0,
        )
        .length;
  }

  int totalCountForMediumCategory(String category, String mediumCategory) {
    return _questions
        .where(
          (q) => q.category == category && q.mediumCategory == mediumCategory,
        )
        .length;
  }

  double get overallAccuracy {
    var correct = 0;
    var total = 0;
    for (final s in _states.values) {
      correct += s.correctCount;
      total += s.totalAnswered;
    }
    return total == 0 ? 0 : correct / total;
  }

  /// 合格ラインの目安（50点満点中）。
  ///
  /// 実際の合格点は年により概ね33〜38点で変動し、事前には決まらない。
  /// 低く見積もって届いたつもりにさせるより、余裕を見た値を目標に置く。
  static const passingScore = 36.0;

  /// 合格ラインの目安まであと何点か。届いていれば0。
  double get pointsToPass =>
      (passingScore - predictedScore).clamp(0, passingScore);

  /// 合格ラインの目安に届いているか。
  bool get reachedPassingScore => predictedScore >= passingScore;

  /// 本試験の配点で換算した予想得点（50点満点）。
  ///
  /// まだ解いていない問題は0点として扱う。「今の実力で確実に取れる点数」の下限を示すためで、
  /// 1問だけ正解した段階でその科目の配点を満額計上するような、実態から離れた数字を出さない。
  /// 全問正解すれば50点になる。
  double get predictedScore {
    var score = 0.0;
    for (final stats in categoryStats) {
      score += stats.scoreRatio * stats.category.weight;
    }
    return score;
  }

  List<CategoryStats> get categoryStats {
    return Category.values.map((category) {
      final qs = _questions.where((q) => q.category == category.label).toList();
      var mastered = 0;
      var answered = 0;
      var correct = 0;
      var attempts = 0;

      // 未回答も分母に含めた到達率。未回答の1問は0点ぶんとして効く。
      var scoreSum = 0.0;
      final levels = <MasteryLevel>[];

      for (final q in qs) {
        final state = _states[q.id];
        levels.add(state?.masteryLevel ?? MasteryLevel.untouched);

        if (state == null || state.isNew) continue;
        answered++;
        if (state.isMastered) mastered++;
        correct += state.correctCount;
        attempts += state.totalAnswered;
        scoreSum += state.accuracy;
      }

      return CategoryStats(
        category: category,
        total: qs.length,
        mastered: mastered,
        answered: answered,
        accuracy: attempts == 0 ? 0 : correct / attempts,
        scoreRatio: qs.isEmpty ? 0 : scoreSum / qs.length,
        levels: levels,
      );
    }).toList();
  }

  /// 起動時の読み込みに失敗したか。true なら問題を出せないので、画面は理由を出す。
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  Future<void> init() async {
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();

    try {
      _questions = await _questionRepo.load();
      _states = await _progressRepo.loadStates();
      _streak = await _progressRepo.loadStreak();
      _remindersEnabled = await _progressRepo.loadRemindersEnabled();
    } catch (_) {
      // 何が起きても読み込み中のまま固まらせない。
      // ここで抜けられないと、履歴を消すボタンにすら到達できず二度と開けなくなる。
      _loadFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 出題を開始する。セッションの集計はここでリセットする。
  void startSession({String? categoryLabel, String? mediumCategoryLabel}) {
    _session.clear();
    _result = null;
    _sessionCategoryLabel = categoryLabel;
    _sessionMediumCategoryLabel = mediumCategoryLabel;
    _sessionQuestionIds = null;

    final filteredQuestions = _questions.where((q) {
      if (categoryLabel != null && q.category != categoryLabel) return false;
      if (mediumCategoryLabel != null &&
          q.mediumCategory != mediumCategoryLabel) {
        return false;
      }
      return true;
    }).toList();

    _current = _scheduler.pickNext(
      questions: filteredQuestions,
      states: _states,
      now: DateTime.now(),
    );
    notifyListeners();
  }

  void startWeakSession() {
    final ids = weakQuestions.map((question) => question.id).toSet();
    _session.clear();
    _result = null;
    _sessionCategoryLabel = null;
    _sessionMediumCategoryLabel = null;
    _sessionQuestionIds = ids;
    _current = _scheduler.pickNext(
      questions: _questions
          .where((question) => ids.contains(question.id))
          .toList(),
      states: _states,
      now: DateTime.now(),
    );
    notifyListeners();
  }

  /// ○×に回答する。保存はここで毎回行う（落ちてもデータを失わないため）。
  Future<void> answer(bool chose) async {
    final question = _current;
    if (question == null || _result != null) return;

    final now = DateTime.now();
    final isCorrect = chose == question.answer;
    final state = _states[question.id] ?? ReviewState(questionId: question.id);

    _states[question.id] = _scheduler.grade(
      state: state,
      isCorrect: isCorrect,
      now: now,
    );

    final result = AnswerResult(
      question: question,
      chose: chose,
      isCorrect: isCorrect,
    );
    _result = result;
    _session.add(result);
    _streak = _streak.markStudied(now);
    notifyListeners();

    await _progressRepo.saveStates(_states);
    await _progressRepo.saveStreak(_streak);
  }

  /// 学習を終えたときに呼ぶ。次の復習日にお知らせを出せるよう予定を組み直す。
  ///
  /// 回答のたびではなくセッションの終わりに1回だけ行う。
  /// 予約は全消し＋組み直しなので、1問ごとにやると無駄が大きい。
  Future<void> finishSession() async {
    if (!_remindersEnabled) {
      await _notifications.cancelAll();
      return;
    }
    await _notifications.scheduleReviewReminders(
      questions: _questions,
      states: _states,
    );
  }

  /// 通知の許可を求める。まだ一度も訊いていないときだけ実際に訊く。
  ///
  /// 呼ぶのは初回の学習を終えた直後だけ。起動直後に出しても
  /// 何のための通知か分からないユーザーは拒否するため。
  /// 許可されたか（＝この呼び出しで実際に許可が下りたか）を返す。
  Future<bool> maybeRequestNotificationPermission() async {
    if (!_remindersEnabled) return false;
    if (await _progressRepo.hasAskedNotificationPermission()) return false;
    await _progressRepo.markAskedNotificationPermission();

    final granted = await _notifications.requestPermission();
    if (granted) await finishSession();
    return granted;
  }

  /// 復習通知はアプリ内からいつでも止められるようにする。
  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    notifyListeners();
    await _progressRepo.saveRemindersEnabled(value);

    if (value) {
      await finishSession();
    } else {
      await _notifications.cancelAll();
    }
  }

  /// 十分使って価値を体験した人にだけ、一度だけ標準の評価依頼を出す。
  Future<bool> maybeRequestReview() async {
    if (answeredCount < 30 || _streak.current < 3) return false;
    if (await _progressRepo.hasRequestedReview()) return false;

    final requested = await _reviews.request();
    if (requested) await _progressRepo.markReviewRequested();
    return requested;
  }

  /// 解説を読み終えて次の問題へ。
  void next() {
    final previous = _current?.id;
    _result = null;

    final filteredQuestions = _questions.where((q) {
      if (_sessionCategoryLabel != null &&
          q.category != _sessionCategoryLabel) {
        return false;
      }
      if (_sessionMediumCategoryLabel != null &&
          q.mediumCategory != _sessionMediumCategoryLabel) {
        return false;
      }
      if (_sessionQuestionIds != null && !_sessionQuestionIds!.contains(q.id)) {
        return false;
      }
      return true;
    }).toList();

    _current = _scheduler.pickNext(
      questions: filteredQuestions,
      states: _states,
      now: DateTime.now(),
      excludeId: previous,
    );
    notifyListeners();
  }

  Future<void> resetProgress() async {
    await _progressRepo.resetAll();
    // 履歴が無くなれば復習の予定も無い。消し忘れると身に覚えのない通知が届く。
    await _notifications.cancelAll();
    _states = {};
    _streak = const StreakData();
    _session.clear();
    _result = null;
    _current = null;
    notifyListeners();
  }

  Future<bool> importProgress(String raw) async {
    final ok = await _progressRepo.importJson(raw);
    if (!ok) return false;

    _states = await _progressRepo.loadStates();
    _streak = await _progressRepo.loadStreak();
    notifyListeners();
    // 読み込んだ履歴に合わせて復習の予定も組み直す。
    await finishSession();
    return true;
  }
}
