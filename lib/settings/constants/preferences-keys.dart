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

  // Custom folder where backups are stored. Empty string means the platform
  // default folder is used. Device-local, so it is excluded from portable
  // backup/restore.
  static const backupFolderPath = 'backupFolderPath';

  // SAF content URI of the Android folder picked for backups. Stored next to
  // backupFolderPath so the persisted URI grant can be reused without asking
  // the user to pick the folder again. Device-local, never exported.
  static const backupFolderUri = 'backupFolderUri';

  // Homepage
  static const homepageTimeInterval = 'homepageTimeInterval';
  static const homepageRecordsMonthStartDay = 'homepageRecordsMonthStartDay';
  static const homepageOverviewWidgetTimeInterval =
      'homepageOverviewWidgetTimeInterval';
  static const homepageRecordNotesVisible = 'homepageRecordNotesVisibleRows';

  // Lock
  static const enableAppLock = 'enableAppLock';

  // Appearance
  static const colorizeAmounts = 'colorizeAmounts';
  static const showHomepageImage = 'showHomepageImage';
  static const enableNavigationBarAnimations =
      'enableNavigationBarAnimations';

  // Privacy mode arms hiding of monetary amounts (eye button and
  // tap-to-hide). Display-only, safe to carry over via portable backup.
  static const privacyMode = 'privacyMode';

  // Persisted hidden state. Only takes effect while privacyMode is armed.
  static const privacyModeHidden = 'privacyModeHidden';

  // When true, privacy mode is enabled on every app start, regardless of
  // the persisted privacyMode value.
  static const privacyModeOnStart = 'privacyModeOnStart';

  // Mics
  static const restoreAmountOnDelete = 'restoreAmountOnDelete';
  static const enableRecordNameSuggestions = 'enableRecordNameSuggestions';
  static const visualiseTagsInMainPage = 'visualiseTagsInMainPage';
  static const showWalletInRecordList = 'showWalletInRecordList';
  static const amountInputKeyboardType = 'amountInputKeyboardType';
  static const showFutureRecords = 'showFutureRecords';

  // Categories
  static const categoryListSortOption = 'defaultCategoryListSortOption';
  static const showCategoriesAtBottom = 'showCategoriesAtBottom';

  // Wallets
  static const walletListSortOption = 'defaultWalletListSortOption';

  // Profiles
  static const profileListSortOption = 'defaultProfileListSortOption';

  // Budgets
  static const budgetsEnabled = 'budgetsEnabled';
  static const walletsEnabled = 'walletsEnabled';
  static const walletBalanceMode = 'walletBalanceMode';
  static const showWalletBarOnHomepage = 'showWalletBarOnHomepage';
  static const transferIconCodePoint = 'transferIconCodePoint';
  static const transferIconEmoji = 'transferIconEmoji';
  static const transferIconColor = 'transferIconColor';

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

  // InApp keyboard appearance
  static const inAppKeyboardScale = 'inAppKeyboardScale';
  static const inAppKeyboardBackgroundColorIndex =
      'inAppKeyboardBackgroundColorIndex';
  static const inAppKeyboardButtonColorIndex = 'inAppKeyboardButtonColorIndex';
  static const inAppKeyboardTextColorIndex = 'inAppKeyboardTextColorIndex';

  // Monthly banner (homepage background)
  static const monthlyBannerAssignments = 'monthlyBannerAssignments';
  static const monthlyBannerUploads = 'monthlyBannerUploads';
  static const reverseMonthlyImages = 'reverseMonthlyImages';
}
