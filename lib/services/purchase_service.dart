import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement_store.dart';

/// Wraps the store billing for the single one-time "unlock" product. Works once
/// the product ([productId]) exists in the Play Console / App Store Connect;
/// before that, [buy] reports that the product isn't available yet.
class PurchaseService extends ChangeNotifier {
  /// Must match the managed-product / non-consumable ID created in the stores.
  static const productId = 'word_sprint_unlock';

  final EntitlementStore entitlement;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  ProductDetails? product;
  bool available = false;
  String? lastError;

  PurchaseService(this.entitlement);

  Future<void> init() async {
    try {
      available = await _iap.isAvailable();
      _sub = _iap.purchaseStream.listen(
        _onUpdates,
        onError: (e) {
          lastError = '$e';
          notifyListeners();
        },
      );
      if (available) {
        final resp = await _iap.queryProductDetails({productId});
        if (resp.productDetails.isNotEmpty) {
          product = resp.productDetails.first;
        }
      }
    } catch (e) {
      lastError = '$e';
    }
    notifyListeners();
  }

  /// Localized price from the store, or a sensible default before setup.
  String get priceLabel => product?.price ?? '\$2.99';

  Future<void> buy() async {
    if (product == null) {
      lastError = 'The store product isn\'t set up yet.';
      notifyListeners();
      return;
    }
    await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product!));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if ((p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) &&
          p.productID == productId) {
        await entitlement.setPurchased(true);
      }
      if (p.status == PurchaseStatus.error) {
        lastError = p.error?.message ?? 'Purchase error';
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
