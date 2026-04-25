import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/wallets/currency-picker-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConversionRatesPage extends StatefulWidget {
  @override
  _CurrencyConversionRatesPageState createState() =>
      _CurrencyConversionRatesPageState();
}

class _CurrencyConversionRatesPageState
    extends State<CurrencyConversionRatesPage> {
  final DatabaseInterface _database = ServiceConfig.database;
  late SharedPreferences _prefs;

  List<Wallet> _wallets = [];
  Set<String> _usedCurrencies = {};
  String? _defaultCurrency;
  Map<String, double> _rates = {};
  final Map<String, TextEditingController> _controllers = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final wallets = await _database.getAllWallets();
    final nonArchived = wallets.where((w) => !w.isArchived).toList();

    final currencies = nonArchived
        .map((w) => w.currency)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet();

    final defaultCurrency = _prefs.getString(PreferencesKeys.defaultCurrency);
    final rates = getConversionRates();

    setState(() {
      _wallets = nonArchived;
      _usedCurrencies = currencies;
      _defaultCurrency =
          (defaultCurrency == null || defaultCurrency.isEmpty) ? null : defaultCurrency;
      _rates = rates;
      _isLoading = false;
    });

    _initControllers();
  }

  void _initControllers() {
    // Dispose existing controllers
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    if (_defaultCurrency == null) return;

    for (final currency in _usedCurrencies) {
      if (currency == _defaultCurrency) continue;
      final key = '${currency}_$_defaultCurrency';
      final existingRate = _rates[key];
      final controller = TextEditingController(
        text: existingRate != null ? existingRate.toString() : '',
      );
      controller.addListener(() => _onRateChanged(currency, controller.text));
      _controllers[currency] = controller;
    }
  }

  void _onRateChanged(String fromCurrency, String text) {
    final rate = double.tryParse(text);
    final key = '${fromCurrency}_$_defaultCurrency';
    if (rate != null && rate > 0) {
      _rates[key] = rate;
    } else {
      _rates.remove(key);
    }
    _saveRates();
  }

  Future<void> _saveRates() async {
    final encoded = jsonEncode(_rates);
    await _prefs.setString(PreferencesKeys.currencyConversionRates, encoded);
  }

  Future<void> _pickDefaultCurrency() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencyPickerPage(selectedCurrency: _defaultCurrency),
      ),
    );
    if (result == null) return; // back pressed
    final newDefault = result.isEmpty ? null : result;
    await _prefs.setString(PreferencesKeys.defaultCurrency, newDefault ?? '');
    setState(() {
      _defaultCurrency = newDefault;
    });
    _initControllers();
  }

  String _getCurrencyLabel(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return "None".i18n;
    final info = CurrencyInfo.byCode(isoCode);
    if (info != null) return '${info.symbol}  $isoCode - ${info.name}';
    return isoCode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Currency".i18n),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final foreignCurrencies = _usedCurrencies
        .where((c) => c != _defaultCurrency)
        .toList()
      ..sort();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Default currency picker
          _buildSectionHeader("Default Currency".i18n),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text("Default Currency".i18n),
            subtitle: Text(_getCurrencyLabel(_defaultCurrency)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDefaultCurrency,
          ),
          const Divider(thickness: 0.5),

          // Conversion rates section
          _buildSectionHeader("Conversion Rates".i18n),

          if (_defaultCurrency == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Please set a default currency first.".i18n,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (foreignCurrencies.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "No conversion rates needed. All your wallets use the same currency.".i18n,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                "These rates are used to combine balances across wallets with different currencies.".i18n,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                "Enter how much 1 unit of each currency equals in %s".i18n.fill([_defaultCurrency!]),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ),
            for (final currency in foreignCurrencies)
              _buildRateRow(currency),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildRateRow(String currency) {
    final controller = _controllers[currency];
    final info = CurrencyInfo.byCode(currency);
    final defaultInfo = CurrencyInfo.byCode(_defaultCurrency!);
    final walletNames = _wallets
        .where((w) => w.currency == currency)
        .map((w) => w.name)
        .where((name) => name.isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '1 ${info?.symbol ?? currency} ($currency) =',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: '0.00',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${defaultInfo?.symbol ?? _defaultCurrency!} ($_defaultCurrency)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          if (walletNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "${"Used by".i18n}: $walletNames",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
