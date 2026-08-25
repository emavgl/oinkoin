import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'logger.dart';
import 'premium-license-store.dart';

/// The Pro product sold in the free app.
///
/// This ID must exist in Google Play Console (free flavor
/// `com.github.emavgl.piggybank`) before real purchases work; until then the
/// splash screen shows its demo state in debug builds and an offline message
/// in release builds.
class ProProductIds {
  ProProductIds._();

  /// One-time (non-consumable) purchase: unlocks Pro forever.
  /// Must exactly match the one-time product ID in Google Play Console.
  /// Google Play IDs allow lowercase letters, numbers, underscores, and
  /// periods; the previous hyphenated value could never resolve.
  static const String oneTime = 'lifetime_pro';

  static const Set<String> all = {oneTime};
}

/// Result of a product-details query, mirroring
/// `BillingManager.queryProductDetails`.
class ProProducts {
  ProProducts({this.oneTime, this.error});

  final ProductDetails? oneTime;
  final IAPError? error;

  bool get isEmpty => oneTime == null;
}

/// Outcome of a "Restore purchases" attempt, mirroring
/// `BillingManager.restorePurchases`.
class RestoreResult {
  RestoreResult({required this.found, this.error});

  final bool found;
  final IAPError? error;
}

/// Owned purchases returned by a store sync query, mirroring
/// `QueryPurchaseDetailsResponse`.
class PurchaseQueryResult {
  PurchaseQueryResult({
    required this.purchases,
    this.error,
    this.clearsLicense = true,
  });

  final List<PurchaseDetails> purchases;
  final IAPError? error;

  /// Whether an empty result means the user owns nothing. True for Android's
  /// synchronous `queryPurchasesAsync` (both in-app and subscriptions); false
  /// on iOS/macOS where owned purchases are delivered asynchronously on the
  /// purchase stream after a restore, so an empty result must not wipe a
  /// valid license.
  final bool clearsLicense;
}

/// Minimal facade over the `in_app_purchase` plugin so [PurchaseService] is
/// testable with a fake (mirrors `BillingManager`'s injected
/// `billingClientFactory`).
abstract class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases({String? applicationUserName});

  /// Queries the store for all owned purchases (Android's
  /// `queryPurchasesAsync`). On platforms without a sync query (iOS/macOS),
  /// triggers [restorePurchases] and returns an empty result — owned
  /// purchases are then delivered on the purchase stream.
  Future<PurchaseQueryResult> queryPastPurchases();
}

/// Real gateway backed by the official plugin.
class PluginPurchaseGateway implements PurchaseGateway {
  final InAppPurchase _iap = InAppPurchase.instance;

