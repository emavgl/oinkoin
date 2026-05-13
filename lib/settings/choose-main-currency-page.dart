import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';

class ChooseMainCurrencyPage extends StatelessWidget {
  final String? selectedCurrency;

  const ChooseMainCurrencyPage({Key? key, this.selectedCurrency})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Choose the main currency".i18n),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
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
            child: ListView.builder(
              itemCount: CurrencyInfo.allCurrencies.length,
              itemBuilder: (context, index) {
                final currency = CurrencyInfo.allCurrencies[index];
                final isSelected = currency.isoCode == selectedCurrency;

                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    child: Text(
                      currency.symbol,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  title: Text(currency.isoCode),
                  subtitle: Text(currency.name),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(currency.isoCode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
