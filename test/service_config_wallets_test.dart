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
    ServiceConfig.walletsEnabledNotifier.value = true;
  });

  test(
      'initWalletsEnabled syncs the notifier to false when the persisted '
      'preference is false', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.walletsEnabled, false);

    ServiceConfig.initWalletsEnabled();

    expect(ServiceConfig.walletsEnabledNotifier.value, isFalse);
  });

  test(
      'initWalletsEnabled keeps the notifier enabled when the persisted '
      'preference is true', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.walletsEnabled, true);

    ServiceConfig.initWalletsEnabled();

    expect(ServiceConfig.walletsEnabledNotifier.value, isTrue);
  });

  test(
      'initWalletsEnabled defaults to enabled when no preference is stored',
      () async {
    ServiceConfig.initWalletsEnabled();

    expect(ServiceConfig.walletsEnabledNotifier.value, isTrue);
  });
}
