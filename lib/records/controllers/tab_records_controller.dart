import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/utils/constants.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../categories/categories-tab-page-view.dart';
import '../../helpers/alert-dialog-builder.dart';
import '../../helpers/datetime-utility-functions.dart';
import '../../helpers/records-utility-functions.dart';
import '../../i18n.dart';
import '../../models/category.dart';
import '../../models/record.dart';
import '../../models/wallet.dart';
import '../../wallets/wallet-picker-page.dart';
import '../../services/backup-service.dart';
import '../../services/csv-service.dart';
import '../../services/database/database-interface.dart';
import '../../services/platform-file-service.dart';
import '../../services/profile-service.dart';
import '../../services/recurrent-record-service.dart';
import '../../services/service-config.dart';
import '../../settings/constants/homepage-time-interval.dart';
import '../../settings/constants/overview-time-interval.dart';
import '../../settings/constants/preferences-keys.dart';
import '../../settings/preferences-utils.dart';
import '../components/filter_modal_content.dart';

class TabRecordsController {
  final VoidCallback onStateChanged;
  final DatabaseInterface _database = ServiceConfig.database;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<CategoryTabPageViewState> _categoryTabPageViewStateKey =
      GlobalKey();

  // State variables
  List<Record?> records = [];
  List<Record?>? overviewRecords;
  List<Record?> filteredRecords = [];
  List<Category?> categories = [];
  List<String> tags = [];

  // Filters state variable
  List<Category?> selectedCategories = [];
  List<String> selectedTags = [];
  bool categoryTagOrLogic = true;
  bool tagORLogic = false;

  // Wallet filter state
  List<Wallet> allWallets = [];
  List<Wallet> selectedWallets = [];
  bool _walletPrefsLoaded = false;
  int? _walletPrefsProfileId;

  String header = "";
  String _activeProfileName = '';
  int backgroundImageIndex = DateTime.now().month;
  DateTime? customIntervalFrom;
  DateTime? customIntervalTo;
  bool isSearchingEnabled = false;
  bool _isNavigating = false;

