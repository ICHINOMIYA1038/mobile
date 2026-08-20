import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/notification_service.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../models/question.dart';

/// クイズの進行状態を管理する。状態管理パッケージを足すほどの規模ではないため、
/// ChangeNotifier + InheritedNotifier だけで済ませている。
class QuizController extends ChangeNotifier {
  QuizController({
    QuestionRepository? repository,
    ProgressRepository? progressRepository,
    NotificationService? notificationService,
    this.questionCount,
    this.units,
    this.weakReviewOnly = false,
    this.bookmarkOnly = false,
  }) : _repository = repository ?? QuestionRepository(),
       _progressRepository = progressRepository ?? ProgressRepository(),
       _notificationService = notificationService ?? NotificationService();

  final QuestionRepository _repository;
  final ProgressRepository _progressRepository;
  final NotificationService _notificationService;

  /// 1回のクイズで出題する問題数。nullなら全問出題する(苦手復習モードでは無視)。
  final int? questionCount;

  /// 出題する単元。nullまたは空なら全単元(苦手復習モードでは無視)。
  final Set<String>? units;

  /// trueの間は単元・出題数の指定を無視し、苦手問題だけを出題する。
  final bool weakReviewOnly;

  /// trueの間は単元・出題数の指定を無視し、ブックマークした問題だけを出題する。
  final bool bookmarkOnly;

  List<Question> _allQuestions = const [];
  List<Question> _questions = const [];
  Set<String> _weakIds = const {};
  Set<String> _bookmarkIds = const {};
  int _currentIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get currentIndex => _currentIndex;
  int get totalCount => _questions.length;
  int get score => _score;
  int? get selectedIndex => _selectedIndex;
  bool get isAnswered => _selectedIndex != null;

  /// 現在の問題に解答済みで、かつ正解だったかどうか。未解答ならnull。
  bool? get isCurrentCorrect =>
      isAnswered ? _selectedIndex == currentQuestion.answerIndex : null;
  bool get isFinished => _loaded && _currentIndex >= _questions.length;

  Question get currentQuestion => _questions[_currentIndex];

  bool get isCurrentBookmarked => _bookmarkIds.contains(currentQuestion.id);

  Future<void> init() async {
    _allQuestions = await _repository.loadAll();
    if (weakReviewOnly) {
      _weakIds = await _progressRepository.loadWeakQuestionIds();
    }
    _bookmarkIds = await _progressRepository.loadBookmarkedQuestionIds();
    _pickSession();
    _loaded = true;
    notifyListeners();
  }

  /// 出題する問題を選ぶ。苦手復習モードなら苦手問題だけ、ブックマークモードなら
  /// ブックマークした問題だけ、通常モードなら単元で絞り込んだ上でシャッフルして
  /// 出題数ぶんを切り出す。
  void _pickSession() {
    if (weakReviewOnly) {
      _questions = _allQuestions
          .where((q) => _weakIds.contains(q.id))
          .toList();
      return;
    }
    if (bookmarkOnly) {
      _questions = _allQuestions
          .where((q) => _bookmarkIds.contains(q.id))
          .toList();
      return;
    }

    final pool = (units == null || units!.isEmpty)
        ? _allQuestions
        : _allQuestions.where((q) => units!.contains(q.unit)).toList();
    final shuffled = List<Question>.from(pool)..shuffle();
    final count = questionCount == null
        ? shuffled.length
        : questionCount!.clamp(1, shuffled.isEmpty ? 1 : shuffled.length);
    _questions = shuffled.take(count).toList();
  }

  void selectAnswer(int index) {
    if (isAnswered || isFinished) return;
    _selectedIndex = index;
    final correct = index == currentQuestion.answerIndex;
    if (correct) {
      _score++;
    }
    unawaited(
      _progressRepository.recordAnswer(
        questionId: currentQuestion.id,
        unit: currentQuestion.unit,
        correct: correct,
      ),
    );
    notifyListeners();
  }

  Future<void> toggleBookmark() async {
    final id = currentQuestion.id;
    if (!_bookmarkIds.remove(id)) {
      _bookmarkIds.add(id);
    }
    notifyListeners();
    await _progressRepository.toggleBookmark(id);
  }

  void nextQuestion() {
    if (!isAnswered) return;
    _selectedIndex = null;
    _currentIndex++;
    if (isFinished) {
      unawaited(_onSessionComplete());
    }
    notifyListeners();
  }

  Future<void> _onSessionComplete() async {
    final streak = await _progressRepository.markStudiedToday();
    final totalCorrect = await _progressRepository.loadTotalCorrect();
    await _progressRepository.checkMilestones(
      streak: streak,
      totalCorrect: totalCorrect,
    );

    final totalAnswered = await _progressRepository.loadTotalAnswered();
    final unitStats = await _progressRepository.loadUnitStats();
    await _progressRepository.checkBadges(
      totalAnswered: totalAnswered,
      unitStats: unitStats,
      streak: streak,
    );
    if (totalCount > 0 && _score == totalCount) {
      await _progressRepository.unlockBadge(ProgressRepository.badgePerfectClear);
    }

    // 初めてクイズを終えたタイミングでだけ、通知の許可を求める。
    final alreadyAsked = await _progressRepository
        .hasAskedNotificationPermission();
    if (!alreadyAsked) {
      await _progressRepository.markAskedNotificationPermission();
      final granted = await _notificationService.requestPermission();
      if (granted) {
        await _progressRepository.setNotificationsEnabled(true);
        final minutes = await _progressRepository.loadReminderMinutes();
        await _notificationService.scheduleDailyReminder(
          hour: minutes ~/ 60,
          minute: minutes % 60,
        );
      }
    }
  }

  void restart() {
    _pickSession();
    _currentIndex = 0;
    _selectedIndex = null;
    _score = 0;
    notifyListeners();
  }
}
