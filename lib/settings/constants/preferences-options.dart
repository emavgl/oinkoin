import 'package:i18n_extension/default.i18n.dart';

import '../backup-retention-period.dart';
import '../homepage-time-interval.dart';

class PreferencesOptions {

  static final Map<String, int> themeStyleDropdown = {
    "System".i18n: 0,
    "Light".i18n: 1,
    "Dark".i18n: 2,
  };

  static final Map<String, int> themeColorDropdown = {
    "Default".i18n: 0,
    "System".i18n: 1,
    "Monthly Image".i18n: 2,
  };

  static final Map<String, String> languageDropdown = {
    "System".i18n: "system",
    "Arabic (Saudi Arabia)": "ar_SA",
    "Deutsch": "de_DE",
    "English (US)": "en_US",
    "English (UK)": "en_GB",
    "Español": "es_ES",
    "Français": "fr_FR",
    "hrvatski (Hrvatska)": "hr_HR",
    "Italiano": "it_IT",
    "ଓଡ଼ିଆ (ଭାରତ)": "or_IN",
    "polski (Polska)": "pl_PL",
    "Português (Brazil)": "pt_BR",
    "Português (Portugal)": "pt_PT",
    "Pусский язык": "ru_RU",
    "Türkçe": "tr_TR",
    "தமிழ் (இந்தியா)": "ta_IN",
    "Україна": "uk_UA",
    "Veneto": "vec_IT",
    "简化字": "zh_CN",
  };

  static final Map<String, int> decimalDigits = {
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
  };

  static final Map<String, String> groupSeparators = {
    "none".i18n: "",
    "dot".i18n: ".",
    "comma".i18n: ",",
    "space".i18n: "\u00A0",
    "underscore".i18n: "_",
    "apostrophe".i18n: "'",
  };

  static final Map<String, String> decimalSeparators = {
    "dot".i18n: ".",
    "comma".i18n: ",",
  };

  static final Map<String, int> homepageTimeInterval = {
    "Records of the current month".i18n: HomepageTimeInterval.CurrentMonth.index,
    "Records of the current year".i18n: HomepageTimeInterval.CurrentYear.index,
    "All records".i18n: HomepageTimeInterval.All.index,
  };

  static final Map<String, int> backupRetentionPeriods = {
    "Never delete".i18n: BackupRetentionPeriod.ALWAYS.index,
    "Weekly".i18n: BackupRetentionPeriod.WEEK.index,
    "Monthly".i18n: BackupRetentionPeriod.MONTH.index,
  };

}