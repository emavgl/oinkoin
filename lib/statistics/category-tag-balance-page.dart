import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/balance-tab-page.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

class CategoryTagBalancePage extends StatefulWidget {
  final String title;
  final List<Record?> records;
  final DateTime from;
  final DateTime to;
  final AggregationMethod? aggregationMethod;
  final Category? category;
  final DateTime? selectedDate;

  CategoryTagBalancePage({
    required this.title,
    required this.records,
    required this.from,
    required this.to,
    required this.aggregationMethod,
    this.category,
    this.selectedDate,
  });

  @override
  _CategoryTagBalancePageState createState() => _CategoryTagBalancePageState();
}

class _CategoryTagBalancePageState extends State<CategoryTagBalancePage> {
  late List<Record?> _currentRecords;
  String? _selectedIntervalTitle;
  DateTime? _selectedIntervalDate;

  @override
  void initState() {
    super.initState();
    _currentRecords = List.from(widget.records);
    _selectedIntervalDate = widget.selectedDate;

    if (_selectedIntervalDate != null) {
      AggregationMethod currentViewAggregation = getAggregationMethodGivenTheTimeRange(widget.from, widget.to);
      _currentRecords = widget.records.where((r) {
        return truncateDateTime(r!.dateTime, currentViewAggregation) == _selectedIntervalDate;
      }).toList();
    }

    _currentRecords.sort((a, b) => b!.dateTime.compareTo(a!.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedIntervalTitle ?? widget.title;
    AggregationMethod currentViewAggregation = getAggregationMethodGivenTheTimeRange(widget.from, widget.to);

    final bool hasTags = widget.records.any((r) => r != null && r.tags.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: BalanceTabPage(
        widget.from,
        widget.to,
        widget.records,
        selectedDate: _selectedIntervalDate,
        showRecordsToggle: true,
        forceGroupByType: GroupByType.records,
        hideCategorySelection: widget.category != null,
        hideTagsSelection: widget.category == null,
        onListBackCallback: () {
          setState(() {
          });
        },
        onIntervalSelected: (newTitle, date) {
          setState(() {
            _selectedIntervalTitle = newTitle != null ? "${widget.title} - $newTitle" : null;
            _selectedIntervalDate = date;
          });
        },
      ),
    );
  }
}
