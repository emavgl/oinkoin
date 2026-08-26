import 'types/product_details_response.dart';
import 'types/purchase_details.dart';
import 'types/purchase_param.dart';

/// Minimal stub of the real InAppPurchase singleton.
class InAppPurchase {
  InAppPurchase._();

  static final InAppPurchase _instance = InAppPurchase._();
  static InAppPurchase get instance => _instance;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  Future<bool> isAvailable() async => false;

  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: identifiers.toList(),
  );

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      false;

  Future<void> completePurchase(PurchaseDetails purchase) async {}

  Future<void> restorePurchases({String? applicationUserName}) async {}

  T getPlatformAddition<T>() => throw UnsupportedError('No platform');
}
