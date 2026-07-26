import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_simple/data/purchase_repository.dart';
import 'package:takken_simple/logic/study_controller.dart';
import 'package:takken_simple/main.dart';
import 'package:takken_simple/ui/screens/stats_screen.dart';

/// ストアが使えない環境を模した InAppPurchase。
/// 実機以外（テスト・シミュレータ）ではストアに繋がらないため、この状態で落ちないことが重要。
class _UnavailableIap implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('ストアが使えない環境では呼ばれないはず: ${invocation.memberName}');
}

/// StoreKit には接続できるが、App Store Connect から商品が返らない状態。
/// IAP がアプリ版と一緒に審査提出されていない場合などに発生する。
class _MissingProductIap implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: identifiers.toList(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('商品取得以外は呼ばれないはず: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PurchaseRepository> launch(
    WidgetTester tester, {
    bool adsRemoved = false,
  }) async {
    final controller = StudyController();
    final purchases = PurchaseRepository(iap: _UnavailableIap());
    await tester.runAsync(() async {
      await controller.init();
      await purchases.init();
      if (adsRemoved) await purchases.debugSetAdsRemoved(true);
    });

    await tester.pumpWidget(
      TakkenApp(controller: controller, purchases: purchases),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    addTearDown(purchases.dispose);
    return purchases;
  }

  Future<void> openStats(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
  }

  /// 成績画面は縦に長く、広告・課金の節は初期表示では画面外にある。
  /// ListView は見えている分しか組み立てないため、明示的にスクロールして出す。
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('広告削除の導線', () {
    testWidgets('未購入なら購入と復元のボタンが出て、広告の出る場所が明記される', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.text('広告について'));

      expect(find.text('広告について'), findsOneWidget);
      expect(
        find.textContaining('広告は結果画面にのみ表示され、出題中と解説中には表示しません'),
        findsOneWidget,
      );
      // 買わなくても全問解けることを明示する。機能制限で購入を迫らない。
      expect(find.textContaining('購入しなくても全ての問題を制限なく解けます'), findsOneWidget);

      expect(find.text('広告を削除する'), findsOneWidget);
      // 「購入の復元」は App Store の審査で必須要件。
      expect(find.text('購入を復元する'), findsOneWidget);
    });

    testWidgets('購入済みなら購入ボタンが消え、購入済みと表示される', (tester) async {
      await launch(tester, adsRemoved: true);
      await openStats(tester);
      await scrollTo(tester, find.textContaining('広告削除を購入済みです'));

      expect(find.textContaining('広告削除を購入済みです'), findsOneWidget);
      expect(find.text('広告を削除する'), findsNothing);
    });

    testWidgets('ストアが使えない環境で購入を押しても落ちず、理由を伝える', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.text('広告を削除する'));

      await tester.tap(find.text('広告を削除する'));
      await tester.pumpAndSettle();

      expect(find.text('この端末では購入できません'), findsOneWidget);
    });

    testWidgets('商品未登録を端末非対応と誤表示しない', (tester) async {
      final controller = StudyController();
      final purchases = PurchaseRepository(iap: _MissingProductIap());
      await tester.runAsync(() async {
        await controller.init();
        await purchases.init();
      });
      await tester.pumpWidget(
        TakkenApp(controller: controller, purchases: purchases),
      );
      await tester.pumpAndSettle();
      addTearDown(controller.dispose);
      addTearDown(purchases.dispose);

      await openStats(tester);
      await scrollTo(tester, find.text('広告を削除する'));
      await tester.tap(find.text('広告を削除する'));
      await tester.pumpAndSettle();

      expect(find.textContaining('商品情報を取得できませんでした'), findsOneWidget);
      expect(find.text('この端末では購入できません'), findsNothing);
    });

    testWidgets('ストアが使えない環境で復元を押しても落ちず、理由を伝える', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.text('購入を復元する'));

      await tester.tap(find.text('購入を復元する'));
      await tester.pumpAndSettle();

      expect(find.text('この端末では復元できません'), findsOneWidget);
    });
  });

  group('審査で見られる表示', () {
    testWidgets('プライバシーポリシーと問い合わせへの導線がアプリ内にある', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.text('プライバシーポリシー'));

      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.text('問い合わせ・誤りの報告'), findsOneWidget);
    });

    testWidgets('法令の正確性に関する断りが表示される', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.textContaining('法令改正等により最新でない場合があります'));

      expect(find.textContaining('法令改正等により最新でない場合があります'), findsOneWidget);
    });

    testWidgets('収録問題数が実データから表示される', (tester) async {
      await launch(tester);
      await openStats(tester);
      await scrollTo(tester, find.textContaining('収録 300問'));

      // ハードコードではなく assets/questions.json の実数が出ること。
      expect(find.textContaining('収録 300問'), findsOneWidget);
    });
  });

  group('URL 定数', () {
    test('プライバシーポリシーは https の公開ページを指す', () {
      expect(privacyPolicyUrl, startsWith('https://'));
      // 仮URL（pairof.jp）のまま出さない。
      expect(privacyPolicyUrl, isNot(contains('pairof.jp')));
    });

    test('問い合わせはメールを開く', () {
      expect(supportUrl, startsWith('mailto:'));
      expect(supportUrl, contains('@'));
    });
  });

  group('購入状態の保存', () {
    test('購入済みフラグは端末に残り、再起動後はストアを待たずに広告が消える', () async {
      final first = PurchaseRepository(iap: _UnavailableIap());
      await first.init();
      expect(first.adsRemoved, isFalse);
      await first.debugSetAdsRemoved(true);

      final revived = PurchaseRepository(iap: _UnavailableIap());
      await revived.init();
      expect(revived.adsRemoved, isTrue);
    });

    test('ストアが使えなくても init は落ちない', () async {
      final repo = PurchaseRepository(iap: _UnavailableIap());
      await repo.init();
      expect(repo.storeAvailable, isFalse);
      expect(repo.adsRemoved, isFalse);
      expect(repo.priceLabel, isNull);
    });
  });
}
