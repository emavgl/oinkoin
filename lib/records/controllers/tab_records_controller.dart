import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../categories/categories-tab-page-view.dart';
import '../../helpers/alert-dialog-builder.dart';
import '../../helpers/datetime-utility-functions.dart';
import '../../helpers/records-utility-functions.dart';
import '../../i18n.dart';
import '../../models/category.dart';
import '../../models/record.dart';
import '../../services/backup-service.dart';
import '../../services/csv-service.dart';
import '../../services/database/database-interface.dart';
import '../../services/platform-file-service.dart';
import '../../services/recurrent-record-service.dart';
import '../../services/service-config.dart';
import '../../settings/constants/homepage-time-interval.dart';
import '../../settings/constants/overview-time-interval.dart';
import '../../settings/constants/preferences-keys.dart';
import '../../settings/preferences-utils.dart';
import '../../statistics/statistics-page.dart';
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

  String header = "";
  int backgroundImageIndex = DateTime.now().month;
  DateTime? customIntervalFrom;
  DateTime? customIntervalTo;
  bool isSearchingEnabled = false;

  TabRecordsController({required this.onStateChanged}) {
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> initialize() async {
    await updateRecurrentRecordsAndFetchRecords();
    await _fetchCategories();
  }

  Future<void> onResume() async {
    await updateRecurrentRecordsAndFetchRecords();
    runAutomaticBackup(null);
  }

  Future<void> onTabChange() async {
    await updateRecurrentRecordsAndFetchRecords();
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
    var recurrentRecordService = RecurrentRecordService();
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
      header = "${getShortDateStr(intervalFrom)} - ${getShortDateStr(intervalTo)}";
    } else {
      // Standard logic (Week, Year, or Day 1 Month)
      var interval = await getTimeIntervalFromHomepageTimeInterval(_database, hti);
      intervalFrom = interval[0];
      intervalTo = interval[1];
      header = getHeaderFromHomepageTimeInterval(hti);
    }

    // Check if future records should be shown
    final prefs = await SharedPreferences.getInstance();
    final showFutureRecords = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.showFutureRecords) ?? true;

    // Calculate the view end date based on the current interval and preference
    DateTime viewEndDate;
    if (showFutureRecords) {
      if (customIntervalFrom != null) {
        viewEndDate = customIntervalTo!;
      } else {
        var hti = getHomepageTimeIntervalEnumSetting();
        var interval = await getTimeIntervalFromHomepageTimeInterval(_database, hti);
        viewEndDate = interval[1]; // End date of the interval
      }
    } else {
      // If future records are disabled, only generate up to end of today
      final nowUtc = DateTime.now().toUtc();
      viewEndDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 23, 59, 59, 999);
    }

    // Update recurrent records and get future records
    List<Record> futureRecords = await recurrentRecordService.updateRecurrentRecords(viewEndDate);

    // Fetch records from database
    List<Record?> newRecords;
    newRecords = await getRecordsByInterval(_database, intervalFrom, intervalTo);
    backgroundImageIndex = intervalFrom.month;
    // DateTime intervalFrom;
    // DateTime intervalTo;
    //
    // if (customIntervalFrom != null) {
    //   newRecords = await getRecordsByInterval(
    //       _database, customIntervalFrom, customIntervalTo);
    //   backgroundImageIndex = customIntervalFrom!.month;
    //   intervalFrom = customIntervalFrom!;
    //   intervalTo = customIntervalTo!;
    // } else {
    //   var hti = getHomepageTimeIntervalEnumSetting();
    //   int startDay = getHomepageRecordsMonthStartDay();
    //   newRecords = await getRecordsByHomepageTimeInterval(_database, hti, monthStartDay: startDay);
    //   header = getHeaderFromHomepageTimeInterval(hti);
    //   backgroundImageIndex = DateTime.now().month;
    //   var interval = await getTimeIntervalFromHomepageTimeInterval(_database, hti, monthStartDay: startDay);
    //   intervalFrom = interval[0];
    //   intervalTo = interval[1];
    //   debugPrint("Loading records for intervalFrom = $intervalFrom intervalTo = $intervalTo");
    // }

    // Filter future records to only include those within the current time interval
    // Convert interval bounds to UTC for proper comparison
    DateTime intervalFromUtc = intervalFrom.toUtc();
    DateTime intervalToUtc = intervalTo.toUtc();

    List<Record> filteredFutureRecords = futureRecords.where((record) {
      return (record.utcDateTime.isAfter(intervalFromUtc) ||
              record.utcDateTime.isAtSameMomentAs(intervalFromUtc)) &&
             (record.utcDateTime.isBefore(intervalToUtc) ||
              record.utcDateTime.isAtSameMomentAs(intervalToUtc));
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
          _database, recordTimeIntervalEnum);
      overviewRecords = fetchedRecords;
    }

    onStateChanged();
    debugPrint("Loading records for intervalFrom = $intervalFrom intervalTo = $intervalTo");
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

  // Navigation methods
  Future<void> navigateToAddNewRecord(BuildContext context) async {
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
    } else {
      await _showNoCategoryDialog(context);
    }
  }

  void navigateToStatisticsPage(BuildContext context) {
    if (customIntervalTo == null) {
      var hti = getHomepageTimeIntervalEnumSetting();
      getTimeIntervalFromHomepageTimeInterval(_database, hti)
          .then((userDefinedInterval) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatisticsPage(userDefinedInterval[0],
                      userDefinedInterval[1], filteredRecords),
                ),
              ));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StatisticsPage(
              customIntervalFrom, customIntervalTo, filteredRecords),
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
      // Weekly shift
      targetRef = baseDate.add(Duration(days: 7 * shift));
    }

    List<DateTime> newInterval = calculateInterval(hti, targetRef, monthStartDay: startDay);

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

    backgroundImageIndex = customIntervalFrom!.month;

    // Fetch records (now sees customIntervalFrom is not null and uses it)
    await updateRecurrentRecordsAndFetchRecords();
  }

  // Computed properties
  double getHeaderFontSize() => header.length > 13 ? 18.0 : 22.0;
  double getHeaderPaddingBottom() => header.length > 13 ? 15.0 : 13.0;

  bool canShiftBack() => isNavigable;

  bool canShiftForward() => isNavigable;

  /// Shifting is disabled only for the [HomepageTimeInterval.All] view.
  bool get isNavigable => getHomepageTimeIntervalEnumSetting() != HomepageTimeInterval.All;

  TextEditingController get searchController => _searchController;

  DatabaseInterface get database => _database;

  get hasActiveFilters =>
      selectedTags.isNotEmpty || selectedCategories.isNotEmpty;
}
