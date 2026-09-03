import 'package:flutter/material.dart';
import 'package:piggybank/helpers/currency_breakdown_sheet.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

class DaysSummaryBox extends StatefulWidget {
  /// DaysSummaryBox is a card that, given a list of records,
  /// shows the total income, total expenses, total balance resulting from
  /// all the movements in input days.
  ///
  /// The top row shows [walletLabel] and [walletBalanceString], and is tappable
  /// via [onWalletRowTap] to open the wallet filter picker.

  final List<Record?> records;
  final String walletLabel;
  final String walletBalanceString;
  final double? walletBalance;
  final Map<int, String?> walletCurrencyMap;
  final VoidCallback? onWalletRowTap;

  /// When false, the wallet header row (and its divider) is hidden, showing
  /// only the Income / Expenses / Balance stats. Used when the wallets feature
  /// is disabled or the "Show wallet bar on the homepage" toggle is off.
  final bool showWalletRow;

  DaysSummaryBox(
    this.records, {
    required this.walletLabel,
    required this.walletBalanceString,
    this.walletBalance,
    this.walletCurrencyMap = const {},
    this.onWalletRowTap,
    this.showWalletRow = true,
  });

  @override
  DaysSummaryBoxState createState() => DaysSummaryBoxState();
}

class DaysSummaryBoxState extends State<DaysSummaryBox> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);
  final _walletRowFont = const TextStyle(fontSize: 15.0);

  Iterable<Record?> get _incomeRecords => widget.records.where((record) =>
      record?.category?.categoryType == CategoryType.income &&
      !record!.isTransfer);

  Iterable<Record?> get _expenseRecords => widget.records.where((record) =>
      record?.category?.categoryType == CategoryType.expense &&
      !record!.isTransfer);

  Iterable<Record?> get _balanceRecords =>
      widget.records.where((record) => !record!.isTransfer);

  Widget _buildAmountWidget(Iterable<Record?> records,
      {bool isAbsValue = true,
      Color? color,
      RecordsTotalResult? precomputed,
      bool hidden = false}) {
    final style =
        color != null ? _biggerFont.copyWith(color: color) : _biggerFont;
    if (hidden) {
      // Concealed: no value, no currency breakdown gesture.
      return obscuredAmountTextWidget(style);
    }
    final result = precomputed ??
        computeConvertedTotal(records, widget.walletCurrencyMap,
            isAbsValue: isAbsValue);
    final text = formatRecordsTotalResult(result);
    final textWidget =
        Text(text, style: style, overflow: TextOverflow.ellipsis);

    if (!hasMixedCurrencies(records, widget.walletCurrencyMap))
      return textWidget;

    return GestureDetector(
      onLongPress: () => showCurrencyBreakdownSheet(
          context, records, widget.walletCurrencyMap,
          isAbsValue: isAbsValue),
      child: textWidget,
    );
  }

  Widget _buildStatColumn(String label, Iterable<Record?> records,
      {bool isAbsValue = true,
      Color? color,
      RecordsTotalResult? precomputed,
      bool hidden = false}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: _subtitleFont, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          _buildAmountWidget(records,
              isAbsValue: isAbsValue,
              color: color,
              precomputed: precomputed,
              hidden: hidden),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ServiceConfig.privacyModeNotifier,
      builder: (context, privacyMode, _) =>
          _buildCard(context, hidden: privacyMode),
    );
  }

  Widget _buildCard(BuildContext context, {required bool hidden}) {
    // Tapping any amount quickly shows or hides all amounts (privacy mode).
    final VoidCallback togglePrivacy =
        () => ServiceConfig.setPrivacyMode(!hidden);
    final brightness = Theme.of(context).brightness;
    final dimColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final balanceResult = computeConvertedTotal(
        _balanceRecords, widget.walletCurrencyMap,
        isAbsValue: false);
    final balanceColor = getAmountColor(balanceResult.total, brightness);
    final incomeColor = getAmountColor(
        computeConvertedTotal(_incomeRecords, widget.walletCurrencyMap).total,
        brightness);
    final expenseColor = getAmountColor(
        computeConvertedTotal(_expenseRecords, widget.walletCurrencyMap).total,
        brightness);
    return Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wallet header row
            if (widget.showWalletRow) ...[
              InkWell(
                onTap: widget.onWalletRowTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        widget.walletLabel,
                        style: _walletRowFont,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      hidden
                          ? obscuredAmountTextWidget(
                              widget.walletBalance != null
                                  ? _walletRowFont.copyWith(
                                      color: getAmountColor(
                                          widget.walletBalance!, brightness))
                                  : _walletRowFont)
                          : Text(
                              widget.walletBalanceString,
                              style: widget.walletBalance != null
                                  ? _walletRowFont.copyWith(
                                      color: getAmountColor(
                                          widget.walletBalance!, brightness))
                                  : _walletRowFont,
                            ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 18, color: dimColor),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            // Income / Expenses / Balance row. Tapping any amount quickly
            // shows or hides all amounts (privacy mode, see the toolbar eye).
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: togglePrivacy,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Row(
                    children: <Widget>[
                      _buildStatColumn("Income".i18n, _incomeRecords,
                          color: incomeColor, hidden: hidden),
                      VerticalDivider(endIndent: 10, indent: 10),
                      _buildStatColumn("Expenses".i18n, _expenseRecords,
                          color: expenseColor, hidden: hidden),
                      VerticalDivider(endIndent: 10, indent: 10),
                      _buildStatColumn("Balance".i18n, _balanceRecords,
                          isAbsValue: false,
                          color: balanceColor,
                          precomputed: balanceResult,
                          hidden: hidden),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
