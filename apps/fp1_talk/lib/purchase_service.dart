import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'config.dart';

class PurchaseCancelledException implements Exception {}

/// RevenueCat。app_user_id にはバックエンドの匿名ユーザーIDをそのまま使う。
/// これで Webhook がどの匿名ユーザーの購入か判別できる。
class PurchaseService {
  PurchaseService._();
  static bool _configured = false;
  static bool get isAvailable => AppConfig.revenueCatPublicApiKey.isNotEmpty;

  static Future<void> ensureConfigured(String appUserId) async {
    if (!isAvailable) return;
    if (_configured) {
      await Purchases.logIn(appUserId);
      return;
    }
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatPublicApiKey)..appUserID = appUserId,
    );
    _configured = true;
  }

  static Future<Offerings?> offerings(String appUserId) async {
    if (!isAvailable) return null;
    await ensureConfigured(appUserId);
    return Purchases.getOfferings();
  }

  static Future<void> purchase(String appUserId, Package package) async {
    await ensureConfigured(appUserId);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseCancelledException();
      }
      rethrow;
    }
  }

  /// Guideline 3.1.1: 明示的な「購入を復元」ボタンからのみ呼ぶ。
  static Future<CustomerInfo?> restore(String appUserId) async {
    if (!isAvailable) return null;
    await ensureConfigured(appUserId);
    return Purchases.restorePurchases();
  }
}
