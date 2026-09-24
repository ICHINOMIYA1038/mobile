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

  /// 会話中に届いた進捗を、サーバに聞き直さずに反映する。
  void applyProgress(ProgressSummary p) {
    final m = me;
    if (m == null) return;
    me = Me(
      userId: m.userId,
      nickname: m.nickname,
      examDate: m.examDate,
      plan: m.plan,
      chapters: m.chapters,
      turnCounts: m.turnCounts,
      lastChapterId: m.lastChapterId,
      progress: p,
      live: m.live,
    );
    notifyListeners();
  }

  void applyTurn(TurnInfo t, String chapterId) {
    final m = me;
    if (m == null) return;
    final counts = Map<String, int>.from(m.turnCounts);
    counts[chapterId] = (counts[chapterId] ?? 0) + 1;
    me = Me(
      userId: m.userId,
      nickname: m.nickname,
      examDate: m.examDate,
      plan: PlanInfo(
        isPro: t.isPro,
        proUntil: m.plan.proUntil,
        turnBalance: t.turnBalance,
        freeUsed: t.freeUsed,
        freeCap: t.freeCap,
      ),
      chapters: m.chapters,
      turnCounts: counts,
      lastChapterId: chapterId,
      progress: m.progress,
      live: m.live,
    );
    notifyListeners();
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
