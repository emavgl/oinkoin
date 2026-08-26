class IAPError {
  IAPError({
    required this.source,
    required this.code,
    required this.message,
    this.details,
  });

  final String source;
  final String code;
  final String message;
  final dynamic details;
}
