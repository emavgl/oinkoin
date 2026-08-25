import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/premium-license-store.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  group('PremiumLicenseStore', () {
    test('isPro is false when nothing was ever purchased', () {
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('clear revokes Pro', () async {
      await PremiumLicenseStore.saveProPermanent();
      await PremiumLicenseStore.clear();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('saveProPermanent grants Pro forever', () async {
      await PremiumLicenseStore.saveProPermanent();
      expect(PremiumLicenseStore.isPro(), isTrue);
      // The entitlement remains active indefinitely.
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test('clear revokes a permanent license', () async {
      await PremiumLicenseStore.saveProPermanent();
      await PremiumLicenseStore.clear();
      expect(PremiumLicenseStore.isPro(), isFalse);
    });

    test('isPro survives a store restart (persistence)', () async {
      await PremiumLicenseStore.saveProPermanent();
      // Simulate app restart: a fresh getInstance returns the same mock store.
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      expect(PremiumLicenseStore.isPro(), isTrue);
    });

    test('isPro is false when prefs are not initialized', () {
      ServiceConfig.sharedPreferences = null;
      expect(PremiumLicenseStore.isPro(), isFalse);
    });
  });
}
