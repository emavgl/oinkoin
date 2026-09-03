import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    // Cold-start defaults: feature disarmed, amounts visible.
    ServiceConfig.privacyModeEnabledNotifier.value = false;
    ServiceConfig.privacyModeHiddenNotifier.value = false;
  });

  test('init starts disarmed and visible with empty preferences', () async {
    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeEnabledNotifier.value, isFalse);
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);
  });

  test('init clears a stale hidden state while disarmed', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyModeHidden, true);

    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);
    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyModeHidden),
      isFalse,
    );
  });

  test('init starts hidden when armed with start-hidden on', () async {
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyMode, true);
    await ServiceConfig.sharedPreferences!
        .setBool(PreferencesKeys.privacyModeOnStart, true);

    ServiceConfig.initPrivacyMode();

    expect(ServiceConfig.privacyModeEnabledNotifier.value, isTrue);
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isTrue);
  });

  test('hide requests are ignored while disarmed', () async {
    ServiceConfig.setPrivacyModeHidden(true);

    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);
    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyModeHidden),
      isNull,
    );
  });

  test('arming does not hide by itself; disarming reveals', () async {
    ServiceConfig.setPrivacyModeEnabled(true);
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);

    ServiceConfig.setPrivacyModeHidden(true);
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isTrue);

    ServiceConfig.setPrivacyModeEnabled(false);
    expect(ServiceConfig.privacyModeEnabledNotifier.value, isFalse);
    expect(ServiceConfig.privacyModeHiddenNotifier.value, isFalse);
    expect(
      ServiceConfig.sharedPreferences!.getBool(PreferencesKeys.privacyModeHidden),
      isFalse,
    );
  });
}
