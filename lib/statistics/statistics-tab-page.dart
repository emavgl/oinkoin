import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-summary-card.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/statistics/bar-chart-card.dart';
import 'package:piggybank/statistics/categories-pie-chart.dart';
import 'package:piggybank/statistics/tags-pie-chart.dart';
import 'package:piggybank/records/components/records-day-list.dart';

class StatisticsTabPage extends StatefulWidget {
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final Function(String?, DateTime?, double?)? onIntervalSelected;
  final DateTime? selectedDate;
  final Widget? footer;
  final GroupByType? forceGroupByType;
  final bool showRecordsToggle;
  final bool hideTagsSelection;
  final bool hideCategorySelection;
  final Function? onListBackCallback;

  StatisticsTabPage(this.from, this.to, this.records,
      {this.onIntervalSelected,
      this.selectedDate,
      this.footer,
      this.forceGroupByType,
      this.showRecordsToggle = false,
      this.hideTagsSelection = false,
      this.hideCategorySelection = false,
      this.onListBackCallback})
      : super();

  @override
  StatisticsTabPageState createState() => StatisticsTabPageState();
}

class StatisticsTabPageState extends State<StatisticsTabPage> {
  int? indexTab;
  AggregationMethod? aggregationMethod;
  double? selectedAmount;
  DateTime? selectedDate;
  String? selectedCategory;
  List<String>? topCategories;
  bool showPieChart = false;
  late GroupByType groupByType;

  @override
  void initState() {
    super.initState();
    indexTab = 0; // index identifying the tab
    this.aggregationMethod =
        getAggregationMethodGivenTheTimeRange(widget.from!, widget.to!);
    this.selectedDate = widget.selectedDate;
    this.groupByType = widget.forceGroupByType ?? GroupByType.category;
  }

  @override
  void didUpdateWidget(StatisticsTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        selectedDate = widget.selectedDate;
        if (selectedDate == null) {
          selectedAmount = null;
        }
      });
    }
  }

  List<Widget> _buildNoRecordSlivers() {
    return [
      SliverFillRemaining(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      )
    ];
  }

  List<Widget> _buildContentSlivers() {
    final List<Record?> recordsToVisualize =
        (widget.footer == null && groupByType == GroupByType.tag)
            ? widget.records.where((r) => r!.tags.isNotEmpty).toList()
            : widget.records;

    final List<Widget> slivers = [];

    Widget chartWidget = Container();
    if (showPieChart) {
      if (groupByType == GroupByType.tag) {
        chartWidget = TagsPieChart(
          recordsToVisualize,
          selectedTag: selectedCategory,
          onSelectionChanged: (amount, tag, topTags) {
            setState(() {
              selectedAmount = amount;
              selectedCategory = tag;
              topCategories = topTags;
            });
          },
        );
      } else {
        chartWidget = CategoriesPieChart(
          recordsToVisualize,
          selectedCategory: selectedCategory,
          onSelectionChanged: (amount, category, topCats) {
            setState(() {
              selectedAmount = amount;
              selectedCategory = category;
              topCategories = topCats;
            });
          },
        );
      }
    } else {
      chartWidget = BarChartCard(
        widget.from!,
        widget.to!,
        recordsToVisualize,
        aggregationMethod,
        selectedDate: selectedDate,
        onSelectionChanged: (double? amount, DateTime? date) {
          setState(() {
            selectedAmount = amount;
            selectedDate = date;

            if (widget.onIntervalSelected != null) {
              if (date == null) {
                widget.onIntervalSelected!(null, null, null);
              } else {
                String title;
                switch (aggregationMethod!) {
                  case AggregationMethod.DAY:
                    title = getDateStr(date);
                    break;
                  case AggregationMethod.WEEK:
                    title = getWeekStr(date);
                    break;
                  case AggregationMethod.MONTH:
                    title = getMonthStr(date);
                    break;
                  case AggregationMethod.YEAR:
                    title = getYearStr(date);
                    break;
                  default:
                    title = getDateRangeStr(widget.from!, widget.to!);
                }
                widget.onIntervalSelected!(title, date, amount);
              }
            }
          });
        },
      );
    }

    final OverviewCard ov = OverviewCard(
      widget.from,
      widget.to,
      recordsToVisualize,
      aggregationMethod,
      selectedAmount: selectedAmount,
      actions: <OverviewCardAction>[
        OverviewCardAction(
          icon: showPieChart ? Icons.bar_chart : Icons.pie_chart,
          onTap: () {
            setState(() {
              showPieChart = !showPieChart;
              selectedAmount = null;
              selectedDate = null;
              selectedCategory = null;
              topCategories = null;
              if (widget.onIntervalSelected != null) {
                widget.onIntervalSelected!(null, null, null);
              }
            });
          },
          tooltip: showPieChart
              ? "Switch to bar chart".i18n
              : "Switch to pie chart".i18n,
        ),
      ],
    );

    slivers.add(SliverToBoxAdapter(child: ov));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));
    slivers.add(SliverToBoxAdapter(child: chartWidget));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));

    // Summary Section
    if (!(groupByType == GroupByType.records && !widget.showRecordsToggle)) {
      slivers.add(SliverToBoxAdapter(
        child: StatisticsSummaryCard(
          records: recordsToVisualize,
          aggregationMethod: aggregationMethod,
          from: widget.from,
          to: widget.to,
          selectedDate: selectedDate,
          selectedCategoryOrTag: selectedCategory,
          topCategories: topCategories,
          groupByType: groupByType,
          showHeaders: true,
          showRecordsToggle: widget.showRecordsToggle,
          hideTagsSelection: widget.hideTagsSelection,
          hideCategorySelection: widget.hideCategorySelection,
          onGroupByTypeChanged: (newType) {
            setState(() {
              groupByType = newType;
              // Don't clear selectedCategory/topCategories when switching to Records
              // We need them to filter the records list
              if (newType != GroupByType.records) {
                selectedCategory = null;
                topCategories = null;
                selectedAmount = null;
                if (widget.onIntervalSelected != null) {
                  widget.onIntervalSelected!(null, null, null);
                }
              }
            });
          },
        ),
      ));
    }

    if (groupByType == GroupByType.records) {
      if (widget.footer != null) {
        slivers.add(SliverToBoxAdapter(child: widget.footer!));
      } else {
        List<Record?> recordsForList = widget.records;

        // Filter by selected date if any
        if (selectedDate != null) {
          recordsForList = recordsForList.where((r) {
            return truncateDateTime(r!.dateTime, aggregationMethod) ==
                selectedDate;
          }).toList();
        }

        // Filter by selected category/tag if any
        if (selectedCategory != null && topCategories != null) {
          if (selectedCategory == "Others".i18n) {
            // Show records for items not in topCategories
            recordsForList = recordsForList.where((r) {
              if (groupByType == GroupByType.tag) {
                return r?.tags.any((tag) => !topCategories!.contains(tag)) ??
                    false;
              }
              return !topCategories!.contains(r?.category?.name);
            }).toList();
          } else {
            // Show records for the selected category or tag
            recordsForList = recordsForList.where((r) {
              if (groupByType == GroupByType.tag) {
                return r?.tags.contains(selectedCategory) ?? false;
              }
              return r?.category?.name == selectedCategory;
            }).toList();
          }
        }

        recordsForList = List.from(recordsForList)
          ..sort((a, b) => b!.dateTime.compareTo(a!.dateTime));

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
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: widget.records.length > 0
          ? _buildContentSlivers()
          : _buildNoRecordSlivers(),
    );
  }
}
