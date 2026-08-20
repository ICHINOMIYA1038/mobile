import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// RevenueCat Public API Key (クライアント埋め込み前提の公開鍵。秘密鍵ではない)。
const revenueCatPublicApiKey = 'appl_SWQPSOnpVpRaWipTlHdTYBmcjij';

class PurchaseCancelledException implements Exception {}

class PurchaseService {
  PurchaseService._();
  static bool _configured = false;

  static Future<void> ensureConfigured() async {
    if (_configured) return;
    await Purchases.configure(PurchasesConfiguration(revenueCatPublicApiKey));
    _configured = true;
  }

  /// Proプランを購入する。[gikyokutosyokanUserId] があればそのユーザーに紐付けて
  /// 購入し、なければRevenueCatの匿名ID (`$RCAnonymousID:...`) のまま購入する。
  /// (Guideline 5.1.1(v): アカウントに紐付かない購入の前にログイン/会員登録を
  /// 必須にしてはならない。匿名購入は後から [linkPurchaseToAccount] で
  /// アカウントに紐付けられる。)
  /// ユーザーがキャンセルした場合は [PurchaseCancelledException] を投げる。
  static Future<void> purchasePro({String? gikyokutosyokanUserId}) async {
    await ensureConfigured();
    if (gikyokutosyokanUserId != null) {
      await Purchases.logIn(gikyokutosyokanUserId);
    }

    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const [];
    if (packages.isEmpty) {
      throw StateError('購入可能なプランが見つかりませんでした');
    }

    try {
      await Purchases.purchase(PurchaseParams.package(packages.first));
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseCancelledException();
      }
      rethrow;
    }
  }

  /// 匿名で購入した後、任意でサインインしたユーザーに購入を紐付ける
  /// (Guideline 5.1.1(v): 複数端末で使うための登録はあくまで任意、かつ
  /// いつでも後から行えるようにする)。
  static Future<void> linkPurchaseToAccount(String gikyokutosyokanUserId) async {
    await ensureConfigured();
    await Purchases.logIn(gikyokutosyokanUserId);
  }

  /// 過去の購入を復元する(Guideline 3.1.1: 明示的な「購入を復元」ボタンから
  /// のみ呼び出すこと)。戯曲図書館の未ログイン状態でもStoreKit側の復元自体は
  /// 必ず実行する(ログイン必須にすると審査環境等で復元操作自体が機能しなくなるため)。
  /// ログイン中はそのユーザーIDにひも付けて復元する。
  static Future<CustomerInfo> restorePurchases({
    String? gikyokutosyokanUserId,
  }) async {
    await ensureConfigured();
    if (gikyokutosyokanUserId != null) {
      await Purchases.logIn(gikyokutosyokanUserId);
    }
    return Purchases.restorePurchases();
  }
}
