import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:piggybank/services/premium-license-store.dart';
import 'package:piggybank/services/purchase-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [PurchaseGateway] that records every interaction, mirroring the
/// mocked `BillingClient` of `BillingManagerTest.kt`.
class FakePurchaseGateway implements PurchaseGateway {
  final _purchasesController =
      StreamController<List<PurchaseDetails>>.broadcast();

  List<PurchaseDetails> queryResult = [];
  IAPError? queryError;
  bool clearsLicense = true;
  List<ProductDetails> productDetailsResult = [];
  bool buyResult = true;
  bool isAvailableResult = true;

  final completedPurchases = <PurchaseDetails>[];
  final restoreCalls = <String?>[];
  PurchaseParam? lastBuyParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchasesController.stream;

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: productDetailsResult,
    notFoundIDs: identifiers
        .where((id) => !productDetailsResult.any((p) => p.id == id))
        .toList(),
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastBuyParam = purchaseParam;
    return buyResult;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls.add(applicationUserName);
  }

  @override
  Future<PurchaseQueryResult> queryPastPurchases() async => PurchaseQueryResult(
    purchases: queryResult,
    error: queryError,
    clearsLicense: clearsLicense,
  );

  void emit(List<PurchaseDetails> purchases) {
    _purchasesController.add(purchases);
  }
}

PurchaseDetails purchase(
  String productId, {
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pending = false,
}) => PurchaseDetails(
  purchaseID: 'pid-$productId',
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: 'server',
    source: 'google_play',
  ),
  transactionDate: '1234567890',
  status: status,
)..pendingCompletePurchase = pending;

ProductDetails product(String id, {double price = 4.99}) => ProductDetails(
  id: id,
  title: 'title-$id',
  description: 'desc-$id',
  price: '\$$price',
  rawPrice: price,
  currencyCode: 'USD',
);

