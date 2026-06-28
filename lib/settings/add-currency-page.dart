import 'package:flutter/material.dart';
import 'package:piggybank/components/amount_input_field.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/wallets/currency-picker-page.dart';

import 'currencies-page.dart';

class AddCurrencyPage extends StatefulWidget {
  final String mainCurrency;
  final List<String> existingCodes;

  /// When non-null, the currency picker is skipped and this currency is pre-selected.
  final String? preSelectedCurrency;

  /// When non-null, pre-fills the conversion ratio field.
  final double? preFilledRatio;

  /// When non-null, pre-fills the decimal digits setting (for editing).
  final int? preFilledDecimalDigits;

  const AddCurrencyPage({
    Key? key,
    required this.mainCurrency,
    required this.existingCodes,
    this.preSelectedCurrency,
    this.preFilledRatio,
    this.preFilledDecimalDigits,
  }) : super(key: key);

  @override
  _AddCurrencyPageState createState() => _AddCurrencyPageState();
}

class _AddCurrencyPageState extends State<AddCurrencyPage> {
  String? _selectedCurrency;
  final _ratioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Per-currency decimal digit override. -1 means "use global default".
  int _decimalDigits = -1;

  /// The set of available decimal digit options shown in the dropdown.
  static const List<int> _decimalDigitOptions = [
    0, 1, 2, 3, 4, 5, 6, 7, 8,
  ];

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.preSelectedCurrency;
    if (widget.preFilledRatio != null) {
      _ratioController.text = widget.preFilledRatio.toString();
    }
    _decimalDigits = widget.preFilledDecimalDigits ?? -1;
  }

  @override
  void dispose() {
    _ratioController.dispose();
    super.dispose();
  }

  String _getCurrencyLabel(String isoCode) {
    final info = CurrencyInfo.byCode(isoCode);
    if (info != null) return '${info.symbol}  $isoCode — ${info.name}';
    return isoCode;
  }

  Future<void> _pickCurrency() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencyPickerPage(
          selectedCurrency: _selectedCurrency,
          showAllCurrencies: true,
        ),
      ),
    );
    if (result == null) return; // back pressed
    if (result.isEmpty) return; // "no currency" not meaningful here

    if (widget.existingCodes.contains(result)) {
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

    setState(() {
      _selectedCurrency = result;
    });
  }

  void _save() {
    if (_selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select a currency.".i18n),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ratio = tryParseCurrencyString(_ratioController.text)!;
    Navigator.of(context).pop(
      UserCurrency(
        isoCode: _selectedCurrency!,
        ratioToMain: ratio,
        decimalDigits: _decimalDigits >= 0 ? _decimalDigits : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainInfo = CurrencyInfo.byCode(widget.mainCurrency);
    final mainSymbol = mainInfo?.symbol ?? widget.mainCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Currency".i18n),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Currency picker
              Text(
                "Currency".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _selectedCurrency != null
                      ? _getCurrencyLabel(_selectedCurrency!)
                      : "Select a currency".i18n,
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedCurrency != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickCurrency,
              ),
              const Divider(thickness: 0.5),
              const SizedBox(height: 16),

              // Conversion ratio
              Text(
                "Conversion Ratio".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _selectedCurrency != null
                      ? "1 $_selectedCurrency = ? $mainSymbol"
                      : "1 [currency] = ? $mainSymbol",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              AmountInputField(
                controller: _ratioController,
                labelText: "1 ${_selectedCurrency ?? '[currency]'} =".i18n,
                suffixText: mainSymbol,
                allowNegative: false,
                currencyCode: _selectedCurrency,
                decimalDigits: _decimalDigits >= 0 ? _decimalDigits : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter a value".i18n;
                  }
                  final parsed = tryParseCurrencyString(value);
                  if (parsed == null || parsed <= 0) {
                    return amountFormatErrorMessage();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Decimal digits
              Text(
                "Decimal digits".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "Number of decimal places for this currency (e.g., 8 for Bitcoin)"
                      .i18n,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _decimalDigits,
                decoration: InputDecoration(
                  labelText: "Decimal places".i18n,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                isExpanded: true,
                items: [
                  // "Use default" option
                  DropdownMenuItem<int>(
                    value: -1,
                    child: Text("Use global default (%s)".i18n.fill([
                      getNumberDecimalDigits().toString(),
                    ])),
                  ),
                  ..._decimalDigitOptions.map((digits) {
                    return DropdownMenuItem<int>(
                      value: digits,
                      child: Text("$digits"),
                    );
                  }),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _decimalDigits = value;
                  });
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<double>(
        valueListenable: inAppKeyboardHeight,
        builder: (context, kbHeight, child) => Padding(
          padding: EdgeInsets.only(bottom: kbHeight),
          child: child,
        ),
        child: FloatingActionButton(
          onPressed: _save,
          tooltip: "Save".i18n,
          child: const Icon(Icons.save),
        ),
      ),
    );
  }
}
