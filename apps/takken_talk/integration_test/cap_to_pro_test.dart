import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/config.dart';
import 'package:takken_talk/main.dart';
import 'package:takken_talk/state/app_state.dart';

/// 上限で止まる → ホームと会話に Pro の案内 → Pro になって戻る → 同じ会話で送れる。
/// 手元のサイトの USER_DAILY_TURN_CAP=2、AI はモックで動かす（購入は Webhook で代わりに起こす）:
///   flutter test integration_test/cap_to_pro_test.dart -d <シミュレーター> \
///     --dart-define=API_BASE=http://localhost:3140 --dart-define=RC_WEBHOOK_SECRET=<.dev.vars の値>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const secret = String.fromEnvironment('RC_WEBHOOK_SECRET');

  Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> say(WidgetTester tester, String text) async {
    // シミュレーターの本物のキーボードでは enterText が2回目から効かないので、入力欄に直接入れる
    final field = tester.widget<TextField>(find.byType(TextField).first);
    field.controller!.text = text;
    field.onChanged?.call(text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '送る'), warnIfMissed: false);
    await settle(tester, 6);
  }

  testWidgets('上限 → Pro → 同じ会話で送れる', (tester) async {
    expect(AppConfig.apiBase, contains('localhost'), reason: '本番に向けて動かさない');
    expect(secret, isNotEmpty);

    final api = ApiClient();
    await api.forgetUser();
    final state = AppState(api);
    await tester.pumpWidget(AppScope(state: state, child: const App()));
    await state.init();
    await settle(tester);

    // 上限まで話す
    await tester.tap(find.textContaining('から始める').first);
    await settle(tester, 8);
    for (var i = 0; i < 4 && find.text('Pro で増やす').evaluate().isEmpty; i++) {
      await say(tester, 'つづけて $i');
    }
    expect(find.text('Pro で増やす'), findsOneWidget, reason: '会話に Pro の案内');
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse, reason: '上限のあいだは送れない');
    final typed = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    expect(typed, isNotEmpty, reason: '書いた文は入力欄に戻る');

    // ホームにも案内が出る
    await state.refresh();
    await tester.pageBack();
    await settle(tester, 2);
    expect(find.text('Pro で回数を増やす'), findsOneWidget, reason: 'ホームで残り0回');

    // 開き直して、もう一度止まる
    await tester.tap(find.textContaining('第1章 ').first);
    await settle(tester, 6);
    await say(tester, 'もう一度');
    expect(find.text('Pro で増やす'), findsOneWidget);

    // Pro の画面へ。購入は Webhook で代わりに起こして閉じる
    await tester.tap(find.text('Pro で増やす'));
    await settle(tester, 3);
    final res = await http.post(
      Uri.parse('${AppConfig.apiBase}/api/v1/webhooks/revenuecat'),
      headers: {'authorization': secret, 'content-type': 'application/json'},
      body: jsonEncode({
        'event': {
          'id': 'verify-${DateTime.now().millisecondsSinceEpoch}',
          'type': 'INITIAL_PURCHASE',
          'app_user_id': api.userId,
          'product_id': 'jp.pairof.takken.talk.pro.monthly',
          'expiration_at_ms': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        },
      }),
    );
    expect(res.statusCode, 200);
    await state.refresh();
    expect(state.me?['pro'], isTrue);
    await tester.tap(find.byType(CloseButton).first);
    await settle(tester, 2);

    // 同じ画面のまま送れる
    expect(find.text('Pro で増やす'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue, reason: 'Pro になったら送れる');
    await say(tester, 'Pro になったので続けます');
    expect(find.textContaining('Pro になったので続けます'), findsWidgets);
    expect(find.textContaining('上限に達しました'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
