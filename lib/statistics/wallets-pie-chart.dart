import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/i18n.dart';

import '../services/service-config.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';

class LinearWalletRecord {
  final int? walletId;
  final String? name;
  final double value;

  LinearWalletRecord(this.walletId, this.name, this.value);
}

class WalletsPieChart extends StatefulWidget {
  final List<Record?> records;
  final Map<int, Wallet> walletMap;
  final Function(double?, String?, List<String>?)? onSelectionChanged;
  final String? selectedWalletId;

  WalletsPieChart(this.records,
      {this.walletMap = const {},
      this.onSelectionChanged,
      this.selectedWalletId});

  @override
  _WalletsPieChartState createState() => _WalletsPieChartState();
}

class _WalletsPieChartState extends State<WalletsPieChart> {
  late List<LinearWalletRecord> _preparedData;
  late List<charts.Color> _preparedColors;
  late List<charts.Series<LinearWalletRecord, String>> seriesList;
  late List<charts.Color> colorPalette;
  late List<LinearWalletRecord> linearRecords;
  String? _selectedWalletId;

  bool _animate = true;
  final Color otherWalletColor = Colors.blueGrey;
  late int walletCount;
  late List<charts.Color> defaultColorsPalette;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.selectedWalletId;
    _initializeData();
  }

  @override
  void didUpdateWidget(WalletsPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records ||
        widget.walletMap != oldWidget.walletMap) {
      _animate = true;
      _initializeData();
    } else if (widget.selectedWalletId != oldWidget.selectedWalletId) {
      _animate = false;
      _selectedWalletId = widget.selectedWalletId;
      _updateSeriesList();
    }
  }

  void _initializeData() {
    walletCount = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;
    defaultColorsPalette =
        charts.MaterialPalette.getOrderedPalettes(walletCount)
            .map((palette) => palette.shadeDefault)
            .toList();
    defaultColorsPalette.add(charts.ColorUtil.fromDartColor(otherWalletColor));

    WalletChartData chartData = _prepareData(widget.records);
    _preparedData = chartData.data;
    _preparedColors = chartData.colors;
    _updateSeriesList();
  }

  void _updateSeriesList() {
    seriesList = [
      charts.Series<LinearWalletRecord, String>(
        id: 'Wallets'.i18n,
        colorFn: (LinearWalletRecord datum, i) {
          final color = _preparedColors[i!];
          if (_selectedWalletId == null ||
              _selectedWalletId == datum.walletId?.toString()) {
            return color;
          }
          return color.lighter.lighter;
        },
        domainFn: (LinearWalletRecord recordsUnderWallet, _) =>
            recordsUnderWallet.walletId?.toString() ?? "Others".i18n,
        measureFn: (LinearWalletRecord recordsUnderWallet, _) =>
            recordsUnderWallet.value,
        data: _preparedData,
      ),
    ];
    colorPalette = _preparedColors;
    linearRecords = _preparedData;
  }

  WalletChartData _prepareData(List<Record?> records) {
    Map<int, double> aggregatedWalletsValuesTemporaryMap = {};

    // Sum each wallet's raw (signed) values so refunds reduce the net.
    for (var record in records) {
      if (record != null && record.walletId != null) {
        aggregatedWalletsValuesTemporaryMap.update(
          record.walletId!,
          (value) => value + record.value!,
          ifAbsent: () => record.value!,
        );
      }
    }

    // Slices are magnitudes: abs of each wallet's net total.
    for (final key in aggregatedWalletsValuesTemporaryMap.keys.toList()) {
      aggregatedWalletsValuesTemporaryMap[key] =
          aggregatedWalletsValuesTemporaryMap[key]!.abs();
    }
    double totalSum =
        aggregatedWalletsValuesTemporaryMap.values.fold(0.0, (a, b) => a + b);

    var aggregatedWalletsAndValues =
        aggregatedWalletsValuesTemporaryMap.entries.toList();
    aggregatedWalletsAndValues.sort((b, a) => a.value.compareTo(b.value));

    var limit = aggregatedWalletsAndValues.length > walletCount + 1
        ? walletCount
        : aggregatedWalletsAndValues.length;

    var topWalletsAndValue = aggregatedWalletsAndValues.sublist(0, limit);

    List<LinearWalletRecord> data = [];
    List<charts.Color> colorsToUse = [];

    for (int i = 0; i < topWalletsAndValue.length; i++) {
      var walletAndValue = topWalletsAndValue[i];
      var percentage = (100 * walletAndValue.value) / totalSum;
      final wallet = widget.walletMap[walletAndValue.key];
      final name = wallet?.name ?? "Unknown wallet".i18n;
      var lr = LinearWalletRecord(walletAndValue.key, name, percentage);
      data.add(lr);
      if (wallet?.color != null) {
        colorsToUse.add(charts.ColorUtil.fromDartColor(wallet!.color!));
      } else {
        colorsToUse.add(defaultColorsPalette[i]);
      }
    }

    if (limit < aggregatedWalletsAndValues.length) {
      var remainingWalletsAndValue = aggregatedWalletsAndValues.sublist(limit);
      var sumOfRemainingWallets = remainingWalletsAndValue.fold(
        0.0,
        (dynamic value, element) => value + element.value,
      );
      var remainingWalletKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingWallets) / totalSum;
      var lr = LinearWalletRecord(null, remainingWalletKey, percentage);
      data.add(lr);
      colorsToUse.add(charts.ColorUtil.fromDartColor(otherWalletColor));
    }

    return WalletChartData(data, colorsToUse);
  }

  void _selectWallet(String? walletId) {
    setState(() {
      _animate = false;
      if (_selectedWalletId == walletId) {
        _selectedWalletId = null;
        if (widget.onSelectionChanged != null)
          widget.onSelectionChanged!(null, null, null);
      } else {
        _selectedWalletId = walletId;
        if (widget.onSelectionChanged != null) {
          double walletSum = 0;
          for (var r in widget.records) {
            if (r == null) continue;
            if (walletId == "Others".i18n) {
              if (r.walletId != null && !_isTopWallet(r.walletId!)) {
                walletSum += r.value!;
              }
            } else if (r.walletId?.toString() == walletId) {
              walletSum += r.value!;
            }
          }
          walletSum = walletSum.abs();

          final List<String> topWalletIds = linearRecords
              .where((lr) => lr.walletId != null)
              .map((lr) => lr.walletId.toString())
              .toList();

          widget.onSelectionChanged!(walletSum, walletId, topWalletIds);
        }
      }
      _updateSeriesList();
    });
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    if (!model.hasDatumSelection) {
      _selectWallet(null);
    } else {
      final selectedDatum = model.selectedDatum.first;
      final data = selectedDatum.datum as LinearWalletRecord;
      _selectWallet(data.walletId?.toString() ?? "Others".i18n);
    }
  }

  bool _isTopWallet(int walletId) {
    return linearRecords.any((lr) =>
        lr.walletId == walletId && lr.walletId?.toString() != "Others".i18n);
  }

  Widget _buildPieChart(BuildContext context) {
    return charts.PieChart<String>(
      seriesList,
      animate: _animate,
      defaultRenderer: charts.ArcRendererConfig(arcWidth: 35),
      selectionModels: [
        charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          changedListener: _onSelectionChanged,
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: linearRecords.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: (context, i) {
          var linearRecord = linearRecords[i];
          var recordColor = colorPalette[i];
          bool isSelected =
              _selectedWalletId == linearRecord.walletId?.toString();

          return InkWell(
            onTap: () => _selectWallet(
                linearRecord.walletId?.toString() ?? "Others".i18n),
            borderRadius: BorderRadius.circular(4),
            child: Container(
                margin: EdgeInsets.fromLTRB(0, 0, 8, 8),
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.grey.withAlpha(40)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Container(
                          margin: EdgeInsets.fromLTRB(0, 0, 4, 0),
                          child: Row(
                            children: <Widget>[
                              Container(
                                height: 10,
                                width: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromARGB(
                                      recordColor.a,
                                      recordColor.r,
                                      recordColor.g,
                                      recordColor.b),
                                ),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(linearRecord.name!,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              )
                            ],
                          )),
                    ),
                    Text(linearRecord.value.toStringAsFixed(2) + " %",
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                )),
          );
        });
  }

  Widget _buildCard(BuildContext context) {
    double baseHeight = 200;
    double extraHeightPerItem =
        linearRecords.length > 5 ? (linearRecords.length - 5) * 28.0 : 0;
    double cardHeight = baseHeight + extraHeightPerItem;

    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: cardHeight,
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(
                height: 200,
                child: _buildPieChart(context),
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildLegend(),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }
}

class WalletChartData {
  final List<LinearWalletRecord> data;
  final List<charts.Color> colors;

  WalletChartData(this.data, this.colors);
}
