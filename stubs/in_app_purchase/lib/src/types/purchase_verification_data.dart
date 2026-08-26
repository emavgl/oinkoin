class PurchaseVerificationData {
  PurchaseVerificationData({
    required this.localVerificationData,
    required this.serverVerificationData,
    required this.source,
  });

  final String localVerificationData;
  final String serverVerificationData;
  final String source;
}
