enum BillingResponse {
  ok,
  error,
}

class BillingResultWrapper {
  const BillingResultWrapper({
    required this.responseCode,
    this.debugMessage = '',
  });

  final BillingResponse responseCode;
  final String debugMessage;
}
