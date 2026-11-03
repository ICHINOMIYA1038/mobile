import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'config.dart';

class PurchaseCancelledException implements Exception {}

/// RevenueCat の準備が時間内に終わらなかった（支払いの画面を出す前の段階）
class StoreConnectTimeout implements Exception {}

/// RevenueCat。app_user_id にはバックエンドの匿名ユーザーIDをそのまま使う。
/// これで Webhook がどの匿名ユーザーの購入か判別できる。
class PurchaseService {
  PurchaseService._();
  static bool _configured = false;
  static String? _appUserId;
  static bool get isAvailable => AppConfig.revenueCatPublicApiKey.isNotEmpty;

  /// 支払いの画面や復元の応答を待つ長さ。パスワードの入力もあるので長めにとる
  static Duration storeWait = const Duration(seconds: 60);
  static const _connectWait = Duration(seconds: 15);

  @visibleForTesting
  static Future<Offerings?> Function()? offeringsForTest;
  @visibleForTesting
  static Future<void> Function(Package)? purchaseForTest;
  @visibleForTesting
  static Future<EntitlementInfo?> Function()? proEntitlementForTest;

  static Future<void> ensureConfigured(String appUserId) async {
    if (!isAvailable) return;
    if (_configured && _appUserId == appUserId) return;
    try {
      if (_configured) {
        await Purchases.logIn(appUserId).timeout(_connectWait);
      } else {
        await Purchases.configure(
          PurchasesConfiguration(AppConfig.revenueCatPublicApiKey)..appUserID = appUserId,
        ).timeout(_connectWait);
        _configured = true;
      }
      _appUserId = appUserId;
    } on TimeoutException {
      throw StoreConnectTimeout();
    }
  }

  static Future<Offerings?> offerings(String appUserId) async {
    if (offeringsForTest != null) return offeringsForTest!();
    if (!isAvailable) return null;
    await ensureConfigured(appUserId);
    return Purchases.getOfferings();
  }

  static Future<void> purchase(String appUserId, Package package) async {
    if (purchaseForTest != null) return purchaseForTest!(package);
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

  /// 今の Pro の権利。「設定」アプリで解約して戻ってきたときに古い内容を見せないよう、毎回取り直す
  static Future<EntitlementInfo?> proEntitlement(String appUserId) async {
    if (proEntitlementForTest != null) return proEntitlementForTest!();
    if (!isAvailable) return null;
    await ensureConfigured(appUserId);
    await Purchases.invalidateCustomerInfoCache();
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active[AppConfig.proEntitlementId];
  }

  /// Guideline 3.1.1: 明示的な「購入を復元」ボタンからのみ呼ぶ。
  static Future<CustomerInfo?> restore(String appUserId) async {
    if (!isAvailable) return null;
    await ensureConfigured(appUserId);
    return Purchases.restorePurchases();
  }
}
