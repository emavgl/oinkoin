import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/statistics/summary-models.dart';
import 'package:piggybank/statistics/aggregated-list-view.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/group-by-dropdown.dart';
import 'package:piggybank/statistics/summary-rows.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';

/// Displays a summary card with grouped statistics by category or tags.
///
/// Features:
/// - Toggle between Category/Tags/Records grouping
/// - Expandable sections for Income and Expense categories
/// - Progress bars showing relative amounts
/// - Navigation to detailed views on tap
class StatisticsSummaryCard extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;
  final DateTime? selectedDate;
  final String? selectedCategoryOrTag;
  final List<String>? topCategories;
  final GroupByType groupByType;
  final void Function(GroupByType) onGroupByTypeChanged;
  final bool showHeaders;
  final bool isBalance;
  final bool hideTagsSelection;
  final bool hideCategorySelection;
  final bool showRecordsToggle;

  final Map<int, String?> walletCurrencyMap;

  const StatisticsSummaryCard({
    Key? key,
    required this.records,
    this.aggregationMethod,
    this.from,
    this.to,
    this.selectedDate,
    this.selectedCategoryOrTag,
    this.topCategories,
    this.groupByType = GroupByType.category,
    required this.onGroupByTypeChanged,
    this.showHeaders = true,
    this.isBalance = false,
    this.hideTagsSelection = false,
    this.hideCategorySelection = false,
    this.showRecordsToggle = false,
    this.walletCurrencyMap = const {},
  }) : super(key: key);

  @override
  _StatisticsSummaryCardState createState() => _StatisticsSummaryCardState();
}

