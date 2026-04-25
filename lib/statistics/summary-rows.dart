import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/components/category_icon_circle.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:piggybank/statistics/category-tag-records-page.dart';
import 'package:piggybank/statistics/category-tag-balance-page.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';

/// Base widget for summary rows displaying aggregated data.
///
/// Provides common layout with label, amount, percentage, and progress bar.
/// Subclasses must implement [buildLeading] and [onTap].
abstract class SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxSum;
  final double totalSum;
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  final DateTime? selectedDate;
  final AggregationMethod? aggregationMethod;
  final bool showPercentage;
  final bool showProgressBar;
  final String? currency;

  final double originalValue;
  final String? originalCurrency;

  const SummaryRow({
    Key? key,
    required this.label,
    required this.value,
    required this.maxSum,
    required this.totalSum,
    required this.records,
    this.from,
    this.to,
    this.selectedDate,
    this.aggregationMethod,
    this.showPercentage = true,
    this.showProgressBar = true,
    this.currency,
    this.originalValue = 0.0,
    this.originalCurrency,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (100 * value.abs()) / totalSum;
    final percentageBar = value.abs() / maxSum;
    final percentageStr = percentage.toStringAsFixed(2);
    final biggerFont = const TextStyle(fontSize: 16.0);
    final secondaryFont = const TextStyle(fontSize: 14.0, color: Colors.grey);

    final bool hasCurrencyConversion = currency != null &&
        currency!.isNotEmpty &&
        originalCurrency != null &&
        originalCurrency!.isNotEmpty &&
        originalCurrency != currency;

    Widget amountWidget;
    if (hasCurrencyConversion) {
      final originalStr =
          formatCurrencyAmount(originalValue.abs(), originalCurrency!);
      final convertedStr = formatCurrencyAmount(value.abs(), currency!);
      final primaryText =
          showPercentage ? '$convertedStr ($percentageStr%)' : convertedStr;
      amountWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(primaryText, style: biggerFont, textAlign: TextAlign.right),
          Text(originalStr, style: secondaryFont, textAlign: TextAlign.right),
        ],
      );
    } else {
      String valueStr;
      if (currency != null && currency!.isNotEmpty) {
        valueStr = formatCurrencyAmount(value.abs(), currency!);
      } else {
        valueStr = getCurrencyValueString(value.abs());
      }
      amountWidget = Text(
        showPercentage ? '$valueStr ($percentageStr%)' : valueStr,
        style: biggerFont,
      );
    }

    final List<Widget> columnChildren = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: biggerFont,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: 5),
            child: amountWidget,
          ),
        ],
      ),
    ];

    if (showProgressBar) {
      columnChildren.add(
        Container(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: percentageBar,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      );
    }

    return ListTile(
      onTap: () => onTap(context),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
      horizontalTitleGap: 16.0,
      minLeadingWidth: 40.0,
      title: Column(
        children: columnChildren,
      ),
      leading: buildLeading(context),
    );
  }

  /// Builds the leading widget (icon). Must be implemented by subclasses.
  Widget buildLeading(BuildContext context);

  /// Called when the row is tapped. Must be implemented by subclasses.
  void onTap(BuildContext context);

  /// Filters records by date if a date is selected.
  List<Record?> filterRecordsByDate(List<Record?> recordsToFilter) {
    return RecordFilters.byDate(
        recordsToFilter, selectedDate, aggregationMethod);
  }
}

/// Widget that displays a row for a single category in the summary list.
class CategorySummaryRow extends SummaryRow {
  final Category category;

  CategorySummaryRow({
    Key? key,
    required this.category,
    required double value,
    required double maxSum,
    required double totalSum,
    required List<Record?> records,
    DateTime? from,
    DateTime? to,
    DateTime? selectedDate,
    AggregationMethod? aggregationMethod,
    String? currency,
    double originalValue = 0.0,
    String? originalCurrency,
  }) : super(
          key: key,
          label: category.name!,
          value: value,
          maxSum: maxSum,
          totalSum: totalSum,
          records: records,
          from: from,
          to: to,
          selectedDate: selectedDate,
          aggregationMethod: aggregationMethod,
          currency: currency,
          originalValue: originalValue,
          originalCurrency: originalCurrency,
        );

  @override
  Widget buildLeading(BuildContext context) {
    return CategoryIconCircle(
      iconEmoji: category.iconEmoji,
      iconDataFromDefaultIconSet: category.icon,
      backgroundColor: category.color,
      overlayIcon: category.isArchived ? Icons.archive : null,
    );
  }

