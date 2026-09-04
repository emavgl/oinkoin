import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/services/preferences-backup-service.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('exports portable settings and excludes sensitive/device-local keys', () async {
    await prefs.setInt(PreferencesKeys.themeColor, 2);
    await prefs.setBool(PreferencesKeys.showWalletBarOnHomepage, false);
    await prefs.setBool(PreferencesKeys.budgetsEnabled, false);
    await prefs.setBool(PreferencesKeys.privacyMode, true);
    await prefs.setBool(PreferencesKeys.privacyModeHidden, true);
    await prefs.setBool(PreferencesKeys.privacyModeOnStart, true);
    await prefs.setBool(
        PreferencesKeys.enableNavigationBarAnimations, false);
    await prefs.setInt(
        PreferencesKeys.transferIconCodePoint,
        CategoryIcons.pro_category_icons.first.codePoint);
    await prefs.setString(PreferencesKeys.backupPassword, 'secret-hash');
    await prefs.setBool(PreferencesKeys.enableAppLock, true);
    await prefs.setInt(PreferencesKeys.activeProfileId, 42);
    await prefs.setStringList(
        PreferencesKeys.homePageWalletFilter(42), ['1', '2']);
    await prefs.setString(
        PreferencesKeys.backupFolderPath, '/storage/emulated/0/Backups');
    await prefs.setString(PreferencesKeys.backupFolderUri,
        'content://com.android.externalstorage.documents/tree/primary:Backups');
    await prefs.setString(PreferencesKeys.databaseFolderPath, '/sync/oinkoin');
    await prefs.setString('future_unknown_setting', 'must not be exported');

    final exported = PreferencesBackupService.exportPreferences(prefs);

    expect(exported[PreferencesKeys.themeColor], 2);
    expect(exported[PreferencesKeys.showWalletBarOnHomepage], isFalse);
    expect(exported[PreferencesKeys.budgetsEnabled], isFalse);
    expect(exported[PreferencesKeys.privacyMode], isTrue);
    expect(exported[PreferencesKeys.privacyModeHidden], isTrue);
    expect(exported[PreferencesKeys.privacyModeOnStart], isTrue);
    expect(exported[PreferencesKeys.enableNavigationBarAnimations], isFalse);
    expect(exported[PreferencesKeys.transferIconCodePoint],
        CategoryIcons.pro_category_icons.first.codePoint);
    expect(exported.containsKey(PreferencesKeys.backupPassword), isFalse);
    expect(exported.containsKey(PreferencesKeys.enableAppLock), isFalse);
    expect(exported.containsKey(PreferencesKeys.activeProfileId), isFalse);
    expect(exported.containsKey(PreferencesKeys.homePageWalletFilter(42)),
        isFalse);
    // Device-local backup folder settings must never move to another device.
    expect(exported.containsKey(PreferencesKeys.backupFolderPath), isFalse);
    expect(exported.containsKey(PreferencesKeys.backupFolderUri), isFalse);
    // Device-local database location must never move to another device.
    expect(exported.containsKey(PreferencesKeys.databaseFolderPath), isFalse);
    // Backup automation controls stay device-local too.
    await prefs.setBool(PreferencesKeys.backupIncludeDatabase, true);
    expect(
        PreferencesBackupService.exportPreferences(prefs)
            .containsKey(PreferencesKeys.backupIncludeDatabase),
        isFalse);
    expect(exported.containsKey('future_unknown_setting'), isFalse);
  });

  test('restores valid settings while skipping unknown and invalid entries',
      () async {
    await PreferencesBackupService.restorePreferences(prefs, {
      PreferencesKeys.themeColor: 1,
      PreferencesKeys.showWalletBarOnHomepage: false,
      PreferencesKeys.budgetsEnabled: true,
      PreferencesKeys.enableNavigationBarAnimations: true,
      PreferencesKeys.transferIconEmoji: '🔄',
      PreferencesKeys.privacyMode: true,
      PreferencesKeys.privacyModeHidden: true,
      PreferencesKeys.privacyModeOnStart: 'not-a-bool',
      'removed_setting_from_an_old_version': true,
      PreferencesKeys.themeMode: 'dark',
      PreferencesKeys.walletBalanceMode: 99,
      PreferencesKeys.homepageTimeInterval: 999,
      PreferencesKeys.languageLocale: 'removed-locale',
      PreferencesKeys.currencyConversionRates: 'not-json',
      PreferencesKeys.transferIconColor: '255:invalid:0:0',
      PreferencesKeys.defaultCurrency: 123,
    });

    expect(prefs.getInt(PreferencesKeys.themeColor), 1);
    expect(prefs.getBool(PreferencesKeys.showWalletBarOnHomepage), isFalse);
    expect(prefs.getBool(PreferencesKeys.budgetsEnabled), isTrue);
    expect(prefs.getBool(PreferencesKeys.enableNavigationBarAnimations), isTrue);
    expect(prefs.getString(PreferencesKeys.transferIconEmoji), '🔄');
    expect(prefs.getBool(PreferencesKeys.privacyMode), isTrue);
    expect(prefs.getBool(PreferencesKeys.privacyModeHidden), isTrue);
    expect(prefs.containsKey(PreferencesKeys.privacyModeOnStart), isFalse);
    expect(prefs.containsKey('removed_setting_from_an_old_version'), isFalse);
    expect(prefs.containsKey(PreferencesKeys.themeMode), isFalse);
    expect(prefs.containsKey(PreferencesKeys.walletBalanceMode), isFalse);
    expect(prefs.containsKey(PreferencesKeys.homepageTimeInterval), isFalse);
    expect(prefs.containsKey(PreferencesKeys.languageLocale), isFalse);
    expect(prefs.containsKey(PreferencesKeys.currencyConversionRates), isFalse);
    expect(prefs.containsKey(PreferencesKeys.transferIconColor), isFalse);
    expect(prefs.containsKey(PreferencesKeys.defaultCurrency), isFalse);
    expect(
      prefs.containsKey(PreferencesKeys.enableNavigationBarAnimations),
      isTrue,
    );
  });

  test('skips malformed JSON and continues restoring later settings', () async {
    await PreferencesBackupService.restorePreferences(prefs, {
      PreferencesKeys.userCurrencies: '{broken json',
      PreferencesKeys.currencyConversionRates: '{"USD_EUR": 0.9}',
      PreferencesKeys.showFutureRecords: 'not-a-bool',
      PreferencesKeys.restoreAmountOnDelete: false,
      PreferencesKeys.enableNavigationBarAnimations: 'not-a-bool',
    });

    expect(prefs.containsKey(PreferencesKeys.userCurrencies), isFalse);
    expect(prefs.getString(PreferencesKeys.currencyConversionRates),
        '{"USD_EUR": 0.9}');
    expect(prefs.containsKey(PreferencesKeys.showFutureRecords), isFalse);
    expect(prefs.getBool(PreferencesKeys.restoreAmountOnDelete), isFalse);
    expect(
      prefs.containsKey(PreferencesKeys.enableNavigationBarAnimations),
      isFalse,
    );
  });

  test('rejects unknown transfer icons and malformed serialized colors',
      () async {
    await PreferencesBackupService.restorePreferences(prefs, {
      PreferencesKeys.transferIconCodePoint: 987654321,
      PreferencesKeys.transferIconColor: '255:0:0:999',
      PreferencesKeys.transferIconEmoji: '',
      PreferencesKeys.showCurrencySymbol: true,
    });

    expect(prefs.containsKey(PreferencesKeys.transferIconCodePoint), isFalse);
    expect(prefs.containsKey(PreferencesKeys.transferIconColor), isFalse);
    expect(prefs.getString(PreferencesKeys.transferIconEmoji), '');
    expect(prefs.getBool(PreferencesKeys.showCurrencySymbol), isTrue);
  });

  test('does not throw when the preferences payload is empty or arbitrary',
      () async {
    await expectLater(
      PreferencesBackupService.restorePreferences(prefs, {
        'unknown': Object(),
        'another_unknown': <String, dynamic>{'value': 1},
      }),
      completes,
    );
  });
}
