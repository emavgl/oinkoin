import 'package:intl/intl.dart';
import 'package:piggybank/settings/constants/overview-time-interval.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';

import '../../services/service-config.dart';
import '../backup-retention-period.dart';
import 'homepage-time-interval.dart';

class PreferencesDefaultValues {

  static final defaultValues = <String, dynamic>{
    PreferencesKeys.themeColor: 0, // Default theme color index
    PreferencesKeys.themeMode: 0, // Default theme mode index
    PreferencesKeys.languageLocale: "system",
    PreferencesKeys.decimalSeparator: getLocaleDecimalSeparator(), // Default locale
    PreferencesKeys.groupSeparator: getLocaleGroupingSeparator(), // Default locale
    PreferencesKeys.numberDecimalDigits: 2, // Default to 2 decimal places
    PreferencesKeys.overwriteDotValueWithComma: false, // Default to false
    PreferencesKeys.overwriteCommaValueWithDot: false, // Default to false
    PreferencesKeys.enableAutomaticBackup: false, // Default to disabled
    PreferencesKeys.enableEncryptedBackup: false,
    PreferencesKeys.enableVersionAndDateInBackupName: true,
    PreferencesKeys.backupRetentionIntervalIndex: BackupRetentionPeriod.ALWAYS.index, // Default retention period index
    PreferencesKeys.backupPassword: '', // Default to empty password
    PreferencesKeys.enableAppLock: false, // Default to disabled
    PreferencesKeys.enableRecordNameSuggestions: true, // Default to enabled
    PreferencesKeys.homepageTimeInterval: HomepageTimeInterval.CurrentMonth.index, // Default interval (e.g., current month)
    PreferencesKeys.homepageOverviewWidgetTimeInterval: OverviewTimeInterval.DisplayedRecords.index, // Default interval (e.g., current month)
    PreferencesKeys.homepageRecordNotesVisible: 0,
  };

  static String getLocaleGroupingSeparator() {
    if (ServiceConfig.currencyLocale == null) {
      NumberFormat currencyLocaleNumberFormat = new NumberFormat.currency();
      return currencyLocaleNumberFormat.symbols.GROUP_SEP;
    }
    String existingCurrencyLocale = ServiceConfig.currencyLocale.toString();
    NumberFormat currencyLocaleNumberFormat =
    new NumberFormat.currency(locale: existingCurrencyLocale);
    return currencyLocaleNumberFormat.symbols.GROUP_SEP;
  }

  static String getLocaleDecimalSeparator() {
    if (ServiceConfig.currencyLocale == null) {
      NumberFormat currencyLocaleNumberFormat = new NumberFormat.currency();
      return currencyLocaleNumberFormat.symbols.DECIMAL_SEP;
    }
    String existingCurrencyLocale = ServiceConfig.currencyLocale.toString();
    NumberFormat currencyLocaleNumberFormat =
    new NumberFormat.currency(locale: existingCurrencyLocale);
    return currencyLocaleNumberFormat.symbols.DECIMAL_SEP;
  }

}