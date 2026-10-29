import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fp1_talk/api/client.dart';
import 'package:fp1_talk/main.dart';
import 'package:fp1_talk/state/app_state.dart';

/// サブスクリプションの審査用スクリーンショット（Pro の購入画面）を撮る。「SHOT 名前」で外から撮る（tool/shots.sh）。
///   tool/shots.sh <UDID> build/paywall integration_test/paywall_shot_test.dart
/// 価格（¥3,000）が出るまで待つ。出なければ、読み込めなかった状態のまま撮る（ログに出す）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Pro の購入画面', (tester) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester, 6);
    final tab = find.descendant(of: find.byType(NavigationBar), matching: find.text('設定'));
    await tester.tap(tab);
    await settle(tester, 3);
    final tile = find.textContaining('広告をなくす');
    await tester.ensureVisible(tile);
    await settle(tester, 1);
    await tester.tap(tile);
    await settle(tester, 3);
    var priced = false;
    for (var i = 0; i < 30; i++) {
      if (find.textContaining('￥').evaluate().isNotEmpty || find.textContaining('¥').evaluate().isNotEmpty) { priced = true; break; }
      await settle(tester, 1);
    }
    // ignore: avoid_print
    print('PRICED $priced');
    await settle(tester, 2);
    // ignore: avoid_print
    print('SHOT paywall');
    await settle(tester, 4);
  });
}
