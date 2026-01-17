import 'package:piggybank/i18n.dart';
import 'package:piggybank/settings/constants/overview-time-interval.dart';

import '../backup-retention-period.dart';
import 'homepage-time-interval.dart';

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
    "Arabic (Saudi Arabia)": "ar-SA",
    "Dansk": "da",
    "Deutsch": "de",
    "English (US)": "en-US",
    "English (UK)": "en-GB",
    "Español": "es",
    "Français": "fr",
    "hrvatski (Hrvatska)": "hr",
    "Italiano": "it",
    "ଓଡ଼ିଆ (ଭାରତ)": "or-IN",
    "polski (Polska)": "pl",
    "Português (Brazil)": "pt-BR",
    "Português (Portugal)": "pt-PT",
    "Pусский язык": "ru",
    "Türkçe": "tr",
    "தமிழ் (இந்தியா)": "ta-IN",
    "Україна": "uk-UA",
    "Veneto": "vec-IT",
    "简化字": "zh-CN",
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
    "Records of the current month".i18n:
        HomepageTimeInterval.CurrentMonth.index,
    "Records of the current year".i18n: HomepageTimeInterval.CurrentYear.index,
    "All records".i18n: HomepageTimeInterval.All.index,
    "Records of the current week".i18n: HomepageTimeInterval.CurrentWeek.index,
  };

  static final Map<String, int> homepageOverviewWidgetTimeInterval = {
    "Displayed records".i18n: OverviewTimeInterval.DisplayedRecords.index,
    "Records of the current month".i18n:
        OverviewTimeInterval.FixCurrentMonth.index,
    "Records of the current year".i18n:
        OverviewTimeInterval.FixCurrentYear.index,
    "All records".i18n: OverviewTimeInterval.FixAllRecords.index,
  };

  static final Map<String, int> backupRetentionPeriods = {
    "Never delete".i18n: BackupRetentionPeriod.ALWAYS.index,
    "Weekly".i18n: BackupRetentionPeriod.WEEK.index,
    "Monthly".i18n: BackupRetentionPeriod.MONTH.index,
  };

  static final Map<String, int> showNotesOnHomepage = {
    "Don't show".i18n: 0,
    "Show at most one row".i18n: 1,
    "Show at most two rows".i18n: 2,
    "Show at most three rows".i18n: 3,
    "Show all rows".i18n: 1000,
  };

  static final Map<String, int> numberOfCategoriesForPieChart = {
    "4": 4,
    "5": 5,
    "6": 6,
    "8": 8,
    "10": 10,
    "All".i18n: 999,
  };

  static final Map<String, int> amountInputKeyboardType = {
    "Phone keyboard (with math symbols)".i18n: 0,
    "Number keyboard".i18n: 1,
  };
}
