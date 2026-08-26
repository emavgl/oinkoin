import 'package:in_app_purchase/in_app_purchase.dart';

class GooglePlayPurchaseDetails extends PurchaseDetails {
  GooglePlayPurchaseDetails({
    super.purchaseID,
    required super.productID,
    required super.verificationData,
    required super.transactionDate,
    required super.status,
  });
}
