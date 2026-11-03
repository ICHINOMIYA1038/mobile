import 'package:flutter/widgets.dart';

import '../api/client.dart';
import '../models/core.dart';

/// 日本時間の日付。1日の回数の区切りはサーバーも日本時間
String jstDay([DateTime? now]) => (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9)).toIso8601String().substring(0, 10);

/// アプリ全体の状態。いくつもの画面で共有するもの（自分・章の一覧・あとで復習・図のお気に入り・今日の回数）だけを持つ。
/// 画面ごとのデータは各画面が API から取る。
class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;

  /// GET /api/v1/me
  Map<String, dynamic>? me;

  /// GET /api/v1/takken/home（科目・章・進み具合・続きから・今日の回数）
  Map<String, dynamic>? home;
  Object? error;
  bool loading = false;

  /// あとで復習の問題 id
  final Set<String> bookmarks = {};

  /// お気に入りの図 id
  final Set<String> figureFavs = {};

  List<Subject> get subjects => ((home?['subjects'] as List?) ?? const []).map((s) => Subject.fromJson(s as Map<String, dynamic>)).toList();
  List<ChapterSummary> get chapters => ((home?['chapters'] as List?) ?? const []).map((c) => ChapterSummary.fromJson(c as Map<String, dynamic>)).toList();
  ChapterSummary? chapter(String id) => chapters.where((c) => c.id == id).firstOrNull;

  int get usedToday => (home?['usedToday'] as num?)?.toInt() ?? 0;
  int get capToday => (home?['capToday'] as num?)?.toInt() ?? 40;
  bool get unlimited => home?['unlimited'] == true || me?['unlimited'] == true;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.ensureUser();
      await refresh(quiet: true);
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 自分・ホーム・あとで復習・お気に入りを取り直す
  Future<void> refresh({bool quiet = false}) async {
    try {
      final results = await Future.wait([api.me(), api.home(), api.review(), api.figureBookmarks()]);
      me = results[0] as Map<String, dynamic>;
      home = results[1] as Map<String, dynamic>;
      bookmarks
        ..clear()
        ..addAll((((results[2] as Map<String, dynamic>)['bookmarked'] as List?) ?? const []).cast<String>());
      figureFavs
        ..clear()
        ..addAll(results[3] as List<String>);
      error = null;
    } catch (e) {
      error = e;
      if (quiet) rethrow;
    }
    notifyListeners();
  }

  /// 裏で取り直す（アプリに戻ったときなど）。失敗しても今の表示のままにする
  Future<void> refreshQuietly() async {
    final before = error;
    try {
      await refresh(quiet: true);
    } catch (_) {
      error = before;
    }
  }

  /// 会話・AIに聞くの返答の最後（done）で届く今日の回数を映す
  void applyTurn(Map<String, dynamic>? turn) {
    final h = home;
    if (h == null || turn == null) return;
    home = {...h, 'usedToday': turn['usedToday'] ?? h['usedToday'], 'capToday': turn['capToday'] ?? h['capToday']};
    notifyListeners();
  }

  /// あとで復習。先に画面を変え、失敗したら戻す
  Future<void> toggleBookmark(String questionId, bool on) async {
    on ? bookmarks.add(questionId) : bookmarks.remove(questionId);
    notifyListeners();
    try {
      await api.setBookmark(questionId, on);
    } catch (_) {
      on ? bookmarks.remove(questionId) : bookmarks.add(questionId);
      notifyListeners();
    }
  }

  /// 図のお気に入り。先に画面を変え、失敗したら戻す
  Future<void> toggleFigureFav(String figureId, bool on) async {
    on ? figureFavs.add(figureId) : figureFavs.remove(figureId);
    notifyListeners();
    try {
      await api.setFigureBookmark(figureId, on);
    } catch (_) {
      on ? figureFavs.remove(figureId) : figureFavs.add(figureId);
      notifyListeners();
    }
  }

  /// 学習データの削除のあとは全部取り直す
  Future<void> afterAccountChange() async {
    me = null;
    home = null;
    bookmarks.clear();
    figureFavs.clear();
    notifyListeners();
    await refresh();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }

  /// 再描画の登録をせずに読む（ボタンの押下時など）
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
