class PreferencesKeys {
  // Theme
  static const themeColor = 'themeColor';
  static const themeMode = 'themeMode';

  // Language
  static const languageLocale = 'languageLocale';

  // Week settings
  static const firstDayOfWeek = 'firstDayOfWeek';
  static const dateFormat = 'dateFormat';

  // Number formatting
  static const decimalSeparator = 'decimalSeparator';
  static const groupSeparator = 'groupSeparator';
  static const numberDecimalDigits = 'numDecimalDigits';
  static const overwriteDotValueWithComma = 'overwriteDotValueWithComma';
  static const overwriteCommaValueWithDot = 'overwriteCommaValueWithDot';
  static const amountInputAutoDecimalShift = 'amountInputAutoDecimalShift';
  static const currencySymbolPosition = 'currencySymbolPosition';
  static const currencySymbolSpacing = 'currencySymbolSpacing';

  // Backup
  static const enableAutomaticBackup = 'enableAutomaticBackup';
  static const enableEncryptedBackup = "enableEncryptedBackup";
  static const backupRetentionIntervalIndex = 'backupRetentionIntervalIndex';
  static const backupPassword = 'backupPassword';
  static const enableVersionAndDateInBackupName =
      'enableVersionAndDateInBackupName';

  // Homepage
  static const homepageTimeInterval = 'homepageTimeInterval';
  static const homepageRecordsMonthStartDay = 'homepageRecordsMonthStartDay';
  static const homepageOverviewWidgetTimeInterval =
      'homepageOverviewWidgetTimeInterval';
  static const homepageRecordNotesVisible = 'homepageRecordNotesVisibleRows';

  // Lock
  static const enableAppLock = 'enableAppLock';

  // Mics
  static const restoreAmountOnDelete = 'restoreAmountOnDelete';
  static const enableRecordNameSuggestions = 'enableRecordNameSuggestions';
  static const visualiseTagsInMainPage = 'visualiseTagsInMainPage';
  static const showWalletInRecordList = 'showWalletInRecordList';
  static const amountInputKeyboardType = 'amountInputKeyboardType';
  static const showFutureRecords = 'showFutureRecords';

  // Categories
  static const categoryListSortOption = 'defaultCategoryListSortOption';

  // Wallets
  static const walletListSortOption = 'defaultWalletListSortOption';

  // Statistics
  static var statisticsPieChartUseCategoryColors =
      "statisticsPieChartUseCategoryColors";
  static var statisticsPieChartNumberOfCategoriesToDisplay =
      "statisticsPieChartNumberOfCategoriesToDisplay";

  // Wallet filter defaults (stored as StringList of wallet IDs; empty = all accounts)
  // Keys are scoped per profile so each profile remembers its own selection.
  static String homePageWalletFilter(int profileId) =>
      'homePageWalletFilter_$profileId';
  static String walletsTabWalletFilter(int profileId) =>
      'walletsTabWalletFilter_$profileId';

  // Currency
  static const defaultCurrency = 'defaultCurrency';
  static const showCurrencySymbol = 'showCurrencySymbol';
  static const currencyConversionRates = 'currencyConversionRates';
  static const userCurrencies = 'userCurrencies';

  // Profile
  static const activeProfileId = 'activeProfileId';
}
