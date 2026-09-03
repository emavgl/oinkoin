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
    ServiceConfig.privacyModeNotifier.value = false;
  });

  test(
      'initPrivacyMode syncs the notifier to true when the persisted '
      'preference is true', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyMode, true);

    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeNotifier.value, isTrue);
  });

  test(
      'initPrivacyMode keeps amounts visible when no preference is stored',
      () async {
    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeNotifier.value, isFalse);
  });

  test(
      'initPrivacyMode starts hidden when start-with-privacy is on, '
      'even if privacy mode was off', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyMode, false);
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyModeOnStart, true);

    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeNotifier.value, isTrue);
    // The persisted toggle is aligned so the settings switch agrees.
    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyMode),
      isTrue,
    );
  });

  test(
      'initPrivacyMode respects the persisted toggle when start-with-privacy '
      'is off', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyMode, true);
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyModeOnStart, false);

    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeNotifier.value, isTrue);
  });

  test('setPrivacyModeOnStart persists the preference', () async {
    ServiceConfig.setPrivacyModeOnStart(true);

    expect(
      ServiceConfig.sharedPreferences!
          .getBool(PreferencesKeys.privacyModeOnStart),
      isTrue,
    );
  });

  test(
      'setPrivacyMode persists the preference and updates the notifier',
      () async {
    ServiceConfig.setPrivacyMode(true);

    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyMode),
      isTrue,
    );
    expect(ServiceConfig.privacyModeNotifier.value, isTrue);

    ServiceConfig.setPrivacyMode(false);

    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyMode),
      isFalse,
    );
    expect(ServiceConfig.privacyModeNotifier.value, isFalse);
  });
}