  @override
  void onTap(BuildContext context) {
    final categoryRecords = records
        .where((element) => element?.category?.name == category.name)
        .toList();

    DateTime? detailFrom = from;
    DateTime? detailTo = to;
    List<Record?> detailRecords = categoryRecords;
    DateTime? detailSelectedDate = selectedDate;

    if (selectedDate != null) {
      detailFrom = selectedDate;
      detailTo = getEndOfInterval(selectedDate!, aggregationMethod);

      // Include all category records within the date range, not just the single selected date
      // Use inclusive range check: not before start AND not after end
      detailRecords = categoryRecords.where((r) {
        final recordDate = r!.dateTime;
        return !recordDate.isBefore(detailFrom!) &&
            !recordDate.isAfter(detailTo!);
      }).toList();

      detailSelectedDate = null;
    }
    String intervalTitle = getDateRangeStr(detailFrom!, detailTo!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryTagRecordsPage(
          title: "$intervalTitle: ${category.name}",
          records: detailRecords,
          from: detailFrom,
          to: detailTo,
          aggregationMethod: aggregationMethod,
          category: category,
          headerColor: category.color,
          selectedDate: detailSelectedDate,
        ),
      ),
    );
  }
}

/// Widget that displays a row for a single tag in the summary list.
class TagSummaryRow extends SummaryRow {
  final bool isBalance;

  TagSummaryRow({
    Key? key,
    required String tag,
    required double value,
    required double maxSum,
    required double totalSum,
    required List<Record?> records,
    DateTime? from,
    DateTime? to,
    DateTime? selectedDate,
    AggregationMethod? aggregationMethod,
    this.isBalance = false,
    String? currency,
    double originalValue = 0.0,
    String? originalCurrency,
  }) : super(
          key: key,
          label: tag,
          value: value,
          maxSum: maxSum,
          totalSum: totalSum,
          records: records,
          from: from,
          to: to,
          selectedDate: selectedDate,
          aggregationMethod: aggregationMethod,
          currency: currency,
          originalValue: originalValue,
          originalCurrency: originalCurrency,
        );

  @override
  Widget buildLeading(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.label, color: Colors.blue, size: 20),
    );
  }

  @override
  void onTap(BuildContext context) {
    final tagRecords = records
        .where((element) => element?.tags.contains(label) ?? false)
        .toList();

    DateTime? detailFrom = from;
    DateTime? detailTo = to;
    List<Record?> detailRecords = tagRecords;
    DateTime? detailSelectedDate = selectedDate;

    if (selectedDate != null) {
      detailFrom = selectedDate;
      detailTo = getEndOfInterval(selectedDate!, aggregationMethod);
      detailRecords = tagRecords.where((r) {
        final recordDate = r!.dateTime;
        return !recordDate.isBefore(detailFrom!) &&
            !recordDate.isAfter(detailTo!);
      }).toList();
      detailSelectedDate = null;
    }
    String intervalTitle = getDateRangeStr(detailFrom!, detailTo!);

    if (isBalance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryTagBalancePage(
            title: "$intervalTitle: #$label",
            records: detailRecords,
            from: detailFrom!,
            to: detailTo!,
            aggregationMethod: aggregationMethod,
            selectedDate: detailSelectedDate,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryTagRecordsPage(
            title: "$intervalTitle: #$label",
            records: detailRecords,
            from: detailFrom,
            to: detailTo,
            aggregationMethod: aggregationMethod,
            headerColor: Colors.blue,
            selectedDate: detailSelectedDate,
          ),
        ),
      );
    }
  }
}

/// Widget that displays a row for viewing all records in the selection.
/// Shows as a special row with yellow star icon, used when a date interval is selected.
class ViewAllSummaryRow extends SummaryRow {
  final VoidCallback onTapCallback;

  ViewAllSummaryRow({
    required String label,
    required double totalAmount,
    required this.onTapCallback,
    List<Record?> records = const [],
    String? currency,
    double originalValue = 0.0,
    String? originalCurrency,
  }) : super(
          label: label,
          value: totalAmount,
          maxSum: totalAmount,
          totalSum: totalAmount,
          records: records,
          showPercentage: false,
          showProgressBar: false,
          currency: currency,
          originalValue: originalValue,
          originalCurrency: originalCurrency,
        );

  @override
  Widget buildLeading(BuildContext context) {
    return CategoryIconCircle(
      iconEmoji: null,
      iconDataFromDefaultIconSet: Icons.align_horizontal_left,
      backgroundColor: Colors.yellow.shade700,
    );
  }

  @override
  void onTap(BuildContext context) => onTapCallback();
}
