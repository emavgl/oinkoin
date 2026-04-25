import '../models/category.dart';

class SumTuple<T> {
  final T key;
  final double value;
  final String? currency;
  final double originalValue;
  final String? originalCurrency;
  SumTuple(this.key, this.value,
      {this.currency, this.originalValue = 0.0, this.originalCurrency});
}

class TagSumTuple extends SumTuple<String> {
  TagSumTuple(String tag, double value,
      {String? currency, double originalValue = 0.0, String? originalCurrency})
      : super(tag, value,
            currency: currency,
            originalValue: originalValue,
            originalCurrency: originalCurrency);
}

class CategorySumTuple extends SumTuple<Category> {
  CategorySumTuple(Category category, double value,
      {String? currency, double originalValue = 0.0, String? originalCurrency})
      : super(category, value,
            currency: currency,
            originalValue: originalValue,
            originalCurrency: originalCurrency);
}
