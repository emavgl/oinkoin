import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/settings/currencies-page.dart';

class AddCustomCurrencyPage extends StatefulWidget {
  final String mainCurrency;
  final List<String> existingCodes;
  final UserCurrency? editCurrency;

  const AddCustomCurrencyPage({
    Key? key,
    required this.mainCurrency,
    required this.existingCodes,
    this.editCurrency,
  }) : super(key: key);

  @override
  _AddCustomCurrencyPageState createState() => _AddCustomCurrencyPageState();
}

class _AddCustomCurrencyPageState extends State<AddCustomCurrencyPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _symbolController;

  @override
  void initState() {
    super.initState();
    _codeController =
        TextEditingController(text: widget.editCurrency?.isoCode ?? '');
    _nameController =
        TextEditingController(text: widget.editCurrency?.customName ?? '');
    _symbolController =
        TextEditingController(text: widget.editCurrency?.customSymbol ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.toUpperCase().trim();
    final name = _nameController.text.trim();
    var symbol = _symbolController.text.trim();

    if (symbol.isEmpty) {
      symbol = code;
    }

    CurrencyInfo.addCustomCurrency(CurrencyInfo(
      isoCode: code,
      name: name,
      customSymbol: symbol,
    ));

    final userCurrency = UserCurrency(
      isoCode: code,
      ratioToMain: 1.0,
      customSymbol: symbol,
      customName: name,
    );

    Navigator.of(context).pop(userCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editCurrency != null;
    final mainInfo = CurrencyInfo.byCode(widget.mainCurrency);
    final mainSymbol = mainInfo?.symbol ?? widget.mainCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? "Edit Custom Currency".i18n
            : "Add Custom Currency".i18n),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Currency Code".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: "Code (e.g., MYC)".i18n,
                  hintText: "e.g., MYC",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a currency code".i18n;
                  }
                  final code = value.trim().toUpperCase();
                  if (CurrencyInfo.byCode(code) != null &&
                      code != widget.editCurrency?.isoCode) {
                    return "This currency already exists".i18n;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                "Currency Name".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Name (e.g., My Currency)".i18n,
                  hintText: "e.g., My Currency",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a currency name".i18n;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                "Symbol (optional)".i18n,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _symbolController,
                decoration: InputDecoration(
                  labelText: "Symbol (e.g., M)".i18n,
                  hintText: "e.g., M",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        tooltip: "Save".i18n,
        child: const Icon(Icons.save),
      ),
    );
  }
}
