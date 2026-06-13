import 'dart:math';

extension NumRounding on num {
  double roundWithDecimals(int decimalPlaces) {
    if (isInfinite || isNaN) {
      return toDouble();
    }

    num mod = pow(10.0, decimalPlaces);
    return ((this * mod).round().toDouble() / mod);
  }
}
