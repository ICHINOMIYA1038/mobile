import 'package:flutter/widgets.dart';

import '../api/client.dart';
import '../models.dart';

/// アプリ全体の状態。/v1/me の結果を持ち、画面はこれを見て描く。
class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;

  Me? me;
  Object? error;
  bool loading = false;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.ensureUser();
      me = await api.me();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      me = await api.me();
      error = null;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  /// サーバに聞き直さずに一部だけ差し替える。
  void _patch({
    PlanInfo? plan,
    Map<String, int>? turnCounts,
    Map<String, String>? currentTopics,
    Set<String>? visitedTopics,
    String? lastChapterId,
    ProgressSummary? progress,
  }) {
    final m = me;
    if (m == null) return;
    me = Me(
      userId: m.userId,
      nickname: m.nickname,
      examDate: m.examDate,
      plan: plan ?? m.plan,
      subjects: m.subjects,
      chapters: m.chapters,
      turnCounts: turnCounts ?? m.turnCounts,
      currentTopics: currentTopics ?? m.currentTopics,
      visitedTopics: visitedTopics ?? m.visitedTopics,
      lastChapterId: lastChapterId ?? m.lastChapterId,
      progress: progress ?? m.progress,
      live: m.live,
    );
    notifyListeners();
  }

  /// 会話中に届いた進捗を反映する。
  void applyProgress(ProgressSummary p) => _patch(progress: p);

  /// AIが宣言した小テーマを、地図やホームにも即座に映す。
  void applyTopic(TopicEvent t) {
    final m = me;
    if (m == null) return;
    _patch(
      currentTopics: {...m.currentTopics, t.chapterId: t.topicKey},
      visitedTopics: {...m.visitedTopics, '${t.chapterId}/${t.topicKey}'},
    );
  }

  void applyTurn(TurnInfo t, String chapterId) {
    final m = me;
    if (m == null) return;
    _patch(
      plan: PlanInfo(
        isPro: t.isPro,
        proUntil: m.plan.proUntil,
        turnBalance: t.turnBalance,
        freeUsed: t.freeUsed,
        freeCap: t.freeCap,
      ),
      turnCounts: {...m.turnCounts, chapterId: (m.turnCounts[chapterId] ?? 0) + 1},
      lastChapterId: chapterId,
    );
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
