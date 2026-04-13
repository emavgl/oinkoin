import 'dart:math';

import 'package:intl/intl.dart';

extension FileFormatter on num {
  /// Convert the number to represent a file size in a human readable format.
  String readableFileSize({bool base1024 = true}) {
    final base = base1024 ? 1024 : 1000;
    if (this <= 0) return '0';
    final units = ['B', 'kB', 'MB', 'GB', 'TB'];
    int digitGroups = (log(this) / log(base)).round();

    return '${NumberFormat.decimalPatternDigits(decimalDigits: 1).format(this / pow(base, digitGroups))} ${units[digitGroups]}';
  }

  double roundWithDecimals(int decimalPlaces) {
    if (isInfinite || isNaN) {
      return toDouble();
    }

    num mod = pow(10.0, decimalPlaces);
    return ((this * mod).round().toDouble() / mod);
  }
}
