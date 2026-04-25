import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/statistics-tab-page.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

class CategoryTagRecordsPage extends StatefulWidget {
  final String title;
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final AggregationMethod? aggregationMethod;
  final Category? category; // null if it's a tag
  final Color? headerColor;
  final DateTime? selectedDate;
  final Map<int, String?> walletCurrencyMap;

  CategoryTagRecordsPage({
    required this.title,
    required this.records,
    required this.from,
    required this.to,
    required this.aggregationMethod,
    this.category,
    this.headerColor,
    this.selectedDate,
    this.walletCurrencyMap = const {},
  });

  @override
  _CategoryTagRecordsPageState createState() => _CategoryTagRecordsPageState();
}

class _CategoryTagRecordsPageState extends State<CategoryTagRecordsPage> {
  late List<Record?> _currentRecords;
  String? _selectedIntervalTitle;
  DateTime? _selectedIntervalDate;
  Map<int, String?> _effectiveCurrencyMap = {};

  @override
  void initState() {
    super.initState();
    _currentRecords = List.from(widget.records);
    _selectedIntervalDate = widget.selectedDate;
    _currentRecords.sort((a, b) => b!.dateTime.compareTo(a!.dateTime));

    if (widget.walletCurrencyMap.isEmpty) {
      _loadCurrencyMap();
    } else {
      _effectiveCurrencyMap = widget.walletCurrencyMap;
    }
  }

  Future<void> _loadCurrencyMap() async {
    final db = ServiceConfig.database;
    final wallets = await db.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    if (!mounted) return;
    setState(() {
      _effectiveCurrencyMap = buildWalletCurrencyMap(wallets);
    });
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
        walletCurrencyMap: _effectiveCurrencyMap,
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
