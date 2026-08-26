import 'package:in_app_purchase/in_app_purchase.dart';

import '../billing_client_wrappers.dart';
import 'query_purchase_details_response.dart';

class InAppPurchaseAndroidPlatformAddition {
  Future<BillingResultWrapper> consumePurchase(PurchaseDetails purchase) async =>
      const BillingResultWrapper(responseCode: BillingResponse.error);

  Future<QueryPurchaseDetailsResponse> queryPastPurchases() async {
    return QueryPurchaseDetailsResponse(pastPurchases: const []);
  }
}
