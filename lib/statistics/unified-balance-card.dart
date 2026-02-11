import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/balance-chart-models.dart';
import 'package:piggybank/statistics/balance-comparison-chart.dart';
import 'package:piggybank/statistics/record-filters.dart';
import '../i18n.dart';

/// A card displaying balance overview with an interactive comparison chart.
///
/// Features:
/// - Toggle between net savings view and separate income/expense bars
/// - Optional cumulative savings line overlay
/// - Interactive period selection
/// - Overview card integration showing totals for selected period
class UnifiedBalanceCard extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;
  final Function(DateTime?)? onSelectionChanged;
  final DateTime? selectedDate;

  const UnifiedBalanceCard(
    this.from,
    this.to,
    this.records,
    this.aggregationMethod, {
    this.onSelectionChanged,
    this.selectedDate,
  }) : super();

  @override
  _UnifiedBalanceCardState createState() => _UnifiedBalanceCardState();
}

class _UnifiedBalanceCardState extends State<UnifiedBalanceCard> {
  late Map<String, ComparisonData> comparisonData;
  late ChartDateRangeConfig dateConfig;
  late BalanceChartTickGenerator tickGenerator;

  String? _selectedPeriodKey;
  bool _animate = true;
  bool _showNetView = true;
  bool _showCumulativeLine = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(UnifiedBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_shouldReinitializeData(oldWidget)) {
      _animate = true;
      _initializeData();
    }

    if (widget.selectedDate != oldWidget.selectedDate) {
      _animate = false;
      _updateSelectionFromDate();
    }
  }

  bool _shouldReinitializeData(UnifiedBalanceCard oldWidget) {
    return widget.records != oldWidget.records ||
        widget.aggregationMethod != oldWidget.aggregationMethod ||
        widget.from != oldWidget.from ||
        widget.to != oldWidget.to;
  }

  void _initializeData() {
    dateConfig = ChartDateRangeConfig.create(
      widget.aggregationMethod!,
      widget.from,
      widget.to,
    );

    final aggregator = ComparisonDataAggregator(widget.aggregationMethod!);
    comparisonData = aggregator.aggregate(widget.records, dateConfig);
    tickGenerator = BalanceChartTickGenerator(widget.aggregationMethod!);

    _updateSelectionFromDate();
  }

  void _updateSelectionFromDate() {
    if (widget.selectedDate == null) {
      _selectedPeriodKey = null;
    } else {
      _selectedPeriodKey = dateConfig.getKey(widget.selectedDate!);
      if (!comparisonData.containsKey(_selectedPeriodKey)) {
        _selectedPeriodKey = null;
      }
    }
  }

  void _onSelectionChanged(charts.SelectionModel<dynamic> model) {
    setState(() {
      _animate = false;

      if (!model.hasDatumSelection) {
        _clearSelection();
        return;
      }

      // Filter out the cumulative line series from selection
      final barDatums = model.selectedDatum
          .where((d) => d.series.id != 'CumulativeBalance')
          .toList();

      if (barDatums.isEmpty) return;

      final selectedDatum = barDatums.first;
      final data = selectedDatum.datum as ComparisonData;

      if (_selectedPeriodKey == data.period) {
        // Toggle off if already selected
        _clearSelection();
      } else {
        _selectedPeriodKey = data.period;
        widget.onSelectionChanged?.call(data.dateTime);
      }
    });
  }

  void _clearSelection() {
    _selectedPeriodKey = null;
    widget.onSelectionChanged?.call(null);
  }

  void _toggleViewMode() {
    setState(() {
      _showNetView = !_showNetView;
      _initializeData();
    });
  }

  void _toggleCumulativeLine() {
    setState(() {
      _showCumulativeLine = !_showCumulativeLine;
    });
  }

  /// Filters records based on the currently selected period.
  List<Record?> _getFilteredRecords() {
    if (_selectedPeriodKey == null) {
      return widget.records;
    }

    final selectedDate = comparisonData[_selectedPeriodKey!]!.dateTime;
    return RecordFilters.byDate(
      widget.records,
      selectedDate,
      widget.aggregationMethod,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OverviewCard(
          widget.from,
          widget.to,
          _getFilteredRecords(),
          widget.aggregationMethod,
          isBalance: true,
          actions: [
            OverviewCardAction(
              icon: _showNetView
                  ? Icons.compare_arrows
                  : Icons.account_balance_wallet,
              onTap: _toggleViewMode,
              tooltip: _showNetView
                  ? "Switch to separate income and expense bars".i18n
                  : "Switch to net savings view".i18n,
            ),
            OverviewCardAction(
              icon: _showCumulativeLine
                  ? Icons.horizontal_rule
                  : Icons.show_chart,
              onTap: _toggleCumulativeLine,
              tooltip: _showCumulativeLine
                  ? "Hide cumulative balance line".i18n
                  : "Show cumulative balance line".i18n,
            ),
          ],
        ),
        const Divider(height: 1, indent: 24, endIndent: 24),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 300,
          child: BalanceComparisonChart(
            data: comparisonData,
            showNetView: _showNetView,
            showCumulativeLine: _showCumulativeLine,
            selectedPeriodKey: _selectedPeriodKey,
            animate: _animate,
            onSelectionChanged: _onSelectionChanged,
          ),
        ),
      ],
    );
  }
}
