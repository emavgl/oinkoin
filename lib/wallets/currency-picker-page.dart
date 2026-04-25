import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/add-custom-currency-page.dart';
import 'package:piggybank/settings/add-currency-page.dart';
import 'package:piggybank/settings/choose-main-currency-page.dart';
import 'package:piggybank/settings/currencies-page.dart';

class CurrencyPickerPage extends StatefulWidget {
  final String? selectedCurrency;

  /// When true, shows all available currencies (used for picking a new one to add).
  /// When false, shows user-defined currencies + "Add currency" FAB.
  final bool showAllCurrencies;

  const CurrencyPickerPage({
    Key? key,
    this.selectedCurrency,
    this.showAllCurrencies = false,
  }) : super(key: key);

  @override
  _CurrencyPickerPageState createState() => _CurrencyPickerPageState();
}

class _CurrencyPickerPageState extends State<CurrencyPickerPage> {
  String _searchQuery = '';
  UserCurrencyConfig _config = UserCurrencyConfig();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _config = getUserCurrencyConfig();
    });
    // If no main currency is set, prompt the user to pick one first
    if (!widget.showAllCurrencies && _config.mainCurrency == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chooseMainCurrency();
      });
    }
  }

  Future<void> _chooseMainCurrency() async {
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
      final existing = _config.getByCode(result);
      if (existing == null) {
        _config.currencies
            .insert(0, UserCurrency(isoCode: result, ratioToMain: 1.0));
      }
    });
    await saveUserCurrencyConfig(_config);
    await _assignMainCurrencyToWallets(result);
  }

  /// Assigns [currency] to all wallets that have no currency set,
  /// after asking the user to confirm.
  Future<void> _assignMainCurrencyToWallets(String currency) async {
    final db = ServiceConfig.database;
    final wallets = await db.getAllWallets();
    final targets = wallets
        .where((w) => w.currency == null || w.currency!.isEmpty)
        .toList();
    if (targets.isEmpty) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Assign Currency".i18n),
        content: Text("Assign %s to all wallets that have no currency set?"
            .i18n
            .fill([currency])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("No".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Yes".i18n),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final wallet in targets) {
      wallet.currency = currency;
      await db.updateWallet(wallet.id!, wallet);
    }
  }

  Future<void> _addCurrency() async {
    // Step 1: pick from the full list
    final picked = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => const CurrencyPickerPage(showAllCurrencies: true),
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

    // Step 2: set conversion ratio
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

  Future<void> _addCustomCurrency() async {
    final result = await Navigator.push<UserCurrency?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomCurrencyPage(
          mainCurrency: _config.mainCurrency!,
          existingCodes: _config.isoCodes,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _config.currencies.add(result);
    });
    await saveUserCurrencyConfig(_config);
  }

  List<String> get _allCodes {
    final customCodes = CurrencyInfo.customCurrencies.map((c) => c.isoCode);
    return [
      ...CurrencyInfo.allCurrencies.map((c) => c.isoCode),
      ...customCodes
    ];
  }

  List<String> get _filteredCodes {
    final base = widget.showAllCurrencies ? _allCodes : _config.isoCodes;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((code) {
      final info = CurrencyInfo.byCode(code);
      return code.toLowerCase().contains(q) ||
          (info != null && info.name.toLowerCase().contains(q)) ||
          (info != null && info.symbol.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCodes;
    final showEmptyState = filtered.isEmpty && _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text("Select Currency".i18n),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: "Search currency".i18n,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: showEmptyState
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No currency found".i18n,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Would you like to add your own currency?".i18n,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addCustomCurrency,
                    icon: const Icon(Icons.add),
                    label: Text("Add your missing currency".i18n),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final code = filtered[index];
                final info = CurrencyInfo.byCode(code);
                final isSelected = code == widget.selectedCurrency;

                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    child: Text(
                      info?.symbol ?? code,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  title: Text(code),
                  subtitle: Text(info?.name ?? code),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(code),
                );
              },
            ),
      floatingActionButton: widget.showAllCurrencies
          ? null
          : FloatingActionButton(
              onPressed: _addCurrency,
              tooltip: "Add currency".i18n,
              child: const Icon(Icons.add),
            ),
    );
  }
}
