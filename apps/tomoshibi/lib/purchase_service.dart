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

  /// 戯曲図書館のユーザーIDでRevenueCatにログインしてからProプランを購入する。
  /// ユーザーがキャンセルした場合は [PurchaseCancelledException] を投げる。
  static Future<void> purchasePro(String gikyokutosyokanUserId) async {
    await ensureConfigured();
    await Purchases.logIn(gikyokutosyokanUserId);

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
}
