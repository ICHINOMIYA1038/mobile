import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 広告削除の買い切り課金。
///
/// 非消費型（non-consumable）のため、購入は一度きりで、機種変更後は復元で戻せる。
/// App Store Connect / Play Console 側にも同じ ID で商品を登録すること。
const removeAdsProductId = 'jp.pairof.takken.remove_ads';

/// 購入処理の結果。UI はこれを見てメッセージを出し分ける。
enum PurchaseOutcome {
  purchased,
  restored,
  cancelled,
  pending,
  unavailable,
  productUnavailable,
  error,
}

/// 課金の状態管理。
///
/// ストアが使えない環境（テスト・シミュレータ・審査前）でも落ちないことを最優先にしている。
/// 購入済みフラグは端末にも保存し、起動直後からストア通信を待たずに広告を消せるようにする。
class PurchaseRepository extends ChangeNotifier {
  PurchaseRepository({InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  static const _adsRemovedKey = 'ads_removed_v1';

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _adsRemoved = false;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  ProductDetails? _product;

  /// 広告を消してよいか。これが true の間、アプリは広告を一切読み込まない。
  bool get adsRemoved => _adsRemoved;

  bool get storeAvailable => _storeAvailable;
  bool get purchasePending => _purchasePending;

  /// ストアから取得した価格（例「¥480」）。取得前は null。
  String? get priceLabel => _product?.price;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
    notifyListeners();

    // ストアが無い環境（テスト等）ではここで静かに終わる。広告は通常どおり出る。
    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (_) {
      _storeAvailable = false;
    }
    if (!_storeAvailable) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {
        _purchasePending = false;
        notifyListeners();
      },
    );

    await _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final response = await _iap.queryProductDetails({removeAdsProductId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
      }
      if (kDebugMode && response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'StoreKit product not found: ${response.notFoundIDs.join(', ')}',
        );
      }
      if (kDebugMode && response.error != null) {
        debugPrint('StoreKit product query failed: ${response.error}');
      }
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('StoreKit product query threw: $error');
      // 価格が出せないだけなので、アプリは通常どおり動かす。
    }
  }

  /// 広告削除を購入する。完了は purchaseStream 経由で通知される。
  Future<PurchaseOutcome> buyRemoveAds() async {
    if (_adsRemoved) return PurchaseOutcome.purchased;
    if (!_storeAvailable) return PurchaseOutcome.unavailable;

    final product = _product;
    if (product == null) {
      await _loadProduct();
      // StoreKit は利用できているため、端末非対応ではない。商品が App Store
      // Connect で未提出・未承認の場合もここに来るので、別の結果として扱う。
      if (_product == null) return PurchaseOutcome.productUnavailable;
    }

    _purchasePending = true;
    notifyListeners();

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      if (!started) {
        _purchasePending = false;
        notifyListeners();
        return PurchaseOutcome.error;
      }
      return PurchaseOutcome.pending;
    } catch (_) {
      _purchasePending = false;
      notifyListeners();
      return PurchaseOutcome.error;
    }
  }

  /// 購入の復元。App Store の審査では「復元できること」が必須要件。
  Future<PurchaseOutcome> restore() async {
    if (!_storeAvailable) return PurchaseOutcome.unavailable;
    try {
      await _iap.restorePurchases();
      return PurchaseOutcome.pending;
    } catch (_) {
      return PurchaseOutcome.error;
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == removeAdsProductId) {
            await _grantRemoveAds();
          }
          _purchasePending = false;

        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _purchasePending = false;
      }

      // 保留のままにするとストアが購入を再通知し続けるため、必ず完了させる。
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<void> _grantRemoveAds() async {
    _adsRemoved = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, true);
  }

  /// テスト・デバッグ用。購入状態を直接切り替える。
  @visibleForTesting
  Future<void> debugSetAdsRemoved(bool value) async {
    _adsRemoved = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, value);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
