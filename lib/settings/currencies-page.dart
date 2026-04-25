import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/wallets/currency-picker-page.dart';
import 'package:piggybank/settings/add-currency-page.dart';
import 'package:piggybank/settings/choose-main-currency-page.dart';

/// A user-defined currency entry with its conversion ratio to the main currency.
class UserCurrency {
  final String isoCode;
  final double ratioToMain;
  final String? customSymbol;
  final String? customName;

  UserCurrency({
    required this.isoCode,
    required this.ratioToMain,
    this.customSymbol,
    this.customName,
  });

  bool get isCustom => customName != null;

  UserCurrency copyWith({
    String? isoCode,
    double? ratioToMain,
    String? customSymbol,
    String? customName,
  }) {
    return UserCurrency(
      isoCode: isoCode ?? this.isoCode,
      ratioToMain: ratioToMain ?? this.ratioToMain,
      customSymbol: customSymbol ?? this.customSymbol,
      customName: customName ?? this.customName,
    );
  }

  Map<String, dynamic> toJson() => {
        'isoCode': isoCode,
        'ratioToMain': ratioToMain,
        if (customSymbol != null) 'customSymbol': customSymbol,
        if (customName != null) 'customName': customName,
      };

  factory UserCurrency.fromJson(Map<String, dynamic> json) {
    return UserCurrency(
      isoCode: json['isoCode'] as String,
      ratioToMain: (json['ratioToMain'] as num).toDouble(),
      customSymbol: json['customSymbol'] as String?,
      customName: json['customName'] as String?,
    );
  }
}

/// Stored user currency configuration.
class UserCurrencyConfig {
  String? mainCurrency;
  List<UserCurrency> currencies;

  UserCurrencyConfig({this.mainCurrency, List<UserCurrency>? currencies})
      : currencies = currencies ?? [];

  Map<String, dynamic> toJson() => {
        'mainCurrency': mainCurrency,
        'currencies': currencies.map((c) => c.toJson()).toList(),
      };

