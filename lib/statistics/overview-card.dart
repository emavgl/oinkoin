import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/statistics-calculator.dart';
import '../helpers/records-utility-functions.dart';
import '../helpers/currency_breakdown_sheet.dart';
import 'package:piggybank/i18n.dart';

class OverviewCardAction {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  OverviewCardAction({
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
  });
}

class OverviewCard extends StatelessWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;
  final List<DateTimeSeriesRecord> aggregatedRecords;
  final double? selectedAmount;
  final DateTime? selectedDate;
  final bool isBalance;
  final List<OverviewCardAction> actions;
  final Map<int, String?> walletCurrencyMap;
  final RecordsTotalResult _convertedResult;

  OverviewCard(this.from, this.to, this.records, this.aggregationMethod,
      {this.selectedAmount,
      this.selectedDate,
      this.isBalance = false,
      this.actions = const [],
      this.walletCurrencyMap = const {}})
      : aggregatedRecords = aggregateRecordsByDate(records, aggregationMethod),
        _convertedResult = computeConvertedTotal(records, walletCurrencyMap,
            isAbsValue: !isBalance);

  double get averageValue {
    switch (aggregationMethod) {
      case AggregationMethod.WEEK:
        // For WEEK: show daily average instead of weekly bin average
        return StatisticsCalculator.calculateDailyAverage(records, from, to,
            isBalance: isBalance);

      default:
        // DAY, MONTH, and YEAR: keep existing period-based calculation
        return StatisticsCalculator.calculateAverage(
            records, aggregationMethod, from, to,
            isBalance: isBalance);
    }
  }

  double get medianValue {
    switch (aggregationMethod) {
      case AggregationMethod.WEEK:
        // For WEEK: show daily median for consistency with daily average
        return StatisticsCalculator.calculateDailyMedian(records, from, to,
            isBalance: isBalance);

      default:
        // DAY, MONTH, and YEAR: keep existing period-based calculation
        return StatisticsCalculator.calculateMedian(
            records, aggregationMethod, from, to,
            isBalance: isBalance);
    }
  }

  String _formatAmount(double value, String? currency) {
    if (currency == null || currency.isEmpty) {
      return getCurrencyValueString(value);
    }
    return formatAmountWithCurrency(value, currency);
  }

  /// Returns the records that belong to the selected bar (filtered by [selectedDate]).
  List<Record?> _getSelectedRecords() {
    if (selectedDate == null) return [];
    return records.where((r) {
      if (r == null) return false;
      final recordDate = truncateDateTime(r.localDateTime, aggregationMethod);
      return recordDate == selectedDate;
    }).toList();
  }

  Widget _buildMainAmountWidget(BuildContext context) {
    final defaultCurrency = getDefaultCurrency();
    final mainStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        );
    final secondaryStyle = TextStyle(
      fontSize: ((mainStyle?.fontSize ?? 24.0) * 0.65).clamp(12.0, double.infinity),
      color: Colors.grey,
    );

    String? convertedAmountText;
    String? originalAmountText;

    if (selectedAmount != null) {
      // Selected bar
      final breakdown = selectedDate != null
          ? buildCurrencyBreakdown(_getSelectedRecords(), walletCurrencyMap,
              isAbsValue: !isBalance)
          : <String, double>{};
      final nonEmpty =
          breakdown.entries.where((e) => e.key.isNotEmpty).toList();
      final selOriginalCurrency =
          nonEmpty.length == 1 ? nonEmpty.first.key : null;

      if (defaultCurrency != null &&
          defaultCurrency.isNotEmpty &&
          selOriginalCurrency != null &&
          selOriginalCurrency != defaultCurrency) {
        final converted = convertAmount(
            selectedAmount!, selOriginalCurrency, defaultCurrency);
        if (converted != null) {
          convertedAmountText =
              formatCurrencyAmount(converted, defaultCurrency);
          originalAmountText =
              formatCurrencyAmount(selectedAmount!, selOriginalCurrency);
        } else {
          convertedAmountText =
              formatCurrencyAmount(selectedAmount!, selOriginalCurrency);
        }
      } else if (selOriginalCurrency != null &&
          selOriginalCurrency.isNotEmpty) {
        convertedAmountText =
            formatCurrencyAmount(selectedAmount!, selOriginalCurrency);
      } else if (_convertedResult.currency != null &&
          _convertedResult.currency!.isNotEmpty) {
        convertedAmountText =
            formatCurrencyAmount(selectedAmount!, _convertedResult.currency!);
      } else {
        convertedAmountText = getCurrencyValueString(selectedAmount);
      }
    } else {
      // Overall total
      final breakdown = buildCurrencyBreakdown(records, walletCurrencyMap,
          isAbsValue: !isBalance);
      final nonEmpty =
          breakdown.entries.where((e) => e.key.isNotEmpty).toList();
      if (nonEmpty.length == 1 &&
          defaultCurrency != null &&
          defaultCurrency.isNotEmpty &&
          nonEmpty.first.key != defaultCurrency) {
        convertedAmountText =
            formatCurrencyAmount(_convertedResult.total, defaultCurrency);
        originalAmountText =
            formatCurrencyAmount(nonEmpty.first.value, nonEmpty.first.key);
      } else if (_convertedResult.currency != null &&
          _convertedResult.currency!.isNotEmpty) {
        convertedAmountText = formatCurrencyAmount(
            _convertedResult.total, _convertedResult.currency!);
      } else {
        convertedAmountText = formatRecordsTotalResult(_convertedResult);
      }
    }

    Widget amountWidget;
    if (originalAmountText != null) {
      amountWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(convertedAmountText, style: mainStyle),
          Text(originalAmountText, style: secondaryStyle),
        ],
      );
    } else {
      amountWidget = Text(convertedAmountText, style: mainStyle);
    }

    if (selectedAmount != null ||
        !hasMixedCurrencies(records, walletCurrencyMap)) return amountWidget;

    return GestureDetector(
      onTap: () => showCurrencyBreakdownSheet(
          context, records, walletCurrencyMap,
          isAbsValue: !isBalance),
      child: amountWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return SizedBox.shrink();

    // Cache computed values — getters iterate over all records each call
    final average = averageValue;
    final median = medianValue;

    final breakdown = buildCurrencyBreakdown(records, walletCurrencyMap,
        isAbsValue: !isBalance);
    final nonEmptyCurrencies =
        breakdown.entries.where((e) => e.key.isNotEmpty).toList();
    final originalCurrency =
        nonEmptyCurrencies.length == 1 ? nonEmptyCurrencies.first.key : null;

    String averageLabelKey;
    String medianLabelKey;
    switch (aggregationMethod) {
      // WEEK intentionally uses daily labels for intuitive comparison
      case AggregationMethod.WEEK:
      case AggregationMethod.DAY:
        averageLabelKey = "Average of %s a day".i18n;
        medianLabelKey = "Median of %s a day".i18n;
        break;
      case AggregationMethod.MONTH:
        averageLabelKey = "Average of %s a month".i18n;
        medianLabelKey = "Median of %s a month".i18n;
        break;
      case AggregationMethod.YEAR:
        averageLabelKey = "Average of %s a year".i18n;
        medianLabelKey = "Median of %s a year".i18n;
        break;
      default:
        averageLabelKey = "Average of %s".i18n;
        medianLabelKey = "Median of %s".i18n;
    }

    final color = isBalance
        ? (_convertedResult.total >= 0 ? Colors.green : Colors.redAccent)
        : (records.first!.category!.categoryType == CategoryType.expense
            ? Colors.redAccent
            : Colors.green);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainAmountWidget(context),
                const SizedBox(height: 2),
                Text(
                  averageLabelKey
                      .fill([_formatAmount(average, originalCurrency)]),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withAlpha(179),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  medianLabelKey
                      .fill([_formatAmount(median, originalCurrency)]),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withAlpha(179),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (actions.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Tooltip(
                    message: actions[i].tooltip ?? '',
                    child: InkWell(
                      onTap: actions[i].onTap,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (actions[i].color ?? color).withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                                scale: animation, child: child);
                          },
                          child: Icon(
                            actions[i].icon,
                            key: ValueKey<int>(i),
                            color: actions[i].color ?? color,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
