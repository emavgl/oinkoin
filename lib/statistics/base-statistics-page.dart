import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/components/records-day-list.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/record-filters.dart';

/// Abstract base class for statistics pages.
///
/// Provides common functionality for pages that display:
/// - Charts (pie charts, bar charts, balance charts)
/// - Summary cards with category/tag breakdowns
/// - Records list when in "Records" view
///
/// Subclasses must implement:
/// - [buildChartWidget]: Returns the main chart widget
/// - [buildSummaryCard]: Returns the summary card widget
/// - [onChartSelectionChanged]: Handles chart selection changes
abstract class BaseStatisticsPage extends StatefulWidget {
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final DateTime? selectedDate;
  final Widget? header;
  final Widget? footer;
  final Function? onListBackCallback;

  const BaseStatisticsPage({
    Key? key,
    required this.records,
    this.from,
    this.to,
    this.selectedDate,
    this.header,
    this.footer,
    this.onListBackCallback,
  }) : super(key: key);
}

/// Base state class for statistics pages.
///
/// Manages common state:
/// - Aggregation method
/// - Selected date
/// - Group by type (Category/Tags/Records)
/// - Selected category/tag
/// - Top categories/tags
abstract class BaseStatisticsPageState<T extends BaseStatisticsPage>
    extends State<T> {
  AggregationMethod? aggregationMethod;
  DateTime? selectedDate;
  GroupByType groupByType = GroupByType.category;
  String? selectedCategory;
  List<String>? topCategories;

  @override
  void initState() {
    super.initState();
    aggregationMethod = getAggregationMethodGivenTheTimeRange(
      widget.from!,
      widget.to!,
    );
    selectedDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        selectedDate = widget.selectedDate;
      });
    }
  }

  /// Returns the list of records filtered by current selections.
  /// Used when displaying the records list.
  List<Record?> getFilteredRecordsForList() {
    var records = List<Record?>.from(widget.records);

    // Filter by selected date
    if (selectedDate != null) {
      records = RecordFilters.byDate(records, selectedDate, aggregationMethod);
    }

    // Filter by selected category/tag
    if (selectedCategory != null && topCategories != null) {
      if (groupByType == GroupByType.tag) {
        records = RecordFilters.byTag(records, selectedCategory, topCategories);
      } else {
        records =
            RecordFilters.byCategory(records, selectedCategory, topCategories);
      }
    }

    // Sort by date descending
    return records..sort((a, b) => b!.dateTime.compareTo(a!.dateTime));
  }

  /// Builds the chart widget. Must be implemented by subclasses.
  Widget buildChartWidget();

  /// Builds the summary card widget. Must be implemented by subclasses.
  Widget buildSummaryCard();

  /// Called when the chart selection changes. Must be implemented by subclasses.
  void onChartSelectionChanged(
      dynamic amount, String? category, List<String>? topCategories);

  /// Called when the group by type changes.
  void onGroupByTypeChanged(GroupByType newType) {
    setState(() {
      groupByType = newType;
      if (newType != GroupByType.records) {
        selectedCategory = null;
        topCategories = null;
      }
    });
  }

  /// Builds the no records page.
  Widget buildNoRecordPage() {
    return Column(
      children: <Widget>[
        Image.asset(
          'assets/images/no_entry_3.png',
          width: 200,
        ),
        Text(
          "No entries to show.".i18n,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.0,
          ),
        )
      ],
    );
  }

  /// Builds the content slivers for the CustomScrollView.
  List<Widget> buildContentSlivers() {
    final slivers = <Widget>[];

    if (widget.header != null) {
      slivers.add(widget.header!);
    }

    // Chart
    slivers.add(SliverToBoxAdapter(
      child: buildChartWidget(),
    ));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));

    // Summary Card
    if (groupByType != GroupByType.records) {
      slivers.add(SliverToBoxAdapter(
        child: buildSummaryCard(),
      ));
    }

    // Records List
    if (groupByType == GroupByType.records) {
      final recordsForList = getFilteredRecordsForList();

      if (recordsForList.isEmpty) {
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  "No entries found".i18n,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ));
      }

      slivers.add(RecordsDayList(
        recordsForList,
        isSliver: true,
        onListBackCallback: widget.onListBackCallback,
      ));
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 75)));
    }

    if (widget.footer != null) {
      slivers.add(SliverToBoxAdapter(child: widget.footer!));
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: buildNoRecordPage(),
      );
    }

    return CustomScrollView(
      slivers: buildContentSlivers(),
    );
  }
}
