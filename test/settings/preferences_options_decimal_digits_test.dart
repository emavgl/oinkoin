import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';

void main() {
  group('PreferencesOptions.decimalDigits', () {
    test('offers options from 0 up to 8 decimal digits', () {
      expect(PreferencesOptions.decimalDigits.values.toList(),
          [0, 1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('keys are the string representation of their value', () {
      PreferencesOptions.decimalDigits.forEach((key, value) {
        expect(key, value.toString());
      });
    });

    test('contains an entry for 8 decimal digits', () {
      expect(PreferencesOptions.decimalDigits['8'], 8);
    });
  });
}
