import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/purchase_repository.dart';
import 'firebase_options.dart';
import 'logic/study_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 計測は失敗してもアプリを止めない作りなので、ここで待って問題ない。
  await AppInsights.initialize(options: DefaultFirebaseOptions.currentPlatform);
  // 学習中に画面が回って問題文が読みにくくなるのを防ぐ。縦固定で十分なアプリ。
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const TakkenApp());
}

class TakkenApp extends StatefulWidget {
  const TakkenApp({super.key, this.controller, this.purchases});

  /// テストから初期化済みのコントローラーを差し込むための口。
  /// 本番では null で、アプリ自身が生成・初期化する。
  final StudyController? controller;
  final PurchaseRepository? purchases;

  @override
  State<TakkenApp> createState() => _TakkenAppState();
}

class _TakkenAppState extends State<TakkenApp> {
  late final StudyController _controller;
  late final PurchaseRepository _purchases;

  /// 自前で作ったものだけを破棄する。差し込まれたものは呼び出し側の持ち物。
  late final bool _ownsController;
  late final bool _ownsPurchases;

  @override
  void initState() {
    super.initState();

    final injectedController = widget.controller;
    _ownsController = injectedController == null;
    _controller = injectedController ?? StudyController();
    if (_ownsController) _controller.init();

    final injectedPurchases = widget.purchases;
    _ownsPurchases = injectedPurchases == null;
    _purchases = injectedPurchases ?? PurchaseRepository();
    if (_ownsPurchases) _purchases.init();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsPurchases) _purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudyScope(
      controller: _controller,
      child: PurchaseScope(
        purchases: _purchases,
        child: MaterialApp(
          title: 'シンプルに学ぶ宅建アプリ',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const HomeScreen(),
          // 画面遷移を screen_view として記録する。記録されるのは
          // RouteSettings.name を付けたルートだけなので、画面を追加したら
          // 名前も必ず付けること。
          navigatorObservers: AppInsights.navigatorObservers,
          builder: (context, child) {
            // 端末の文字サイズ設定を尊重しつつ、レイアウトが壊れる倍率までは許さない。
            // アクセシビリティ対応として審査でも見られる箇所。
            final scale = MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.6,
            );
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scale),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}

/// コントローラーを画面ツリーに配る。状態管理パッケージを足すほどの規模ではないため、
/// InheritedNotifier だけで済ませている。
class StudyScope extends InheritedNotifier<StudyController> {
  const StudyScope({
    super.key,
    required StudyController controller,
    required super.child,
  }) : super(notifier: controller);

  static StudyController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StudyScope>();
    assert(scope != null, 'StudyScope が見つかりません');
    return scope!.notifier!;
  }
}

/// 課金状態を画面ツリーに配る。
class PurchaseScope extends InheritedNotifier<PurchaseRepository> {
  const PurchaseScope({
    super.key,
    required PurchaseRepository purchases,
    required super.child,
  }) : super(notifier: purchases);

  static PurchaseRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PurchaseScope>();
    assert(scope != null, 'PurchaseScope が見つかりません');
    return scope!.notifier!;
  }
}
