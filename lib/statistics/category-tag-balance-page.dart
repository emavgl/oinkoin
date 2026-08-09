import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/statistics/balance-tab-page.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

class CategoryTagBalancePage extends StatefulWidget {
  final String title;
  final List<Record?> records;
  final DateTime from;
  final DateTime to;
  final AggregationMethod? aggregationMethod;
  final Category? category;
  final String? walletName;
  final DateTime? selectedDate;
  final Map<int, String?> walletCurrencyMap;

  CategoryTagBalancePage({
    required this.title,
    required this.records,
    required this.from,
    required this.to,
    required this.aggregationMethod,
    this.category,
    this.walletName,
    this.selectedDate,
    this.walletCurrencyMap = const {},
  });

  @override
  _CategoryTagBalancePageState createState() => _CategoryTagBalancePageState();
}

class _CategoryTagBalancePageState extends State<CategoryTagBalancePage> {
  late List<Record?> _currentRecords;
  String? _selectedIntervalTitle;
  DateTime? _selectedIntervalDate;
  Map<int, String?> _effectiveCurrencyMap = {};
  Map<int, Wallet> _effectiveWalletMap = {};

  @override
  void initState() {
    super.initState();
    _currentRecords = List.from(widget.records);
    _selectedIntervalDate = widget.selectedDate;

    if (_selectedIntervalDate != null) {
      AggregationMethod currentViewAggregation =
          getAggregationMethodGivenTheTimeRange(widget.from, widget.to);
      _currentRecords = widget.records.where((r) {
        return truncateDateTime(r!.dateTime, currentViewAggregation) ==
            _selectedIntervalDate;
      }).toList();
    }

    _currentRecords.sort((a, b) => b!.dateTime.compareTo(a!.dateTime));

    if (widget.walletCurrencyMap.isEmpty) {
      _loadWalletData();
    } else {
      _effectiveCurrencyMap = widget.walletCurrencyMap;
    }
  }

  Future<void> _loadWalletData() async {
    final db = ServiceConfig.database;
    final wallets = await db.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    if (!mounted) return;
    setState(() {
      _effectiveCurrencyMap = buildWalletCurrencyMap(wallets);
      _effectiveWalletMap = {
        for (final w in wallets)
          if (w.id != null) w.id!: w
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedIntervalTitle ?? widget.title;

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
        hideTagsSelection: widget.category == null && widget.walletName == null,
        hideWalletsSelection: widget.walletName != null,
        walletCurrencyMap: _effectiveCurrencyMap,
        walletMap: _effectiveWalletMap,
        onListBackCallback: () {
          setState(() {});
        },
        onIntervalSelected: (newTitle, date) {
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