void main() {
  late FakePurchaseGateway gateway;
  late PurchaseService service;
  final premiumChanges = <bool>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    gateway = FakePurchaseGateway();
    service = PurchaseService(gateway: gateway)
      ..onPremiumChanged = premiumChanges.add;
  });

  tearDown(() {
    service.dispose();
    premiumChanges.clear();
  });

  group('initialize', () {
    test(
      'subscribes to the purchase stream and syncs existing purchases',
      () async {
        gateway.queryResult = [
          purchase(ProProductIds.oneTime, status: PurchaseStatus.restored),
        ];
        await service.initialize();
        expect(PremiumLicenseStore.isPro(), isTrue);
        expect(premiumChanges, [true]);
      },
    );

    test('sync with no purchases leaves premium off', () async {
      gateway.queryResult = [];
      await service.initialize();
      expect(PremiumLicenseStore.isPro(), isFalse);
      expect(premiumChanges, [false]);
    });

    test('initialize is idempotent', () async {
      gateway.queryResult = [];
      await service.initialize();
      await service.initialize();
      expect(gateway.restoreCalls, isEmpty); // no extra side effects tracked
    });
  });

  group('purchase stream handling', () {
    test('one-time purchase grants Pro forever', () async {
      await service.initialize();
      gateway.emit([purchase(ProProductIds.oneTime)]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isTrue);
      expect(premiumChanges.last, isTrue);
      // A permanent license survives indefinitely.
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test('restored purchase grants Pro', () async {
      await service.initialize();
      gateway.emit([
        purchase(ProProductIds.oneTime, status: PurchaseStatus.restored),
      ]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test('pending purchase does not grant Pro', () async {
      await service.initialize();
      gateway.emit([
        purchase(ProProductIds.oneTime, status: PurchaseStatus.pending),
      ]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('canceled purchase does not grant Pro', () async {
      await service.initialize();
      gateway.emit([
        purchase(ProProductIds.oneTime, status: PurchaseStatus.canceled),
      ]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('error purchase is ignored without crashing', () async {
      await service.initialize();
      gateway.emit([
        purchase(ProProductIds.oneTime)..status = PurchaseStatus.error,
      ]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('non-Pro products are ignored', () async {
      await service.initialize();
      gateway.emit([purchase('some_other_product')]);
      await pumpEventQueue();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('pending purchase is completed after being granted', () async {
      await service.initialize();
      final p = purchase(ProProductIds.oneTime, pending: true);
      gateway.emit([p]);
      await pumpEventQueue();
      expect(gateway.completedPurchases, contains(p));
    });

    test('already-completed purchases are not completed again', () async {
      await service.initialize();
      final p = purchase(ProProductIds.oneTime, pending: false);
      gateway.emit([p]);
      await pumpEventQueue();
      expect(gateway.completedPurchases, isEmpty);
    });
  });

  group('syncPurchases', () {
    test('clears the license when the store has no active purchase', () async {
      await PremiumLicenseStore.saveProPermanent();
      expect(PremiumLicenseStore.isPro(), isTrue);

      gateway.queryResult = [];
      await service.syncPurchases();

      expect(PremiumLicenseStore.isPro(), isFalse);
      expect(premiumChanges.last, isFalse);
    });

    test('keeps the license when an active purchase is found', () async {
      gateway.queryResult = [purchase(ProProductIds.oneTime)];
      await service.syncPurchases();
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test(
      'does not clear when the store cannot be queried synchronously',
      () async {
        // iOS/macOS path: owned purchases arrive asynchronously on the stream,
        // so an empty query result must not wipe a valid license.
        await PremiumLicenseStore.saveProPermanent();
        expect(PremiumLicenseStore.isPro(), isTrue);

        gateway.clearsLicense = false;
        gateway.queryResult = [];
        await service.syncPurchases();

        expect(PremiumLicenseStore.isPro(), isTrue);
      },
    );

    test('does not touch the license when the query fails', () async {
      await PremiumLicenseStore.saveProPermanent();
      gateway.queryError = IAPError(
        source: 'test',
        code: 'network_error',
        message: 'offline',
      );
      await service.syncPurchases();
      expect(PremiumLicenseStore.isPro(), isTrue);
      expect(premiumChanges, isEmpty);
    });
  });

  group('restorePurchases', () {
    test('reports found when an active purchase exists', () async {
      gateway.queryResult = [purchase(ProProductIds.oneTime)];
      final result = await service.restorePurchases();
      expect(result.found, isTrue);
      expect(result.error, isNull);
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test('reports not found when there are no purchases', () async {
      gateway.queryResult = [];
      final result = await service.restorePurchases();
      expect(result.found, isFalse);
      expect(result.error, isNull);
    });

    test('propagates query errors', () async {
      gateway.queryError = IAPError(
        source: 'test',
        code: 'restore_failed',
        message: 'boom',
      );
      final result = await service.restorePurchases();
      expect(result.found, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('getProducts', () {
    test('returns the Lifetime Pro product details', () async {
      gateway.productDetailsResult = [
        product(ProProductIds.oneTime, price: 4.99),
      ];
      final products = await service.getProducts();
      expect(products.oneTime?.id, ProProductIds.oneTime);
      expect(products.isEmpty, isFalse);
    });

    test('returns empty when no products are configured', () async {
      gateway.productDetailsResult = [];
      final products = await service.getProducts();
      expect(products.isEmpty, isTrue);
    });

    test('returns empty silently when billing is unavailable', () async {
      // Mirrors platforms without the billing plugin (desktop builds, tests):
      // no error is raised, no store query is attempted, the caller simply
      // shows its offline state.
      gateway.isAvailableResult = false;
      gateway.productDetailsResult = [
        product(ProProductIds.oneTime, price: 4.99),
      ];
      final products = await service.getProducts();
      expect(products.isEmpty, isTrue);
      expect(products.error, isNull);
      expect(gateway.lastBuyParam, isNull);
    });

    test('survives gateway exceptions', () async {
      gateway.productDetailsResult = [];
      final throwing = _ThrowingGateway();
      final broken = PurchaseService(gateway: throwing);
      final products = await broken.getProducts();
      expect(products.isEmpty, isTrue);
      expect(products.error, isNotNull);
    });
  });

  group('buy', () {
    test('launches the billing flow with the selected product', () async {
      final details = product(ProProductIds.oneTime, price: 4.99);
      final ok = await service.buy(details);
      expect(ok, isTrue);
      expect(gateway.lastBuyParam?.productDetails, same(details));
    });

    test('returns false when the store rejects the flow', () async {
      gateway.buyResult = false;
      final ok = await service.buy(product(ProProductIds.oneTime));
      expect(ok, isFalse);
    });

    test('returns false when the gateway throws', () async {
      final broken = PurchaseService(gateway: _ThrowingGateway());
      final ok = await broken.buy(product(ProProductIds.oneTime));
      expect(ok, isFalse);
    });
  });
}

class _ThrowingGateway extends FakePurchaseGateway {
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    throw StateError('no platform');
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    throw StateError('no platform');
  }

  @override
  Future<PurchaseQueryResult> queryPastPurchases() async {
    throw StateError('no platform');
  }
}
