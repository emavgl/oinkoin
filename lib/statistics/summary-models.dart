import '../models/category.dart';

class SumTuple<T> {
  final T key;
  final double value;
  SumTuple(this.key, this.value);
}

class TagSumTuple extends SumTuple<String> {
  TagSumTuple(String tag, double value) : super(tag, value);
}

class CategorySumTuple extends SumTuple<Category> {
  CategorySumTuple(Category category, double value) : super(category, value);
}
