import '../errors/iap_error.dart';
import 'purchase_status.dart';
import 'purchase_verification_data.dart';

class PurchaseDetails {
  PurchaseDetails({
    this.purchaseID,
    required this.productID,
    required this.verificationData,
    required this.transactionDate,
    required this.status,
  });

  final String? purchaseID;
  final String productID;
  final PurchaseVerificationData verificationData;
  final String? transactionDate;
  PurchaseStatus status;
  IAPError? error;
  bool pendingCompletePurchase = false;
}