class _StatisticsSummaryCardState extends State<StatisticsSummaryCard> {
  bool _showIncome = true;
  bool _showExpenses = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GroupByDropdown(
          records: widget.records,
          groupByType: widget.groupByType,
          onGroupByTypeChanged: widget.onGroupByTypeChanged,
          selectedDate: widget.selectedDate,
          selectedCategoryOrTag: widget.selectedCategoryOrTag,
          topCategories: widget.topCategories,
          aggregationMethod: widget.aggregationMethod,
          showRecordsToggle: widget.showRecordsToggle,
          hideTagsSelection: widget.hideTagsSelection,
          hideCategorySelection: widget.hideCategorySelection,
        ),
        Divider(),
        _buildSummaryList(),
      ],
    );
  }

  /// Builds the appropriate summary list based on the current grouping type.
  Widget _buildSummaryList() {
    switch (widget.groupByType) {
      case GroupByType.category:
        return _buildCategoriesSummaryList();
      case GroupByType.tag:
        return _buildTagsSummaryList();
      case GroupByType.records:
        return Container(); // Records are handled by the parent widget
    }
  }

  /// Builds the categories summary list with Income and Expense sections.
  Widget _buildCategoriesSummaryList() {
    final filteredRecords = _getFilteredRecords();
    // Determine common currency: if mixed, use default currency so all amounts are comparable
    final commonCurrency = _resolveCommonCurrency(filteredRecords);
    final categoriesByType =
        _aggregateCategoriesByType(filteredRecords, commonCurrency);
    final sectionCount = _countNonEmptySections(categoriesByType);

    String? viewAllCurrency;
    String? viewAllOriginalCurrency;
    double totalAmount = 0.0;
    double totalOriginalAmount = 0.0;
    if (widget.selectedDate != null) {
      final result = commonCurrency != null
          ? computeTotalInCurrency(
              filteredRecords, widget.walletCurrencyMap, commonCurrency,
              isAbsValue: false)
          : computeConvertedTotal(filteredRecords, widget.walletCurrencyMap,
              isAbsValue: false);
      totalAmount = result.total;
      viewAllCurrency = result.currency;
      final originalResult = computeConvertedTotal(
          filteredRecords, widget.walletCurrencyMap,
          isAbsValue: false);
      totalOriginalAmount = originalResult.total;
      viewAllOriginalCurrency = originalResult.currency;
    }

    return Column(
      children: [
        if (widget.selectedDate != null)
          Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Column(
                children: [
                  ViewAllSummaryRow(
                    label: "All categories".i18n,
                    totalAmount: totalAmount,
                    onTapCallback: () => _navigateToAllCategories(),
                    currency: viewAllCurrency,
                    originalValue: totalOriginalAmount,
                    originalCurrency: viewAllOriginalCurrency,
                  ),
                  Divider()
                ],
              )),
        if (categoriesByType[CategoryType.income]!.isNotEmpty)
          _buildCategoryTypeSection(
            title: "Income".i18n,
            categories: categoriesByType[CategoryType.income]!,
            hideHeaderOverride: sectionCount == 1,
            filteredRecords: filteredRecords,
          ),
        if (categoriesByType[CategoryType.expense]!.isNotEmpty)
          _buildCategoryTypeSection(
            title: "Expenses".i18n,
            categories: categoriesByType[CategoryType.expense]!,
            hideHeaderOverride: sectionCount == 1,
            filteredRecords: filteredRecords,
          ),
      ],
    );
  }

  /// Returns the common currency to use for all aggregations.
  /// When records span multiple currencies, returns the default currency.
  /// When all records share one currency, returns that currency.
  /// Returns null if no currency is set.
  String? _resolveCommonCurrency(List<Record?> records) {
    return getDefaultCurrency();
  }

  /// Navigate to view all records for the selected period (no category filter).
  void _navigateToAllCategories() {
    if (widget.selectedDate == null) return;

    final detailFrom = widget.selectedDate;
    final detailTo =
        getEndOfInterval(widget.selectedDate!, widget.aggregationMethod);

    // Filter records by date range only (no category filter)
    // Use start of day for from and end of day for to to ensure inclusive range
    final fromDate =
        DateTime(detailFrom!.year, detailFrom.month, detailFrom.day);
    final toDate =
        DateTime(detailTo.year, detailTo.month, detailTo.day, 23, 59, 59);
    final detailRecords = widget.records.where((r) {
      final recordDate = r!.dateTime;
      return !recordDate.isBefore(fromDate) && !recordDate.isAfter(toDate);
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatisticsPage(
          detailFrom,
          detailTo,
          detailRecords,
        ),
      ),
    );
  }

  /// Aggregates [records] by category type (Income/Expense).
  Map<CategoryType, List<CategorySumTuple>> _aggregateCategoriesByType(
      List<Record?> records, String? commonCurrency) {
    final categoriesByType = <CategoryType, List<CategorySumTuple>>{
      CategoryType.income: [],
      CategoryType.expense: [],
    };

    final aggregatedCategories = _aggregateCategories(records, commonCurrency);

    for (var tuple in aggregatedCategories.values) {
      categoriesByType[tuple.key.categoryType]!.add(tuple);
    }

    // Sort by absolute value (descending)
    categoriesByType[CategoryType.expense]!
        .sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    categoriesByType[CategoryType.income]!
        .sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return categoriesByType;
  }

  /// Aggregates records by category, computing currency-aware totals.
  /// When [commonCurrency] is set, all totals are expressed in that currency.
  Map<String, CategorySumTuple> _aggregateCategories(
      List<Record?> records, String? commonCurrency) {
    final categoryRecordsMap = <String, List<Record?>>{};
    final categoryRef = <String, Category>{};

    for (var record in records) {
      if (record?.category == null) continue;
      final uniqueKey =
          '${record!.category!.name}_${record.category!.categoryType}';
      categoryRecordsMap.putIfAbsent(uniqueKey, () => []).add(record);
      categoryRef[uniqueKey] = record.category!;
    }

    final aggregatedCategories = <String, CategorySumTuple>{};
    for (var entry in categoryRecordsMap.entries) {
      final result = commonCurrency != null
          ? computeTotalInCurrency(
              entry.value, widget.walletCurrencyMap, commonCurrency,
              isAbsValue: false)
          : computeConvertedTotal(entry.value, widget.walletCurrencyMap,
              isAbsValue: false);

      final originalResult = computeConvertedTotal(
          entry.value, widget.walletCurrencyMap,
          isAbsValue: false);

      aggregatedCategories[entry.key] = CategorySumTuple(
        categoryRef[entry.key]!,
        result.total,
        currency: result.currency,
        originalValue: originalResult.total,
        originalCurrency: originalResult.currency,
      );
    }

    return aggregatedCategories;
  }

  /// Counts how many sections have data.
  int _countNonEmptySections(
      Map<CategoryType, List<CategorySumTuple>> categoriesByType) {
    var count = 0;
    if (categoriesByType[CategoryType.income]!.isNotEmpty) count++;
    if (categoriesByType[CategoryType.expense]!.isNotEmpty) count++;
    return count;
  }

  /// Filters records based on current selection criteria.
  List<Record?> _getFilteredRecords() {
    return RecordFilters.byMultipleCriteria(
      widget.records,
      date: widget.selectedDate,
      aggregationMethod: widget.aggregationMethod,
      category: widget.selectedCategoryOrTag,
      topCategories: widget.topCategories,
    );
  }

  /// Builds a collapsible section for a category type (Income or Expense).
  Widget _buildCategoryTypeSection({
    required String title,
    required List<CategorySumTuple> categories,
    required bool hideHeaderOverride,
    required List<Record?> filteredRecords,
  }) {
    final totalSum =
        categories.fold<double>(0.0, (sum, cat) => sum + cat.value.abs());
    final maxSum =
        categories.isNotEmpty ? categories[0].value.abs().toDouble() : 0.0;
    final isExpanded = title == "Income".i18n ? _showIncome : _showExpenses;

    final categoryNames = categories.map((c) => c.key.name).toSet();
    final sectionRecords = filteredRecords
        .where((r) => categoryNames.contains(r?.category?.name))
        .toList();
    final defaultCurrency = getDefaultCurrency();
    final convertedResult = defaultCurrency != null
        ? computeTotalInCurrency(
            sectionRecords, widget.walletCurrencyMap, defaultCurrency,
            isAbsValue: true)
        : computeConvertedTotal(sectionRecords, widget.walletCurrencyMap,
            isAbsValue: true);
    final breakdown = buildCurrencyBreakdown(
        sectionRecords, widget.walletCurrencyMap,
        isAbsValue: true);
    final nonEmptyCurrencies =
        breakdown.entries.where((e) => e.key.isNotEmpty).toList();
    const headerStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    Widget formattedTotalWidget;
    if (nonEmptyCurrencies.length == 1 &&
        nonEmptyCurrencies.first.key != defaultCurrency) {
      formattedTotalWidget = buildAmountWithCurrencyWidget(
        nonEmptyCurrencies.first.value,
        nonEmptyCurrencies.first.key,
        mainStyle: headerStyle,
      );
    } else {
      formattedTotalWidget = Text(
        formatRecordsTotalResult(convertedResult),
        style: headerStyle,
      );
    }

    return Column(
      children: [
        if (widget.showHeaders && !hideHeaderOverride)
          _buildSectionHeader(
            title: title,
            formattedTotalWidget: formattedTotalWidget,
            isExpanded: isExpanded,
            onTap: () => _toggleSection(title),
          ),
        if (isExpanded)
          AggregatedListView<CategorySumTuple>(
            items: categories,
            itemBuilder: (context, categorySum, i) => CategorySummaryRow(
              category: categorySum.key,
              value: categorySum.value,
              maxSum: maxSum,
              totalSum: totalSum,
              records: widget.records,
              from: widget.from,
              to: widget.to,
              selectedDate: widget.selectedDate,
              aggregationMethod: widget.aggregationMethod,
              currency: categorySum.currency,
              originalValue: categorySum.originalValue,
              originalCurrency: categorySum.originalCurrency,
            ),
          ),
      ],
    );
  }

  /// Builds the header for a collapsible section.
  Widget _buildSectionHeader({
    required String title,
    required Widget formattedTotalWidget,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                ),
                SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            formattedTotalWidget,
          ],
        ),
      ),
    );
  }

  /// Toggles the expansion state of a section.
  void _toggleSection(String title) {
    setState(() {
      if (title == "Income".i18n) {
        _showIncome = !_showIncome;
      } else {
        _showExpenses = !_showExpenses;
      }
    });
  }

  /// Builds the tags summary list.
  Widget _buildTagsSummaryList() {
    final recordsToUse = _getFilteredRecordsForTags();
    final commonCurrency = _resolveCommonCurrency(recordsToUse);
    final aggregatedTags = _aggregateTags(recordsToUse, commonCurrency);

    String? viewAllCurrency;
    String? viewAllOriginalCurrency;
    double totalAmount = 0.0;
    double totalOriginalAmount = 0.0;
    if (widget.selectedDate != null) {
      final recordsForTotal = _getFilteredRecordsForTags();
      final result = commonCurrency != null
          ? computeTotalInCurrency(
              recordsForTotal, widget.walletCurrencyMap, commonCurrency,
              isAbsValue: false)
          : computeConvertedTotal(recordsForTotal, widget.walletCurrencyMap,
              isAbsValue: false);
      totalAmount = result.total;
      viewAllCurrency = result.currency;
      final originalResult = computeConvertedTotal(
          recordsForTotal, widget.walletCurrencyMap,
          isAbsValue: false);
      totalOriginalAmount = originalResult.total;
      viewAllOriginalCurrency = originalResult.currency;
    }

    final List<Widget> children = [];

    // Show "All tags" row when a date is selected
    if (widget.selectedDate != null) {
      children.add(Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: ViewAllSummaryRow(
              label: "All tags".i18n,
              totalAmount: totalAmount,
              onTapCallback: () => _navigateToAllTags(),
              currency: viewAllCurrency,
              originalValue: totalOriginalAmount,
              originalCurrency: viewAllOriginalCurrency,
            ),
          ),
          Divider()
        ],
      ));
    }

    if (aggregatedTags.isEmpty) {
      children.add(
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            "No tags found".i18n,
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
      );
    } else {
      final tagsAndSums = aggregatedTags.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

      final totalSum = tagsAndSums.fold<double>(0.0, (sum, e) => sum + e.value);
      final maxSum = tagsAndSums.isNotEmpty ? tagsAndSums[0].value : 0.0;

      children.add(
        AggregatedListView<TagSumTuple>(
          items: tagsAndSums,
          itemBuilder: (context, tagSum, i) => TagSummaryRow(
            tag: tagSum.key,
            value: tagSum.value,
            maxSum: maxSum,
            totalSum: totalSum,
            records: widget.records,
            from: widget.from,
            to: widget.to,
            selectedDate: widget.selectedDate,
            aggregationMethod: widget.aggregationMethod,
            isBalance: widget.isBalance,
            currency: tagSum.currency,
            originalValue: tagSum.originalValue,
            originalCurrency: tagSum.originalCurrency,
          ),
        ),
      );
    }

    return Column(children: children);
  }

  /// Navigate to view all records for the selected period (no tag filter).
  void _navigateToAllTags() {
    if (widget.selectedDate == null) return;

    final detailFrom = widget.selectedDate;
    final detailTo =
        getEndOfInterval(widget.selectedDate!, widget.aggregationMethod);

    // Filter records by date range only (no tag filter)
    // Use start of day for from and end of day for to to ensure inclusive range
    final fromDate =
        DateTime(detailFrom!.year, detailFrom.month, detailFrom.day);
    final toDate =
        DateTime(detailTo.year, detailTo.month, detailTo.day, 23, 59, 59);
    final detailRecords = widget.records.where((r) {
      final recordDate = r!.dateTime;
      return !recordDate.isBefore(fromDate) && !recordDate.isAfter(toDate);
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatisticsPage(
          detailFrom,
          detailTo,
          detailRecords,
        ),
      ),
    );
  }

  /// Gets filtered records specifically for tag aggregation.
  List<Record?> _getFilteredRecordsForTags() {
    return RecordFilters.forTagAggregation(
      widget.records,
      widget.selectedDate,
      widget.aggregationMethod,
      widget.selectedCategoryOrTag,
      widget.topCategories,
    );
  }

  /// Aggregates records by tag, computing currency-aware totals.
  /// When [commonCurrency] is set, all totals are expressed in that currency.
  List<TagSumTuple> _aggregateTags(
      List<Record?> records, String? commonCurrency) {
    // Group records by tag
    final tagRecordsMap = <String, List<Record?>>{};

    for (var record in records) {
      if (record == null) continue;
      for (var tag in record.tags) {
        // Skip tags that are in topCategories when showing "Others"
        if (widget.selectedCategoryOrTag == "Others".i18n &&
            widget.topCategories != null &&
            widget.topCategories!.contains(tag)) {
          continue;
        }
        tagRecordsMap.putIfAbsent(tag, () => []).add(record);
      }
    }

    return tagRecordsMap.entries.map((entry) {
      final result = commonCurrency != null
          ? computeTotalInCurrency(
              entry.value, widget.walletCurrencyMap, commonCurrency,
              isAbsValue: true)
          : computeConvertedTotal(entry.value, widget.walletCurrencyMap,
              isAbsValue: true);
      final originalResult = computeConvertedTotal(
          entry.value, widget.walletCurrencyMap,
          isAbsValue: true);
      return TagSumTuple(entry.key, result.total,
          currency: result.currency,
          originalValue: originalResult.total,
          originalCurrency: originalResult.currency);
    }).toList();
  }
}
