import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
    await recurrentRecordService.updateRecurrentRecords();

    List<Record?> newRecords;
    if (customIntervalFrom != null) {
      newRecords = await getRecordsByInterval(
          _database, customIntervalFrom, customIntervalTo);
      backgroundImageIndex = customIntervalFrom!.month;
    } else {
      var hti = getHomepageTimeIntervalEnumSetting();
      newRecords = await getRecordsByHomepageTimeInterval(_database, hti);
      header = getHeaderFromHomepageTimeInterval(hti);
      backgroundImageIndex = DateTime.now().month;
    }

    records = newRecords;
    filteredRecords = newRecords;
    _extractTags(newRecords);
    _extractCategories(newRecords);
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

  Future<void> shiftMonthWeekYear(int shift) async {
    DateTime newFrom;
    DateTime newTo;
    List<Record?> newRecords = [];
    String newHeader;

    if (customIntervalFrom != null) {
      if (isFullMonth(customIntervalFrom!, customIntervalTo!)) {
        newFrom = DateTime(
            customIntervalFrom!.year, customIntervalFrom!.month + shift, 1);
        newTo = getEndOfMonth(newFrom.year, newFrom.month);
        newHeader = getMonthStr(newFrom);
        newRecords =
            await getRecordsByMonth(_database, newFrom.year, newFrom.month);
      } else if (isFullWeek(customIntervalFrom!, customIntervalTo!)) {
        newFrom = customIntervalFrom!.add(Duration(days: 7 * shift));
        newTo = newFrom.add(Duration(days: 6));
        newHeader = getWeekStr(newFrom);
        newRecords = await getRecordsByInterval(_database, newFrom, newTo);
      } else {
        newFrom = DateTime(customIntervalFrom!.year + shift, 1, 1);
        newTo = DateTime(newFrom.year, 12, 31, 23, 59);
        newRecords = await getRecordsByYear(_database, newFrom.year);
        newHeader = getYearStr(newFrom);
      }
    } else {
      HomepageTimeInterval hti = getHomepageTimeIntervalEnumSetting();
      DateTime d = DateTime.now();
      if (hti == HomepageTimeInterval.CurrentMonth) {
        newFrom = DateTime(d.year, d.month + shift, 1);
        newTo = getEndOfMonth(newFrom.year, newFrom.month);
        newHeader = getMonthStr(newFrom);
        newRecords =
            await getRecordsByMonth(_database, newFrom.year, newFrom.month);
      } else if (hti == HomepageTimeInterval.CurrentWeek) {
        DateTime startOfWeek = getStartOfWeek(d);
        newFrom = startOfWeek.add(Duration(days: 7 * shift));
        newTo = newFrom.add(Duration(days: 6));
        newHeader = getWeekStr(newFrom);
        newRecords = await getRecordsByInterval(_database, newFrom, newTo);
      } else {
        newFrom = DateTime(d.year + shift, 1, 1);
        newTo = DateTime(newFrom.year, 12, 31, 23, 59);
        newRecords = await getRecordsByYear(_database, newFrom.year);
        newHeader = getYearStr(newFrom);
      }
    }

    customIntervalFrom = newFrom;
    customIntervalTo = newTo;
    header = newHeader;
    backgroundImageIndex = newFrom.month;
    records = newRecords;
    filterRecords();
    onStateChanged();
  }

  // Computed properties
  double getHeaderFontSize() => header.length > 13 ? 18.0 : 22.0;
  double getHeaderPaddingBottom() => header.length > 13 ? 15.0 : 13.0;

  bool canShiftBack() {
    return canShift(-1, customIntervalFrom, customIntervalTo,
        getHomepageTimeIntervalEnumSetting());
  }

  bool canShiftForward() {
    return canShift(1, customIntervalFrom, customIntervalTo,
        getHomepageTimeIntervalEnumSetting());
  }

  TextEditingController get searchController => _searchController;

  DatabaseInterface get database => _database;

  get hasActiveFilters =>
      selectedTags.isNotEmpty || selectedCategories.isNotEmpty;
}
