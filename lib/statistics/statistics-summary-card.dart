import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/category-type.dart';
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
    final categoriesByType = _aggregateCategoriesByType();
    final sectionCount = _countNonEmptySections(categoriesByType);

    // Calculate total for all records when a date is selected
    double totalAmount = 0.0;
    if (widget.selectedDate != null) {
      final recordsToUse = _getFilteredRecords();
      totalAmount =
          recordsToUse.fold<double>(0.0, (sum, r) => sum + (r?.value ?? 0.0));
    }

    return Column(
      children: [
        // Show "All categories" row when a date is selected
        if (widget.selectedDate != null)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Column(
              children: [
                ViewAllSummaryRow(
                  label: "All categories".i18n,
                  totalAmount: totalAmount,
                  onTapCallback: () => _navigateToAllCategories(),
                ),
                Divider()
              ],
            )
          ),
        if (categoriesByType[CategoryType.income]!.isNotEmpty)
          _buildCategoryTypeSection(
            title: "Income".i18n,
            categories: categoriesByType[CategoryType.income]!,
            hideHeaderOverride: sectionCount == 1,
          ),
        if (categoriesByType[CategoryType.expense]!.isNotEmpty)
          _buildCategoryTypeSection(
            title: "Expenses".i18n,
            categories: categoriesByType[CategoryType.expense]!,
            hideHeaderOverride: sectionCount == 1,
          ),
      ],
    );
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

  /// Aggregates records by category type (Income/Expense).
  Map<CategoryType, List<CategorySumTuple>> _aggregateCategoriesByType() {
    final categoriesByType = <CategoryType, List<CategorySumTuple>>{
      CategoryType.income: [],
      CategoryType.expense: [],
    };

    final recordsToUse = _getFilteredRecords();
    final aggregatedCategories = _aggregateCategories(recordsToUse);

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

  /// Aggregates records by category name and type.
  Map<String, CategorySumTuple> _aggregateCategories(List<Record?> records) {
    final aggregatedCategories = <String, CategorySumTuple>{};

    for (var record in records) {
      if (record?.category == null) continue;

      final uniqueKey =
          '${record!.category!.name}_${record.category!.categoryType}';
      aggregatedCategories.update(
        uniqueKey,
        (tuple) => CategorySumTuple(tuple.key, tuple.value + record.value!),
        ifAbsent: () => CategorySumTuple(record.category!, record.value!),
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
  }) {
    final totalSum =
        categories.fold<double>(0.0, (sum, cat) => sum + cat.value.abs());
    final maxSum =
        categories.isNotEmpty ? categories[0].value.abs().toDouble() : 0.0;
    final isExpanded = title == "Income".i18n ? _showIncome : _showExpenses;

    return Column(
      children: [
        if (widget.showHeaders && !hideHeaderOverride)
          _buildSectionHeader(
            title: title,
            totalSum: totalSum,
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
            ),
          ),
      ],
    );
  }

  /// Builds the header for a collapsible section.
  Widget _buildSectionHeader({
    required String title,
    required double totalSum,
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
            Text(
              getCurrencyValueString(totalSum),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
    final aggregatedTags = _aggregateTags(recordsToUse);

    // Calculate total for all records when a date is selected
    double totalAmount = 0.0;
    if (widget.selectedDate != null) {
      final recordsForTotal = _getFilteredRecordsForTags();
      totalAmount = recordsForTotal.fold<double>(
          0.0, (sum, r) => sum + (r?.value ?? 0.0));
    }

    final List<Widget> children = [];

    // Show "All tags" row when a date is selected
    if (widget.selectedDate != null) {
      children.add(
        Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: ViewAllSummaryRow(
                label: "All tags".i18n,
                totalAmount: totalAmount,
                onTapCallback: () => _navigateToAllCategories(),
              ),
            ),
            Divider()
          ],
        )
      );
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
      final tagsAndSums = aggregatedTags.entries.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

      final totalSum = tagsAndSums.fold<double>(0.0, (sum, e) => sum + e.value);
      final maxSum = tagsAndSums.isNotEmpty ? tagsAndSums[0].value : 0.0;

      children.add(
        AggregatedListView<MapEntry<String, double>>(
          items: tagsAndSums,
          itemBuilder: (context, entry, i) => TagSummaryRow(
            tag: entry.key,
            value: entry.value,
            maxSum: maxSum,
            totalSum: totalSum,
            records: widget.records,
            from: widget.from,
            to: widget.to,
            selectedDate: widget.selectedDate,
            aggregationMethod: widget.aggregationMethod,
            isBalance: widget.isBalance,
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

  /// Aggregates records by tag.
  Map<String, double> _aggregateTags(List<Record?> records) {
    final aggregatedTags = <String, double>{};

    for (var record in records) {
      if (record == null) continue;

      for (var tag in record.tags) {
        // Skip tags that are in topCategories when showing "Others"
        if (widget.selectedCategoryOrTag == "Others".i18n &&
            widget.topCategories != null &&
            widget.topCategories!.contains(tag)) {
          continue;
        }

        aggregatedTags.update(
          tag,
          (value) => value + record.value!.abs(),
          ifAbsent: () => record.value!.abs(),
        );
      }
    }

    return aggregatedTags;
  }
}
