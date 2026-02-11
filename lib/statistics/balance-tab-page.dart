import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/statistics-summary-card.dart';
import 'package:piggybank/records/components/records-day-list.dart';
import '../helpers/datetime-utility-functions.dart';
import 'unified-balance-card.dart';

class BalanceTabPage extends StatefulWidget {
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final Function(String?, DateTime?)? onIntervalSelected;
  final DateTime? selectedDate;
  final Widget? footer;
  final bool hideTagsSelection;
  final bool hideCategorySelection;
  final bool showRecordsToggle;
  final GroupByType? forceGroupByType;
  final Function? onListBackCallback;

  BalanceTabPage(this.from, this.to, this.records,
      {this.onIntervalSelected,
      this.selectedDate,
      this.footer,
      this.hideTagsSelection = false,
      this.hideCategorySelection = false,
      this.showRecordsToggle = false,
      this.forceGroupByType,
      this.onListBackCallback})
      : super();

  @override
  BalanceTabPageState createState() => BalanceTabPageState();
}

class BalanceTabPageState extends State<BalanceTabPage> {
  AggregationMethod? aggregationMethod;
  DateTime? selectedDate;
  late GroupByType groupByType;
  String? selectedCategory;
  List<String>? topCategories;

  @override
  void initState() {
    super.initState();
    this.aggregationMethod =
        getAggregationMethodGivenTheTimeRange(widget.from!, widget.to!);
    this.selectedDate = widget.selectedDate;
    this.groupByType = widget.forceGroupByType ?? GroupByType.category;
  }

  @override
  void didUpdateWidget(BalanceTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        selectedDate = widget.selectedDate;
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
    final List<Widget> slivers = [];

    slivers.add(SliverToBoxAdapter(
      child: UnifiedBalanceCard(
        widget.from,
        widget.to,
        widget.records,
        aggregationMethod,
        selectedDate: selectedDate,
        onSelectionChanged: (date) {
          setState(() {
            selectedDate = date;
            if (widget.onIntervalSelected != null) {
              if (date == null) {
                widget.onIntervalSelected!(null, null);
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
                widget.onIntervalSelected!(title, date);
              }
            }
          });
        },
      ),
    ));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));

    if (!(groupByType == GroupByType.records && !widget.showRecordsToggle)) {
      slivers.add(SliverToBoxAdapter(
        child: StatisticsSummaryCard(
          records: widget.records,
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
