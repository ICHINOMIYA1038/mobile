import 'package:etude_generator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 実機/シミュレータ上でAdMobの広告が実際に読み込めるかを確認するための一時的な確認用テスト。
/// ウィジェットテスト環境ではAdMob SDKが動かないため、これは `flutter test integration_test/...`
/// を実機/シミュレータ向けに実行して確かめる。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('実演画面と振り返り画面でバナー広告が読み込まれる', (tester) async {
    await tester.pumpWidget(const EtudeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('お題をつくる'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このエチュードを実行する'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('一人目の役を引く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次の人へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二人目の役を引く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('配役完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配役完了'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('エチュードを始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('エチュードを始める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('実演中'), findsOneWidget);

    // 広告は非同期で読み込まれるため、実際のネットワーク応答を待つ。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final performanceAdCount = find.byType(AdWidget).evaluate().length;
    debugPrint('[ad_smoke] 実演画面のAdWidget数: $performanceAdCount');

    await tester.tap(find.text('終了する'));
    await tester.pumpAndSettle();
    expect(find.text('振り返り'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final reflectionAdCount = find.byType(AdWidget).evaluate().length;
    debugPrint('[ad_smoke] 振り返り画面のAdWidget数: $reflectionAdCount');

    expect(tester.takeException(), isNull);
  });
}
