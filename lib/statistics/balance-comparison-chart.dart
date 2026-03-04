import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'balance-chart-models.dart';

/// A reusable balance comparison chart widget.
///
/// Displays income vs expenses or net savings as bars, with an optional
/// cumulative savings line overlay.
class BalanceComparisonChart extends StatelessWidget {
  final Map<String, ComparisonData> data;
  final bool showNetView;
  final bool showCumulativeLine;
  final String? selectedPeriodKey;
  final bool animate;
  final void Function(charts.SelectionModel<dynamic>)? onSelectionChanged;

  const BalanceComparisonChart({
    Key? key,
    required this.data,
    required this.showNetView,
    required this.showCumulativeLine,
    this.selectedPeriodKey,
    this.animate = true,
    this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final labelAxesColor = isDarkMode ? charts.Color.white : charts.Color.black;
    final gridLineColor = charts.MaterialPalette.gray.shade400;

    final seriesFactory = BalanceChartSeriesFactory(
      showNetView: showNetView,
      selectedPeriodKey: selectedPeriodKey,
    );

    final seriesList = seriesFactory.createSeries(data, showCumulativeLine);
    final hasNegativeValues =
        data.values.any((d) => d.netSavings < 0 || d.cumulativeSavings < 0);

    return Container(
      padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
      child: charts.OrdinalComboChart(
        seriesList,
        animate: animate,
        behaviors: _createBehaviors(hasNegativeValues, labelAxesColor),
        defaultRenderer: charts.BarRendererConfig(
          groupingType: charts.BarGroupingType.grouped,
          strokeWidthPx: 2,
        ),
        customSeriesRenderers: [
          charts.LineRendererConfig(
            customRendererId: 'customLine',
            includePoints: false,
            includeArea: true,
            areaOpacity: 0.1,
          ),
        ],
        selectionModels: [
          charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: onSelectionChanged,
          ),
        ],
        domainAxis: charts.OrdinalAxisSpec(
          renderSpec: charts.SmallTickRendererSpec(
            labelStyle:
                charts.TextStyleSpec(fontSize: 14, color: labelAxesColor),
            lineStyle: charts.LineStyleSpec(color: labelAxesColor),
          ),
        ),
        primaryMeasureAxis: charts.NumericAxisSpec(
          renderSpec: charts.GridlineRendererSpec(
            labelStyle:
                charts.TextStyleSpec(fontSize: 14, color: labelAxesColor),
            lineStyle: charts.LineStyleSpec(color: gridLineColor, thickness: 1),
          ),
        ),
      ),
    );
  }

  List<charts.ChartBehavior<String>> _createBehaviors(
    bool hasNegativeValues,
    charts.Color labelAxesColor,
  ) {
    final behaviors = <charts.ChartBehavior<String>>[];

    if (hasNegativeValues) {
      behaviors.add(
        charts.RangeAnnotation<String>([
          charts.LineAnnotationSegment(
            0,
            charts.RangeAnnotationAxisType.measure,
            color: labelAxesColor,
            strokeWidthPx: 1,
          ),
        ], layoutPaintOrder: 100),
      );
    }

    return behaviors;
  }
}
