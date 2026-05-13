import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/models/record.dart';

void showCurrencyBreakdownSheet(
  BuildContext context,
  Iterable<Record?> records,
  Map<int, String?> walletCurrencyMap, {
  bool isAbsValue = false,
}) {
  final breakdown = buildCurrencyBreakdown(records, walletCurrencyMap,
      isAbsValue: isAbsValue);
  if (breakdown.isEmpty) return;

  final total = computeConvertedTotal(records, walletCurrencyMap,
      isAbsValue: isAbsValue);
  final entries = breakdown.entries.toList()
    ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Currency Breakdown".i18n,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.isNotEmpty
                          ? (CurrencyInfo.byCode(entry.key)?.name ?? entry.key)
                          : "No currency".i18n,
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      entry.key.isNotEmpty
                          ? formatCurrencyAmount(entry.value, entry.key)
                          : getCurrencyValueString(entry.value),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            if (total.currency != null) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Total in %s".i18n.fill([total.currency!]),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatRecordsTotalResult(total),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
