extension BoolConversions on bool {
  /// Convert to integer (1 for true, 0 for false)
  int toInt() {
    return this ? 1 : 0;
  }

  /// Convert to double (1.0 for true, 0.0 for false)
  double toDouble() {
    return this ? 1.0 : 0.0;
  }

  /// Chainable 'and' operation
  bool and(bool other) {
    return this && other;
  }

  /// Chainable 'or' operation
  bool or(bool other) {
    return this || other;
  }
}
