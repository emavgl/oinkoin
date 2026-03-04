import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-tab-page.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

class CategoryTagRecordsPage extends StatefulWidget {
  final String title;
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final AggregationMethod? aggregationMethod;
  final Category? category; // null if it's a tag
  final Color? headerColor;
  final DateTime? selectedDate;

  CategoryTagRecordsPage({
    required this.title,
    required this.records,
    required this.from,
    required this.to,
    required this.aggregationMethod,
    this.category,
    this.headerColor,
    this.selectedDate,
  });

  @override
  _CategoryTagRecordsPageState createState() => _CategoryTagRecordsPageState();
}

class _CategoryTagRecordsPageState extends State<CategoryTagRecordsPage> {
  late List<Record?> _currentRecords;
  String? _selectedIntervalTitle;
  DateTime? _selectedIntervalDate;

  @override
  void initState() {
    super.initState();
    _currentRecords = List.from(widget.records);
    _selectedIntervalDate = widget.selectedDate;

    _currentRecords.sort((a, b) => b!.dateTime.compareTo(a!.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedIntervalTitle ?? widget.title;
    // These may be used in future UI enhancements
    // ignore: unused_local_variable
    AggregationMethod currentViewAggregation =
        getAggregationMethodGivenTheTimeRange(widget.from!, widget.to!);
    // ignore: unused_local_variable
    bool hasTags =
        _currentRecords.any((r) => r?.tags != null && r!.tags.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: StatisticsTabPage(
        widget.from,
        widget.to,
        _currentRecords,
        selectedDate: _selectedIntervalDate,
        forceGroupByType: GroupByType.records,
        showRecordsToggle: true,
        hideCategorySelection: widget.category != null,
        hideTagsSelection: widget.category == null,
        onListBackCallback: () {
          setState(() {
            // No need to manually sort _currentRecords anymore if we rely on StatisticsTabPage
          });
        },
        onIntervalSelected: (newTitle, date, amount) {
          setState(() {
            _selectedIntervalTitle =
                newTitle != null ? "${widget.title} - $newTitle" : null;
            _selectedIntervalDate = date;
          });
        },
      ),
    );
  }
}
