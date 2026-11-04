import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/config.dart';
import 'package:takken_talk/purchase_service.dart';
import 'package:takken_talk/screens/pro_screen.dart';
import 'package:takken_talk/state/app_state.dart';

const _price = '¥3,000';

Package _package() => const Package(
  r'$rc_monthly',
  PackageType.monthly,
  StoreProduct(AppConfig.proProductId, '', 'Pro', 3000, _price, 'JPY'),
  PresentedOfferingContext('default', null, null),
);

void main() {
  late bool serverPro;

  setUp(() {
    serverPro = false;
    SharedPreferences.setMockInitialValues({'ps_token': 't', 'ps_user_id': 'u_1'});
    PurchaseService.storeWait = const Duration(seconds: 60);
    PurchaseService.offeringsForTest = () async => Offerings({
      'default': Offering('default', '', const {}, [_package()]),
    });
  });
  tearDown(() {
    PurchaseService.offeringsForTest = null;
    PurchaseService.purchaseForTest = null;
  });

  Future<void> open(WidgetTester tester) async {
    final state = AppState(
      ApiClient(
        baseUrl: 'http://test',
        client: MockClient((req) async {
          final body = req.url.path.endsWith('/me') ? {'pro': serverPro} : <String, Object>{'bookmarked': <Object>[], 'favorites': <Object>[]};
          return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
        }),
      ),
    );
    await tester.runAsync(state.api.ensureUser);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: ProScreen(reason: 'settings')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(_price), findsOneWidget);
  }

  bool canClose(WidgetTester tester) => tester.widget<PopScope>(find.descendant(of: find.byType(ProScreen), matching: find.byWidgetPredicate((w) => w is PopScope))).canPop;

  testWidgets('App Store が応答しなくても、閉じられて、時間が来ればボタンが戻る', (tester) async {
    final never = Completer<void>();
    PurchaseService.purchaseForTest = (_) => never.future;
    await open(tester);
    await tester.tap(find.text(_price));
    await tester.pump();
    expect(find.text(_price), findsNothing, reason: '押したあとは回っている');
    expect(canClose(tester), isTrue, reason: '応答待ちで閉じ込めない');

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('App Store から応答がありません'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(_price), findsOneWidget);
  });

  testWidgets('待つのをやめたあとで支払いが終わっても、Pro に切り替わる', (tester) async {
    final late = Completer<void>();
    PurchaseService.purchaseForTest = (_) => late.future;
    await open(tester);
    await tester.tap(find.text(_price));
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    serverPro = true;
    late.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Pro になりました'), findsOneWidget);
  });

  testWidgets('支払いのあとの確認中だけは閉じられず、確認は時間内に終わる', (tester) async {
    PurchaseService.purchaseForTest = (_) async {};
    await open(tester);
    await tester.tap(find.text(_price));
    await tester.pump();
    await tester.pump();
    expect(canClose(tester), isFalse);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('購入を受け付けました'), findsOneWidget);
    expect(canClose(tester), isTrue);
  });
}
