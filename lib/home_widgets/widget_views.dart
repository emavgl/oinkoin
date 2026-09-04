import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';

/// Compact widgets rendered to bitmaps for the Android home screen widgets.
/// They mirror the app's summary styling but take preformatted values, so
/// rendering needs no database access.

/// Income / Expenses / Balance overview card, mirroring DaysSummaryBox.
class HomeWidgetOverview extends StatelessWidget {
  final String incomeText;
  final String expensesText;
  final String balanceText;
  final Color incomeColor;
  final Color expenseColor;
  final Color balanceColor;

  const HomeWidgetOverview({
    super.key,
    required this.incomeText,
    required this.incomeColor,
    required this.expensesText,
    required this.expenseColor,
    required this.balanceText,
    required this.balanceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _HomeWidgetStatColumn(
              label: "Income".i18n,
              amount: incomeText,
              color: incomeColor,
            ),
          ),
          Expanded(
            child: _HomeWidgetStatColumn(
              label: "Expenses".i18n,
              amount: expensesText,
              color: expenseColor,
            ),
          ),
          Expanded(
            child: _HomeWidgetStatColumn(
              label: "Balance".i18n,
              amount: balanceText,
              color: balanceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWidgetStatColumn extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _HomeWidgetStatColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Single labeled amount (Income, Expenses, or Balance widget).
class HomeWidgetAmount extends StatelessWidget {
  final String label;
  final String amount;
  final Color? color;

  const HomeWidgetAmount({
    super.key,
    required this.label,
    required this.amount,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// One budget: name, spent/target line, and progress bar.
class HomeWidgetBudget extends StatelessWidget {
  final String name;
  final String progressText;
  final double ratio;
  final Color color;

  const HomeWidgetBudget({
    super.key,
    required this.name,
    required this.progressText,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            progressText,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
