import '../models/category.dart';

class SumTuple<T> {
  final T key;
  final double value;
  final String? currency;
  final double originalValue;
  final String? originalCurrency;

  /// Signed (non-absolute) counterparts of [value]/[originalValue].
  ///
  /// [value] may be an absolute magnitude for display (e.g. tag and wallet
  /// totals), while the sign of the underlying data lives here so callers can
  /// color amounts by sign (red for expenses, green for income). Defaults to
  /// [value]/[originalValue] when the totals already carry their sign.
  final double signedValue;
  final double signedOriginalValue;

  SumTuple(
    this.key,
    this.value, {
    this.currency,
    this.originalValue = 0.0,
    this.originalCurrency,
    double? signedValue,
    double? signedOriginalValue,
  })  : signedValue = signedValue ?? value,
        signedOriginalValue = signedOriginalValue ?? originalValue;
}

class TagSumTuple extends SumTuple<String> {
  TagSumTuple(String tag, double value,
      {String? currency,
      double originalValue = 0.0,
      String? originalCurrency,
      double? signedValue,
      double? signedOriginalValue})
      : super(tag, value,
            currency: currency,
            originalValue: originalValue,
            originalCurrency: originalCurrency,
            signedValue: signedValue,
            signedOriginalValue: signedOriginalValue);
}

class CategorySumTuple extends SumTuple<Category> {
  CategorySumTuple(Category category, double value,
      {String? currency,
      double originalValue = 0.0,
      String? originalCurrency,
      double? signedValue,
      double? signedOriginalValue})
      : super(category, value,
            currency: currency,
            originalValue: originalValue,
            originalCurrency: originalCurrency,
            signedValue: signedValue,
            signedOriginalValue: signedOriginalValue);
}

class WalletSumTuple extends SumTuple<int> {
  WalletSumTuple(int walletId, double value,
      {String? currency,
      double originalValue = 0.0,
      String? originalCurrency,
      double? signedValue,
      double? signedOriginalValue})
      : super(walletId, value,
            currency: currency,
            originalValue: originalValue,
            originalCurrency: originalCurrency,
            signedValue: signedValue,
            signedOriginalValue: signedOriginalValue);
}