  factory UserCurrencyConfig.fromJson(Map<String, dynamic> json) {
    return UserCurrencyConfig(
      mainCurrency: json['mainCurrency'] as String?,
      currencies: (json['currencies'] as List<dynamic>?)
              ?.map((e) => UserCurrency.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Returns the list of ISO codes the user has defined.
  List<String> get isoCodes => currencies.map((c) => c.isoCode).toList();

  /// Returns the UserCurrency for [isoCode], or null.
  UserCurrency? getByCode(String isoCode) {
    try {
      return currencies.firstWhere((c) => c.isoCode == isoCode);
    } catch (_) {
      return null;
    }
  }
}

/// Loads the UserCurrencyConfig from SharedPreferences.
UserCurrencyConfig getUserCurrencyConfig() {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return UserCurrencyConfig();
  final raw = prefs.getString(PreferencesKeys.userCurrencies);
  if (raw == null || raw.isEmpty) return UserCurrencyConfig();
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final config = UserCurrencyConfig.fromJson(decoded);
    _loadCustomCurrencies(config);
    return config;
  } catch (_) {
    return UserCurrencyConfig();
  }
}

void _loadCustomCurrencies(UserCurrencyConfig config) {
  for (final currency in config.currencies) {
    if (currency.isCustom && CurrencyInfo.byCode(currency.isoCode) == null) {
      CurrencyInfo.addCustomCurrency(CurrencyInfo(
        isoCode: currency.isoCode,
        name: currency.customName!,
        customSymbol: currency.customSymbol,
      ));
    }
  }
}

/// Saves the UserCurrencyConfig to SharedPreferences and syncs conversion rates.
Future<void> saveUserCurrencyConfig(UserCurrencyConfig config) async {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return;
  await prefs.setString(
      PreferencesKeys.userCurrencies, jsonEncode(config.toJson()));
  // Sync legacy keys
  if (config.mainCurrency != null) {
    await prefs.setString(
        PreferencesKeys.defaultCurrency, config.mainCurrency!);
    final rates = <String, double>{};
    for (final c in config.currencies) {
      if (c.isoCode == config.mainCurrency) continue;
      if (c.ratioToMain > 0) {
        rates['${c.isoCode}_${config.mainCurrency}'] = c.ratioToMain;
      }
    }
    await prefs.setString(
        PreferencesKeys.currencyConversionRates, jsonEncode(rates));
  }
}

/// Returns the list of user-defined currency ISO codes.
List<String> getUserCurrencyCodes() {
  return getUserCurrencyConfig().isoCodes;
}

class CurrenciesPage extends StatefulWidget {
  @override
  _CurrenciesPageState createState() => _CurrenciesPageState();
}

class _CurrenciesPageState extends State<CurrenciesPage> {
  UserCurrencyConfig _config = UserCurrencyConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _config = getUserCurrencyConfig();
      _isLoading = false;
    });
    // If no main currency is set, prompt the user to pick one
    if (_config.mainCurrency == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickMainCurrency();
      });
    }
  }

  Future<void> _pickMainCurrency() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseMainCurrencyPage(
          selectedCurrency: _config.mainCurrency,
        ),
      ),
    );
    if (result == null || result.isEmpty) return;

    setState(() {
      _config.mainCurrency = result;
      // Ensure main currency is in the list with ratio 1.0
      final existing = _config.getByCode(result);
      if (existing == null) {
        _config.currencies
            .insert(0, UserCurrency(isoCode: result, ratioToMain: 1.0));
      }
    });
    await saveUserCurrencyConfig(_config);
  }

  Future<void> _addCurrency() async {
    if (_config.mainCurrency == null) {
      await _pickMainCurrency();
      if (_config.mainCurrency == null) return;
    }

    // Step 1: pick a currency from the full list
    final picked = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencyPickerPage(
          showAllCurrencies: true,
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    if (_config.isoCodes.contains(picked)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("This currency is already added.".i18n),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Step 2: set the conversion ratio
    final result = await Navigator.push<UserCurrency?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCurrencyPage(
          mainCurrency: _config.mainCurrency!,
          existingCodes: _config.isoCodes,
          preSelectedCurrency: picked,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _config.currencies.add(result);
    });
    await saveUserCurrencyConfig(_config);
  }

  Future<void> _editCurrency(UserCurrency userCurrency) async {
    final result = await Navigator.push<UserCurrency?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCurrencyPage(
          mainCurrency: _config.mainCurrency!,
          existingCodes: _config.isoCodes,
          preSelectedCurrency: userCurrency.isoCode,
          preFilledRatio: userCurrency.ratioToMain,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      final idx =
          _config.currencies.indexWhere((c) => c.isoCode == result.isoCode);
      if (idx >= 0) {
        _config.currencies[idx] = result;
      } else {
        _config.currencies.add(result);
      }
    });
    await saveUserCurrencyConfig(_config);
  }

  Future<void> _removeCurrency(String isoCode) async {
    if (isoCode == _config.mainCurrency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Cannot remove the main currency. Change it first.".i18n),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if any wallet uses this currency
    final db = ServiceConfig.database;
    final wallets = await db.getAllWallets();
    final hasWallets =
        wallets.any((w) => w.currency != null && w.currency == isoCode);
    if (hasWallets) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Cannot remove %s: there are wallets using this currency."
                    .i18n
                    .fill([isoCode])),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete currency".i18n),
        content: Text("Remove %s from your currencies?".i18n.fill([isoCode])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete".i18n),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _config.currencies.removeWhere((c) => c.isoCode == isoCode);
    });
    await saveUserCurrencyConfig(_config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Currencies".i18n),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCurrency,
        tooltip: "Add currency".i18n,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainCurrencySection(),
          const Divider(thickness: 0.5),
          _buildCurrenciesList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMainCurrencySection() {
    final label = _config.mainCurrency != null
        ? _getCurrencyLabel(_config.mainCurrency!)
        : "Not set".i18n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            "Main Currency".i18n,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ListTile(
          title: Text(label),
          subtitle:
              Text("This is the reference currency for conversion rates.".i18n),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickMainCurrency,
        ),
      ],
    );
  }

  Widget _buildCurrenciesList() {
    final others = _config.currencies
        .where((c) => c.isoCode != _config.mainCurrency)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            "Other currencies".i18n,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (others.isEmpty)
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
                        "No currencies added yet. Tap + to add one.".i18n,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          for (final c in others)
            _buildCurrencyTile(c.isoCode, userCurrency: c),
        const SizedBox(height: 75),
      ],
    );
  }

  Widget _buildCurrencyTile(String isoCode,
      {bool isMain = false, UserCurrency? userCurrency}) {
    final info = CurrencyInfo.byCode(isoCode);
    final symbol = info?.symbol ?? isoCode;
    final name = info?.name ?? isoCode;

    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Text(
          symbol,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      title: Row(
        children: [
          Text(isoCode),
          if (isMain) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Main".i18n,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: isMain
          ? Text(name)
          : Text(
              '$name — 1 $isoCode = ${userCurrency?.ratioToMain ?? '?'} ${_config.mainCurrency}'),
      onTap: isMain ? null : () => _editCurrency(userCurrency!),
      onLongPress: isMain ? null : () => _removeCurrency(isoCode),
    );
  }

  String _getCurrencyLabel(String isoCode) {
    final info = CurrencyInfo.byCode(isoCode);
    if (info != null) return '${info.symbol}  $isoCode — ${info.name}';
    return isoCode;
  }
}
