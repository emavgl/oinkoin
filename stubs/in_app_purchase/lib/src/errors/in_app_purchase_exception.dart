class InAppPurchaseException implements Exception {
  InAppPurchaseException({required this.source, this.code, this.message});

  final String source;
  final String? code;
  final String? message;
}