  TabRecordsController({required this.onStateChanged}) {
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> initialize() async {
    await reloadProfileName();
    await updateRecurrentRecordsAndFetchRecords();
    await _fetchCategories();
    await _loadWallets();
  }

  Future<void> reloadProfileName() async {
    final profileId = ProfileService.instance.activeProfileId;
    if (profileId == null) {
      _activeProfileName = '';
      return;
    }
    final profile = await _database.getProfileById(profileId);
    _activeProfileName = profile?.name ?? '';
    onStateChanged();
  }

  Future<void> onResume() async {
    await updateRecurrentRecordsAndFetchRecords();
    await _loadWallets();
    runAutomaticBackup(null);
  }

  Future<void> onTabChange() async {
    await updateRecurrentRecordsAndFetchRecords();
    await _loadWallets();
    await _categoryTabPageViewStateKey.currentState?.refreshCategories();
  }

  void dispose() {
    _searchController.dispose();
  }

  // Search functionality
  void _onSearchChanged() => filterRecords();

  void startSearch() {
    isSearchingEnabled = true;
    _searchController.clear();
    selectedCategories = [];
    selectedTags = [];
    filterRecords();
    onStateChanged();
  }

  void stopSearch() {
    isSearchingEnabled = false;
    _searchController.clear();
    selectedCategories = [];
    selectedTags = [];
    filterRecords();
    onStateChanged();
  }

  void filterRecords() {
    List<Record?> tempRecords;

    final hasSearch = _searchController.text.isNotEmpty;
    final hasCategories = selectedCategories.isNotEmpty;
    final hasTags = selectedTags.isNotEmpty;

    if (!hasSearch && !hasCategories && !hasTags) {
      tempRecords = records;
    } else {
      final query = _searchController.text.toLowerCase().trim();

      tempRecords = records.where((record) {
        bool matchesSearch = !hasSearch;
        if (hasSearch) {
          matchesSearch = _matchesSmartSearch(record?.title, query) ||
              _matchesSmartSearch(record?.description, query) ||
              _matchesSmartSearch(record?.category?.name, query) ||
              _matchesSmartSearch(record?.tags.join(" "), query);
        }

        // Categories
        bool matchesCategories = !hasCategories;
        if (hasCategories) {
          matchesCategories = selectedCategories.contains(record?.category);
        }

        // Tags
        bool matchesTags = !hasTags;
        if (hasTags && record?.tags != null) {
          if (tagORLogic) {
            // OR logic: any tag matches
            matchesTags = selectedTags.any((tag) => record!.tags.contains(tag));
          } else {
            // AND logic: all tags must match
            matchesTags =
                selectedTags.every((tag) => record!.tags.contains(tag));
          }
        }

        // Combine Categories + Tags depending on user choice
        bool matchesCategoryTagCombo;
        if (hasCategories && hasTags) {
          if (categoryTagOrLogic) {
            // OR between categories and tags
            matchesCategoryTagCombo = matchesCategories || matchesTags;
          } else {
            // AND between categories and tags
            matchesCategoryTagCombo = matchesCategories && matchesTags;
          }
        } else {
          // If only one of them is active, just use that result
          matchesCategoryTagCombo = matchesCategories && matchesTags;
        }

        // Final check includes search
        return matchesSearch && matchesCategoryTagCombo;
      }).toList();
    }

    // Wallet filter
    if (selectedWallets.isNotEmpty) {
      final selectedIds = selectedWallets.map((w) => w.id).toSet();
      tempRecords =
          tempRecords.where((r) => selectedIds.contains(r?.walletId)).toList();
    }

    if (!const DeepCollectionEquality().equals(filteredRecords, tempRecords)) {
      filteredRecords = tempRecords;
      onStateChanged();
    }
  }

  bool _matchesSmartSearch(String? text, String query) {
    if (text == null || text.isEmpty) return false;

    final textLower = text.toLowerCase();

    // Split the text into words (handling multiple spaces, punctuation, etc.)
    final words = textLower
        .split(RegExp(r'[\s\-_.,;:!?()]+'))
        .where((word) => word.isNotEmpty)
        .toList();

    // Check if any word starts with the query
    return words.any((word) => word.startsWith(query));
  }

  // Data fetching
  Future<void> updateRecurrentRecordsAndFetchRecords() async {
    final activeProfileId = ProfileService.instance.activeProfileId;
    var recurrentRecordService =
        RecurrentRecordService(profileId: activeProfileId);
    final int startDay = getHomepageRecordsMonthStartDay();
    HomepageTimeInterval hti = getHomepageTimeIntervalEnumSetting();

    DateTime intervalFrom;
    DateTime intervalTo;

    if (customIntervalFrom != null) {
      // If the user has manual navigation (Forward/Back), respect it
      intervalFrom = customIntervalFrom!;
      intervalTo = customIntervalTo!;
    } else if (startDay != 1 && hti == HomepageTimeInterval.CurrentMonth) {
      // If it's a custom start day and we are in "Month" view, calculate the cycle
      var cycle = calculateMonthCycle(DateTime.now(), startDay);
      intervalFrom = cycle[0];
      intervalTo = cycle[1];
      header =
          "${getShortDateStr(intervalFrom)} - ${getShortDateStr(intervalTo)}";
    } else {
      // Standard logic (Week, Year, or Day 1 Month)
      var interval =
          await getTimeIntervalFromHomepageTimeInterval(_database, hti);
      intervalFrom = interval[0];
      intervalTo = interval[1];
      header = getHeaderFromHomepageTimeInterval(hti);
    }

    // Check if future records should be shown
    final prefs = await SharedPreferences.getInstance();
    final showFutureRecords = PreferencesUtils.getOrDefault<bool>(
            prefs, PreferencesKeys.showFutureRecords) ??
        true;

    // Calculate the view end date based on the current interval and preference
    DateTime viewEndDate;
    if (showFutureRecords) {
      if (customIntervalFrom != null) {
        viewEndDate = customIntervalTo!;
      } else {
        var hti = getHomepageTimeIntervalEnumSetting();
        var interval =
            await getTimeIntervalFromHomepageTimeInterval(_database, hti);
        viewEndDate = interval[1]; // End date of the interval
      }
    } else {
      // If future records are disabled, only generate up to end of today
      final nowUtc = DateTime.now().toUtc();
      viewEndDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day)
          .add(DateTimeConstants.END_OF_DAY)
          .add(const Duration(milliseconds: 999));
    }

    // Update recurrent records and get future records
    List<Record> futureRecords =
        await recurrentRecordService.updateRecurrentRecords(viewEndDate);

    // Fetch records from database
    List<Record?> newRecords;
    newRecords = await getRecordsByInterval(_database, intervalFrom, intervalTo,
        profileId: activeProfileId);
    backgroundImageIndex = isFullYear(intervalFrom, intervalTo)
        ? DateTime.now().month
        : intervalFrom.month;

    // Filter future records to only include those within the current time interval.
    // Use calendar-date comparison in the record's own timezone to avoid cross-timezone
    // bleed (e.g. a Vienna-timezone May 1 record appearing in the April London view).
    final fromDate =
        DateTime(intervalFrom.year, intervalFrom.month, intervalFrom.day);
    final toDate = DateTime(intervalTo.year, intervalTo.month, intervalTo.day);

    List<Record> filteredFutureRecords = futureRecords.where((record) {
      final recordLocal = record.dateTime;
      final recordDate =
          DateTime(recordLocal.year, recordLocal.month, recordLocal.day);
      return !recordDate.isBefore(fromDate) && !recordDate.isAfter(toDate);
    }).toList();

    // Merge future records with database records (only if enabled)
    List<Record?> allRecords = showFutureRecords
        ? [...newRecords, ...filteredFutureRecords]
        : newRecords;

    records = allRecords;
    filteredRecords = allRecords;
    _extractTags(allRecords);
    _extractCategories(allRecords);
    filterRecords();

    // Handle overview records
    OverviewTimeInterval overviewTimeIntervalEnum =
        getHomepageOverviewWidgetTimeIntervalEnumSetting();
    if (overviewTimeIntervalEnum == OverviewTimeInterval.DisplayedRecords) {
      // When set to DisplayedRecords, use the filtered records
      overviewRecords = null;
    } else {
      HomepageTimeInterval recordTimeIntervalEnum =
          mapOverviewTimeIntervalToHomepageTimeInterval(
              overviewTimeIntervalEnum);
      var fetchedRecords = await getRecordsByHomepageTimeInterval(
          _database, recordTimeIntervalEnum,
          profileId: activeProfileId);
      overviewRecords = fetchedRecords;
    }

    // Refresh wallet balances since records have changed
    await _loadWallets();

    onStateChanged();
  }

