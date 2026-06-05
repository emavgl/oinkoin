import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('getBackgroundImage', () {
    setUp(() async {
      // Reset ServiceConfig to defaults before each test
      ServiceConfig.isPremium = true;
      ServiceConfig.sharedPreferences = null;
    });

    test('returns default image when not premium', () async {
      ServiceConfig.isPremium = false;
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(1);
      expect(result.assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on invalid month index', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(-1);
      expect(result.assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on month index 0', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(0);
      expect(result.assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on month index 13', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(13);
      expect(result.assetName, 'assets/images/bkg-default.png');
    });

    group('without reversal (default)', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      });

      test('month 1 returns January image', () {
        final result = getBackgroundImage(1);
        expect(result.assetName, 'assets/images/bkg-1.png');
      });

      test('month 6 returns June image', () {
        final result = getBackgroundImage(6);
        expect(result.assetName, 'assets/images/bkg-6.png');
      });

      test('month 7 returns July image', () {
        final result = getBackgroundImage(7);
        expect(result.assetName, 'assets/images/bkg-7.png');
      });

      test('month 12 returns December image', () {
        final result = getBackgroundImage(12);
        expect(result.assetName, 'assets/images/bkg-12.png');
      });
    });

    group('with reversal enabled (Southern Hemisphere)', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({
          PreferencesKeys.reverseMonthlyImages: true,
        });
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      });

      test('month 1 (January) maps to July image (7)', () {
        final result = getBackgroundImage(1);
        // ((1 + 5) % 12) + 1 = 7
        expect(result.assetName, 'assets/images/bkg-7.png');
      });

      test('month 7 (July) maps to January image (1)', () {
        final result = getBackgroundImage(7);
        // ((7 + 5) % 12) + 1 = 1
        expect(result.assetName, 'assets/images/bkg-1.png');
      });

      test('month 12 (December) maps to June image (6)', () {
        final result = getBackgroundImage(12);
        // ((12 + 5) % 12) + 1 = 6
        expect(result.assetName, 'assets/images/bkg-6.png');
      });

      test('month 6 (June) maps to December image (12)', () {
        final result = getBackgroundImage(6);
        // ((6 + 5) % 12) + 1 = 12
        expect(result.assetName, 'assets/images/bkg-12.png');
      });

      test('all months map correctly with 6-month offset', () {
        // Verify every month maps to the expected offset month
        for (int month = 1; month <= 12; month++) {
          final result = getBackgroundImage(month);
          final expectedMonth = ((month + 5) % 12) + 1;
          expect(result.assetName, 'assets/images/bkg-$expectedMonth.png',
              reason: 'Month $month should map to month $expectedMonth');
        }
      });

      test('month 2 (February) maps to August image (8)', () {
        final result = getBackgroundImage(2);
        // ((2 + 5) % 12) + 1 = 8
        expect(result.assetName, 'assets/images/bkg-8.png');
      });

      test('month 8 (August) maps to February image (2)', () {
        final result = getBackgroundImage(8);
        // ((8 + 5) % 12) + 1 = 2
        expect(result.assetName, 'assets/images/bkg-2.png');
      });
    });

    group('when sharedPreferences is null', () {
      test('defaults to no reversal when preferences not initialized', () {
        // ServiceConfig.sharedPreferences is null
        ServiceConfig.isPremium = true;
        // This should not crash and should return the normal image
        final result = getBackgroundImage(3);
        expect(result.assetName, 'assets/images/bkg-3.png');
      });
    });
  });
}
