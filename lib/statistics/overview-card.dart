import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import '../helpers/records-utility-functions.dart';
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
  final double sumValues;
  final double averageValue;
  final double? selectedAmount;
  final bool isBalance;
  final List<OverviewCardAction> actions;

  OverviewCard(this.from, this.to, this.records, this.aggregationMethod,
      {this.selectedAmount, this.isBalance = false, this.actions = const []})
      : aggregatedRecords = aggregateRecordsByDate(records, aggregationMethod),
        sumValues = isBalance
            ? records.fold(0.0, (acc, e) {
                double val = e!.value!.abs();
                return (acc as double) +
                    (e.category!.categoryType == CategoryType.income
                        ? val
                        : -val);
              })
            : records
                .fold(0.0, (acc, e) => (acc as double) + e!.value!.abs())
                .abs(),
        averageValue = (isBalance
                ? records.fold(0.0, (acc, e) {
                    double val = e!.value!.abs();
                    return (acc as double) +
                        (e.category!.categoryType == CategoryType.income
                            ? val
                            : -val);
                  })
                : records
                    .fold(0.0, (acc, e) => (acc as double) + e!.value!.abs())
                    .abs()) /
            (aggregationMethod != null &&
                    aggregationMethod != AggregationMethod.NOT_AGGREGATED
                ? (computeNumberOfIntervals(from!, to!, aggregationMethod) == 0
                    ? 1
                    : computeNumberOfIntervals(from, to, aggregationMethod))
                : (records.isEmpty ? 1 : records.length));

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return SizedBox.shrink();

    String prelude;
    if (isBalance) {
      prelude = sumValues >= 0 ? "You saved".i18n : "You overspent".i18n;
    } else {
      final categoryType = records.first!.category!.categoryType;
      prelude = categoryType == CategoryType.expense
          ? "You spent".i18n
          : "Your income is".i18n;
    }

    String averageLabelKey;
    switch (aggregationMethod) {
      case AggregationMethod.DAY:
        averageLabelKey = "Average of %s a day".i18n;
        break;
      case AggregationMethod.WEEK:
        averageLabelKey = "Average of %s a week".i18n;
        break;
      case AggregationMethod.MONTH:
        averageLabelKey = "Average of %s a month".i18n;
        break;
      case AggregationMethod.YEAR:
        averageLabelKey = "Average of %s a year".i18n;
        break;
      default:
        averageLabelKey = "Average of %s".i18n;
    }

    final color = isBalance
        ? (sumValues >= 0 ? Colors.green : Colors.redAccent)
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
                Text(
                  prelude,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  getCurrencyValueString(selectedAmount ?? sumValues),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  averageLabelKey.fill([getCurrencyValueString(averageValue)]),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(179),
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
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return ScaleTransition(scale: animation, child: child);
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