  void _extractTags(List<Record?> records) {
    final Set<String> uniqueTags = {};
    for (var record in records) {
      if (record != null) {
        uniqueTags.addAll(record.tags);
      }
    }
    tags = uniqueTags.toList();
  }

  void _extractCategories(List<Record?> records) {
    final Set<Category?> uniqueCategories = {};
    for (var record in records) {
      if (record != null && record.category != null) {
        uniqueCategories.add(record.category);
      }
    }
    categories = uniqueCategories.toList();
  }

  Future<void> _fetchCategories() async {
    categories = await _database.getAllCategories();
    onStateChanged();
  }

  Future<void> _loadWallets() async {
    final wallets = await _database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    allWallets = wallets.where((w) => !w.isArchived).toList();
    if (selectedWallets.isNotEmpty) {
      // Re-sync selectedWallets so balances stay fresh after external edits
      final selectedIds = selectedWallets.map((w) => w.id).toSet();
      selectedWallets =
          allWallets.where((w) => selectedIds.contains(w.id)).toList();
    } else if (!_walletPrefsLoaded ||
        _walletPrefsProfileId != ProfileService.instance.activeProfileId) {
      // First load, or profile switched: restore saved selection for this profile
      _walletPrefsLoaded = true;
      _walletPrefsProfileId = ProfileService.instance.activeProfileId;
      selectedWallets = [];
      final profileId = ProfileService.instance.activeProfileId;
      if (profileId == null) {
        onStateChanged();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs
              .getStringList(PreferencesKeys.homePageWalletFilter(profileId)) ??
          [];
      if (savedIds.isNotEmpty) {
        final idSet = savedIds.map(int.tryParse).toSet();
        selectedWallets =
            allWallets.where((w) => idSet.contains(w.id)).toList();
        // Apply the wallet filter to already-fetched records
        filterRecords();
        // Also filter overview records if they were fetched separately
        if (overviewRecords != null) {
          overviewRecords = overviewRecords!
              .where((r) => idSet.contains(r?.walletId))
              .toList();
        }
        return;
      }
    }
    onStateChanged();
  }

  Future<void> navigateToWalletPicker(BuildContext context) async {
    final result = await Navigator.push<List<Wallet>>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPickerPage(
          multiSelect: true,
          initiallySelected: selectedWallets,
          preferencesKey: PreferencesKeys.homePageWalletFilter(
              ProfileService.instance.activeProfileId!),
        ),
      ),
    );
    if (result != null) {
      // If every wallet is selected, treat it the same as "All accounts"
      selectedWallets = result.length == allWallets.length ? [] : result;
      filterRecords();
      onStateChanged();
    }
  }

  // Navigation methods
  Future<void> navigateToAddNewRecord(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      var categoryIsSet = await _isThereSomeCategory();
      if (categoryIsSet) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryTabPageView(
              goToEditMovementPage: true,
              key: _categoryTabPageViewStateKey,
            ),
          ),
        );
        await updateRecurrentRecordsAndFetchRecords();
        await _loadWallets();
      } else {
        await _showNoCategoryDialog(context);
      }
    } finally {
      _isNavigating = false;
    }
  }

  void navigateToStatisticsPage(BuildContext context) {
    final currencyMap = walletCurrencyMap;
    if (customIntervalTo == null) {
      var hti = getHomepageTimeIntervalEnumSetting();
      getTimeIntervalFromHomepageTimeInterval(_database, hti)
          .then((userDefinedInterval) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatisticsPage(userDefinedInterval[0],
                      userDefinedInterval[1], filteredRecords,
                      walletCurrencyMap: currencyMap),
                ),
              ));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StatisticsPage(
              customIntervalFrom, customIntervalTo, filteredRecords,
              walletCurrencyMap: currencyMap),
        ),
      );
    }
  }

  // Menu and modal actions
  Future<void> handleMenuAction(BuildContext context, int index) async {
    if (index == 1) {
      await _exportToCSV();
    }
  }

  Future<void> showFilterModal(BuildContext context) async {
    List<Category?> usedCategories =
        records.map((record) => record?.category).toSet().toList();
    List<String> usedTags = records
        .expand((record) => record?.tags ?? {})
        .cast<String>()
        .toSet()
        .toList();
    await showModalBottomSheet(
      isScrollControlled: true, // This allows the modal to take more space
      context: context,
      builder: (context) {
        return FilterModalContent(
          categories: usedCategories,
          tags: usedTags,
          currentlySelectedCategories: selectedCategories,
          currentlySelectedTags: selectedTags,
          currentCategoryTagOrLogic: categoryTagOrLogic,
          currentTagsOrLogic: tagORLogic,
          onApplyFilters:
              (selectedCategories, selectedTags, categoryOR, tagOR) {
            this.selectedCategories = selectedCategories;
            this.selectedTags = selectedTags;
            this.categoryTagOrLogic = categoryOR;
            this.tagORLogic = tagOR;
            filterRecords();
          },
        );
      },
    );
  }

  // Helper methods
  Future<bool> _isThereSomeCategory() async {
    var categories = await _database.getAllCategories();
    return categories.isNotEmpty;
  }

  Future<void> _showNoCategoryDialog(BuildContext context) async {
    AlertDialogBuilder noCategoryDialog = AlertDialogBuilder(
            "No Category is set yet.".i18n)
        .addTrueButtonName("OK")
        .addSubtitle(
            "You need to set a category first. Go to Category tab and add a new category."
                .i18n);

    await showDialog(
      context: context,
      builder: (context) => noCategoryDialog.build(context),
    );
  }

  Future<void> _exportToCSV() async {
    var csvStr = CSVExporter.createCSVFromRecordList(filteredRecords);
    final path = await getApplicationDocumentsDirectory();
    var csvFile = File(path.path + "/records.csv");
    await csvFile.writeAsString(csvStr);

    // Use platform-aware service (share on mobile, save-as on desktop)
    await PlatformFileService.shareOrSaveFile(
      filePath: csvFile.path,
      suggestedName: 'oinkoin_records.csv',
    );
  }

  void runAutomaticBackup(BuildContext? context) {
    log("Checking if automatic backup should be fired!");
    BackupService.shouldCreateAutomaticBackup().then((shouldBackup) {
      if (shouldBackup) {
        log("Automatic backup fired!");
        BackupService.createAutomaticBackup().then((operationSuccess) {
          if (!operationSuccess && context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(BackupService.ERROR_MSG)),
            );
          } else {
            BackupService.removeOldAutomaticBackups();
          }
        });
      } else {
        log("Automatic backup not needed.");
      }
    });
  }

  // Date manipulation methods
  void updateCustomInterval(DateTime from, DateTime to, String newHeader) {
    customIntervalFrom = from;
    customIntervalTo = to;
    header = newHeader;
  }

  /// TODO Resets the homepage navigation to the default "Current" view.
  /// Call this whenever preferences (like Start Day or Interval) are changed.
  void resetHomepageInterval() {
    customIntervalFrom = null;
    customIntervalTo = null;
  }

  /// Navigates the homepage view forward or backward by a specific number of intervals.
  ///
  /// [shift] - An integer representing the number of periods to move.
  /// Positive moves forward in time, negative moves backward.
  ///
  /// This method:
  /// 1. Determines the current viewing period (defaults to 'now' if first load).
  /// 2. Calculates the new target period using [calculateInterval].
  /// 3. Updates the global [customIntervalFrom], [customIntervalTo], and [header].
  /// 4. Triggers a database fetch for the new date range.
  Future<void> shiftInterval(int shift) async {
    final int startDay = getHomepageRecordsMonthStartDay();
    final HomepageTimeInterval hti = getHomepageTimeIntervalEnumSetting();

    DateTime baseDate = customIntervalFrom ?? DateTime.now();

    DateTime targetRef;
    if (hti == HomepageTimeInterval.CurrentMonth) {
      // We add the shift to the month.
      targetRef = DateTime(baseDate.year, baseDate.month + shift, startDay);
    } else if (hti == HomepageTimeInterval.CurrentYear) {
      targetRef = DateTime(baseDate.year + shift, 1, 1);
    } else {
      // Weekly shift - use date-only arithmetic to avoid DST boundary issues.
      // Duration(days: N) adds exactly N*24 hours which can cross DST transitions
      // and land on a different local date than intended.
      targetRef =
          DateTime(baseDate.year, baseDate.month, baseDate.day + 7 * shift);
    }

    List<DateTime> newInterval =
        calculateInterval(hti, targetRef, monthStartDay: startDay);

    // Update the state
    customIntervalFrom = newInterval[0];
    customIntervalTo = newInterval[1];

    // Update Header (Slightly cleaner logic for Day 1 vs Cycle)
    if (hti == HomepageTimeInterval.CurrentMonth) {
      header = (startDay == 1)
          ? getMonthStr(customIntervalFrom!)
          : "${getShortDateStr(customIntervalFrom!)} - ${getShortDateStr(customIntervalTo!)}";
    } else if (hti == HomepageTimeInterval.CurrentYear) {
      header = getYearStr(customIntervalFrom!);
    } else {
      header = getWeekStr(customIntervalFrom!);
    }

    backgroundImageIndex = isFullYear(customIntervalFrom!, customIntervalTo!)
        ? DateTime.now().month
        : customIntervalFrom!.month;

    // Fetch records (now sees customIntervalFrom is not null and uses it)
    await updateRecurrentRecordsAndFetchRecords();
  }

  // Computed properties
  double getHeaderFontSize() => header.length > 13 ? 18.0 : 22.0;
  double getHeaderPaddingBottom() => header.length > 13 ? 15.0 : 13.0;

  bool canShiftBack() => isNavigable;

  bool canShiftForward() => isNavigable;

  /// Shifting is disabled only for the [HomepageTimeInterval.All] view.
  bool get isNavigable =>
      getHomepageTimeIntervalEnumSetting() != HomepageTimeInterval.All;

  TextEditingController get searchController => _searchController;

  DatabaseInterface get database => _database;

  String get activeProfileName => _activeProfileName;

  get hasActiveFilters =>
      selectedTags.isNotEmpty || selectedCategories.isNotEmpty;

  // Wallet computed properties
  double get totalWalletsBalance =>
      allWallets.fold(0.0, (sum, w) => sum + (w.balance ?? 0.0));

  double get selectedWalletsBalance {
    if (selectedWallets.isEmpty) return totalWalletsBalance;
    return selectedWallets.fold(0.0, (sum, w) => sum + (w.balance ?? 0.0));
  }

  String get selectedWalletsBalanceString {
    final wallets = selectedWallets.isEmpty
        ? allWallets.where((w) => !w.isArchived).toList()
        : selectedWallets;
    return computeCombinedBalanceString(wallets);
  }

  Map<int, String?> get walletCurrencyMap => buildWalletCurrencyMap(allWallets);

  String get walletRowLabel {
    if (selectedWallets.isEmpty) return "All accounts".i18n;
    if (selectedWallets.length == 1) return selectedWallets.first.name;
    return "%s Wallets".i18n.fill([selectedWallets.length.toString()]);
  }
}
