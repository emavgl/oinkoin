import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    // Reset the notifier to its cold-start default so each test simulates a
    // fresh app launch.
    ServiceConfig.showHomepageImageNotifier.value = true;
  });

  test(
      'initShowHomepageImage syncs the notifier to false when the persisted '
      'preference is false', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.showHomepageImage, false);

    ServiceConfig.initShowHomepageImage();

    expect(ServiceConfig.showHomepageImageNotifier.value, isFalse);
  });

  test(
      'initShowHomepageImage keeps the notifier enabled when the persisted '
      'preference is true', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.showHomepageImage, true);

    ServiceConfig.initShowHomepageImage();

    expect(ServiceConfig.showHomepageImageNotifier.value, isTrue);
  });

  test(
      'setShowHomepageImage persists the preference and updates the notifier',
      () async {
    ServiceConfig.setShowHomepageImage(false);

    expect(
      ServiceConfig.sharedPreferences!
          .getBool(PreferencesKeys.showHomepageImage),
      isFalse,
    );
    expect(ServiceConfig.showHomepageImageNotifier.value, isFalse);
  });
}
