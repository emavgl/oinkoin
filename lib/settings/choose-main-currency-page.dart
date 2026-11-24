import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/settings/add-custom-currency-page.dart';
import 'package:piggybank/settings/currencies-page.dart';

class ChooseMainCurrencyPage extends StatefulWidget {
  final String? selectedCurrency;

  const ChooseMainCurrencyPage({Key? key, this.selectedCurrency})
      : super(key: key);

  @override
  _ChooseMainCurrencyPageState createState() => _ChooseMainCurrencyPageState();
}

class _ChooseMainCurrencyPageState extends State<ChooseMainCurrencyPage> {
  String _searchQuery = '';

  /// Built-in currencies plus any custom currency the user has defined, so a
  /// custom currency can also be selected as the main one.
  List<String> get _allCodes {
    final codes = CurrencyInfo.allCurrencies.map((c) => c.isoCode).toList();
    for (final custom in CurrencyInfo.customCurrencies) {
      if (!codes.contains(custom.isoCode)) codes.add(custom.isoCode);
    }
    return codes;
  }

  List<String> get _filteredCodes {
    final base = _allCodes;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((code) {
      final info = CurrencyInfo.byCode(code);
      return code.toLowerCase().contains(q) ||
          (info != null && info.name.toLowerCase().contains(q)) ||
          (info != null && info.symbol.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _addCustomCurrency() async {
    final config = getUserCurrencyConfig();
    final result = await Navigator.push<UserCurrency?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomCurrencyPage(
          mainCurrency: widget.selectedCurrency ?? '',
          existingCodes: config.isoCodes,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    // The custom currency has been registered in [CurrencyInfo] by the form
    // page, so it can be picked as the main currency right away.
    Navigator.of(context).pop(result.isoCode);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCodes;
    final showEmptyState = filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text("Choose the main currency".i18n),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: _addCustomCurrency,
            icon: const Icon(Icons.add),
            tooltip: "Add your missing currency".i18n,
          ),
        ],
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
      body: Column(
        children: [
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                "Your main currency is the reference for all conversion rates. Pick the currency you use most often."
                    .i18n,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
          const Divider(thickness: 0.5, height: 1),
          Expanded(
            child: showEmptyState
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          "No currency found".i18n,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Would you like to add your own currency?".i18n,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          ),
        ],
      ),
    );
  }
}