  /// Whether the billing plugin is registered on this platform.
  ///
  /// Accessing `InAppPurchasePlatform.instance` throws a
  /// [LateInitializationError] when the plugin was never registered (desktop
  /// builds, widget tests, web). That is not an error — it means this build
  /// simply has no billing — so it is reported as unavailability instead.
  bool get _billingRegistered {
    try {
      // Touching the stream getter resolves the platform instance.
      // ignore: unnecessary_statements
      _iap.purchaseStream;
      return true;
    } on Error catch (e) {
      // The platform interface throws a late-initialization error (named
      // `LateError`/`LateInitializationError`, not public in this SDK) when
      // the plugin was never registered — desktop builds, widget tests, web.
      // That means no billing on this platform; anything else is rethrown.
      if (e.runtimeType.toString().contains('Late')) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _billingRegistered
      ? _iap.purchaseStream
      : const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<bool> isAvailable() {
    if (!_billingRegistered) return Future.value(false);
    return _iap.isAvailable();
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _iap.restorePurchases(applicationUserName: applicationUserName);

  @override
  Future<PurchaseQueryResult> queryPastPurchases() async {
    if (!_billingRegistered) {
      // No billing on this platform: nothing owned, and the empty result must
      // not clear a stored license.
      return PurchaseQueryResult(purchases: const [], clearsLicense: false);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      return PurchaseQueryResult(
        purchases: response.pastPurchases,
        error: response.error,
      );
    }
    // iOS/macOS: no sync query API; restore so the purchase stream delivers
    // owned purchases asynchronously. An empty result must not clear the
    // license — the stream re-grants it a moment later.
    await _iap.restorePurchases();
    return PurchaseQueryResult(purchases: const [], clearsLicense: false);
  }
}

/// Handles the store billing lifecycle: product queries, purchase updates,
/// license persistence and restore. Mirrors `BillingManager.kt` from the
/// photobooth project.
///
/// The store is the source of truth: every successful sync writes the license
/// cache via [PremiumLicenseStore] and reports the resulting state through
/// [onPremiumChanged] (wired to `ServiceConfig` in `main.dart`).
class PurchaseService {
  PurchaseService({PurchaseGateway? gateway})
    : _gateway = gateway ?? PluginPurchaseGateway();

  /// App-wide singleton; the paywall and `main.dart` use this instance.
  static final PurchaseService instance = PurchaseService();

  static final _logger = Logger.withContext('PurchaseService');

  final PurchaseGateway _gateway;

  /// Called whenever the premium state may have changed (new purchase,
  /// restored purchase, or a sync that found no active purchase).
  void Function(bool isPremium)? onPremiumChanged;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;

  /// Subscribes to the purchase stream and syncs existing purchases from the
  /// store. Call once at startup, on platforms where billing is available.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!await _gateway.isAvailable()) {
      // No billing on this platform/build — nothing to subscribe or sync.
      return;
    }
    _initialized = true;
    _subscription = _gateway.purchaseStream.listen(_handlePurchaseUpdate);
    await syncPurchases();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  /// Queries the store for the Pro offers (mirrors
  /// `BillingManager.queryProductDetails`).
  ///
  /// Bounded by a timeout: if the store never answers (no Play services,
  /// network black hole, test environment), the caller falls back to its
  /// offline/demo state instead of spinning forever.
  Future<ProProducts> getProducts() async {
    try {
      if (!await _gateway.isAvailable().timeout(const Duration(seconds: 8))) {
        // No billing on this platform (unsupported build or missing store):
        // nothing to sell — the caller shows its offline state, silently.
        return ProProducts();
      }
      final response = await _gateway
          .queryProductDetails(ProProductIds.all)
          .timeout(const Duration(seconds: 8));
      ProductDetails? oneTime;
      for (final details in response.productDetails) {
        if (details.id == ProProductIds.oneTime) {
          oneTime = details;
        }
      }
      if (response.notFoundIDs.isNotEmpty) {
        _logger.warning(
          'Products not found in the store: ${response.notFoundIDs.join(', ')}',
        );
      }
      if (response.error != null) {
        _logger.warning('Product query returned an error: ${response.error}');
      }
      return ProProducts(oneTime: oneTime, error: response.error);
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to query product details');
      return ProProducts(
        error: IAPError(source: 'query', code: 'query_failed', message: '$e'),
      );
    }
  }

  /// Launches the billing flow for [details] (mirrors
  /// `BillingManager.launchBillingFlow`). The outcome arrives on the
  /// purchase stream.
  Future<bool> buy(ProductDetails details) async {
    try {
      return await _gateway.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to launch billing flow');
      return false;
    }
  }

  /// Restores previous purchases and reports whether an active Pro purchase
  /// was found (mirrors `BillingManager.restorePurchases`).
  Future<RestoreResult> restorePurchases() async {
    try {
      final result = await _gateway.queryPastPurchases();
      if (result.error != null) {
        return RestoreResult(found: false, error: result.error);
      }
      await _handlePurchaseList(
        result.purchases,
        fromSync: true,
        clearsLicense: result.clearsLicense,
      );
      final found = result.purchases.any(_isActiveProPurchase);
      return RestoreResult(found: found, error: null);
    } catch (e, st) {
      _logger.handle(e, st, 'Restore failed');
      return RestoreResult(
        found: false,
        error: IAPError(
          source: 'restore',
          code: 'restore_failed',
          message: '$e',
        ),
      );
    }
  }

  /// Re-syncs the local license with the store. Called at startup; mirrors
  /// `BillingManager.queryAndSyncPurchases`.
  Future<void> syncPurchases() async {
    try {
      final result = await _gateway.queryPastPurchases();
      if (result.error != null) {
        _logger.warning('Purchase sync error: ${result.error}');
        return;
      }
      await _handlePurchaseList(
        result.purchases,
        fromSync: true,
        clearsLicense: result.clearsLicense,
      );
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to sync purchases');
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    // Intentionally not awaited: the stream listener keeps delivering.
    _handlePurchaseList(purchases, fromSync: false);
  }

  bool _isActiveProPurchase(PurchaseDetails purchase) =>
      _isProProduct(purchase.productID) &&
      (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored);

  /// Grants entitlements for active Pro purchases, completes pending
  /// purchases, and clears the license when a store sync finds nothing
  /// (mirrors `BillingManager.handlePurchases`).
  Future<void> _handlePurchaseList(
    List<PurchaseDetails> purchases, {
    required bool fromSync,
    bool clearsLicense = true,
  }) async {
    var foundActive = false;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.error) {
        _logger.warning('Purchase error: ${purchase.error}');
        continue;
      }
      if (!_isProProduct(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _logger.info('Pro purchase active: ${purchase.productID}');
          // The Lifetime Pro product is a permanent entitlement.
          await PremiumLicenseStore.saveProPermanent();
          await _completeIfPending(purchase);
          foundActive = true;
        case PurchaseStatus.pending:
          // Waiting for payment confirmation — grant nothing yet.
          _logger.info('Pro purchase pending: ${purchase.productID}');
        case PurchaseStatus.canceled:
          _logger.info('Pro purchase canceled: ${purchase.productID}');
        case PurchaseStatus.error:
          break;
      }
    }

    // When syncing from the store, no active purchase means the user has not
    // bought Lifetime Pro (or the store could not find the purchase).
    if (fromSync && clearsLicense && !foundActive) {
      await PremiumLicenseStore.clear();
    }

    if (foundActive || fromSync) {
      onPremiumChanged?.call(PremiumLicenseStore.isPro());
    }
  }

  Future<void> _completeIfPending(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _gateway.completePurchase(purchase);
    } catch (e, st) {
      // Mirrors BillingManager.acknowledgePurchase: a failure is logged but
      // does not revoke the entitlement; the purchase is re-delivered on the
      // stream on the next session.
      _logger.handle(e, st, 'Failed to complete purchase');
    }
  }

  bool _isProProduct(String productId) => ProProductIds.all.contains(productId);
}
