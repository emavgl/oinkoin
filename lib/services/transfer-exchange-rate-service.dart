import 'dart:convert';

import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/currencies-page.dart';

/// Keeps current conversion preferences aligned with the latest dated transfer.
/// Historical record amounts are never changed. Pairs without any completed
/// transfer retain their existing configured rate.
class TransferExchangeRateService {
  static Future<void>? _pending;

  /// Serializes refreshes so concurrent saves cannot persist stale snapshots.
  /// [asOf] also lets scheduled transactions become eligible on app resume.
  static Future<void> refresh(DatabaseInterface database, {DateTime? asOf}) {
    final pending = _pending;
    final next = pending == null
        ? _refresh(database, asOf)
        : pending.then((_) => _refresh(database, asOf));
    // A failed refresh must not prevent subsequent attempts.
    final settled = next.catchError((Object _) {});
    _pending = settled;
    settled.then((_) {
      if (identical(_pending, settled)) _pending = null;
    });
    return next;
  }

  static Future<void> _refresh(
    DatabaseInterface database,
    DateTime? asOf,
  ) async {
    final prefs = ServiceConfig.sharedPreferences;
    final main = getDefaultCurrency();
    if (prefs == null || main == null) return;
    final latest = await database.getLatestMainCurrencyTransferRates(
      main,
      asOf ?? DateTime.now().toUtc(),
    );
    if (latest.isEmpty) return;

    final rates = getConversionRates();
    var ratesChanged = false;
    for (final entry in latest.entries) {
      final forward = '${main}_${entry.key}';
      final reverse = '${entry.key}_$main';
      if (rates[forward] != entry.value || rates[reverse] != 1 / entry.value) {
        rates[forward] = entry.value;
        rates[reverse] = 1 / entry.value;
        ratesChanged = true;
      }
    }
    if (ratesChanged) {
      await prefs.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode(rates),
      );
    }

    // Currency settings store other→main rather than main→other. Update only
    // the ratio, preserving custom names, symbols, order and decimal digits.
    final config = getUserCurrencyConfig();
    if (config.mainCurrency != main) return;
    var configChanged = false;
    config.currencies = config.currencies.map((currency) {
      final rate = latest[currency.isoCode];
      if (rate == null || currency.ratioToMain == 1 / rate) return currency;
      configChanged = true;
      return currency.copyWith(ratioToMain: 1 / rate);
    }).toList();
    if (configChanged) {
      await prefs.setString(
        PreferencesKeys.userCurrencies,
        jsonEncode(config.toJson()),
      );
    }
  }
}
