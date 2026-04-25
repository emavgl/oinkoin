import 'dart:async';

import 'package:flutter/material.dart';
import 'package:piggybank/services/logger.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/components/wallet_icon_square.dart';
import 'package:piggybank/components/icon_color_picker_section.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/style.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:piggybank/wallets/currency-picker-page.dart';
import 'package:piggybank/wallets/wallet-picker-page.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';

enum _WalletDeletionChoice { deleteAll, moveToWallet, keepInDefault }

class EditWalletPage extends StatefulWidget {
  /// EditWalletPage is a page for creating or editing a Wallet.
  /// Pass [passedWallet] to edit an existing wallet; leave null to create a new one.

  final Wallet? passedWallet;

  EditWalletPage({Key? key, this.passedWallet}) : super(key: key);

  @override
  _EditWalletPageState createState() => _EditWalletPageState(passedWallet);
}

class _EditWalletPageState extends State<EditWalletPage> {
  static final _logger = Logger.withContext('EditWalletPage');

  Wallet? passedWallet;
  late Wallet wallet;

  DatabaseInterface database = ServiceConfig.database;

  String? walletName;
  String? _selectedCurrency;
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  late int amountInputKeyboardTypeIndex;
  final bool autoDec = getAmountInputAutoDecimalShift();
  Timer? _mathDebounce;

  _EditWalletPageState(this.passedWallet);

  @override
  void initState() {
    super.initState();

    amountInputKeyboardTypeIndex = getAmountInputKeyboardTypeIndex();

    if (passedWallet == null) {
      wallet = Wallet(
        '',
        color: Wallet.colors[0],
        iconCodePoint: FontAwesomeIcons.wallet.codePoint,
        isDefault: false,
        sortOrder: 0,
      );
    } else {
      wallet = Wallet.fromMap(
          passedWallet!.toMap()..['balance'] = passedWallet!.balance);
      walletName = passedWallet!.name;
      _selectedCurrency = passedWallet!.currency;
    }

    // Initialize balance field — same logic as EditRecordPage
    if (passedWallet == null) {
      // New wallet: leave empty (hint shows "0"), unless autoDec is on
      if (autoDec) {
        final decSep = getDecimalSeparator();
        final decDigits = getNumberDecimalDigits();
        final zeroText = decDigits <= 0
            ? '0'
            : '0$decSep${List.filled(decDigits, '0').join()}';
        _balanceController.value = _balanceController.value.copyWith(
          text: zeroText,
          selection: TextSelection.collapsed(offset: zeroText.length),
          composing: TextRange.empty,
        );
      }
    } else {
      // Existing wallet: load current balance with grouping separators
      final displayBalance = wallet.balance ?? wallet.initialAmount;
      _balanceController.text =
          getCurrencyValueString(displayBalance, turnOffGrouping: false);
    }

    _balanceController.addListener(() {
      _mathDebounce?.cancel();
      _mathDebounce = Timer(const Duration(seconds: 2), () {
        solveMathExpressionAndUpdateController(_balanceController);
      });
    });
  }

  @override
  void dispose() {
    _mathDebounce?.cancel();
    _balanceController.dispose();
    super.dispose();
  }

  Widget _getPageSeparatorLabel(String labelText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(15, 15, 0, 5),
        child: Text(
          labelText,
          style: TextStyle(
            fontFamily: FontNameDefault,
            fontWeight: FontWeight.w300,
            fontSize: 26.0,
            color: MaterialThemeInstance.currentTheme?.colorScheme.onSurface,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _getWalletCirclePreview() {
    return Container(
      margin: EdgeInsets.all(10),
      child: WalletIconSquare(
        iconEmoji: wallet.iconEmoji,
        iconDataFromDefaultIconSet: wallet.icon,
        backgroundColor: wallet.color,
        size: 70,
        mainIconSize: 30,
      ),
    );
  }

  Widget _getNameField() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(10),
        child: TextFormField(
          onChanged: (text) => setState(() => walletName = text),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter the wallet name".i18n;
            }
            return null;
          },
          initialValue: walletName,
          style: TextStyle(
              fontSize: 22.0, color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "Wallet name".i18n,
            errorStyle: TextStyle(fontSize: 16.0),
          ),
        ),
      ),
    );
  }

  Widget _getBalanceField() {
    final decimalSep = getDecimalSeparator();
    final groupSep = getGroupingSeparator();
    final decDigits = getNumberDecimalDigits();
    final zeroHint = (autoDec && decDigits > 0)
        ? '0$decimalSep${List.filled(decDigits, '0').join()}'
        : '0';
    return Container(
      margin: EdgeInsets.fromLTRB(15, 5, 15, 5),
      child: TextFormField(
        controller: _balanceController,
        inputFormatters: buildAmountInputFormatters(
          decimalSep: decimalSep,
          groupSep: groupSep,
          autoDec: autoDec,
          decDigits: decDigits,
        ),
        autofocus: passedWallet == null,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please enter a value".i18n;
          }
          var numericValue = tryParseSignedCurrencyString(value);
          if (numericValue == null) {
            return "Not a valid format (use for example: %s)"
                .i18n
                .fill([getCurrencyValueString(1234.20, turnOffGrouping: true)]);
          }
          return null;
        },
        textAlign: TextAlign.end,
        style: TextStyle(
            fontSize: 32.0, color: Theme.of(context).colorScheme.onSurface),
        keyboardType: getAmountInputKeyboardType(amountInputKeyboardTypeIndex,
            signed: true),
        decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: zeroHint),
      ),
    );
  }

  Widget _getCurrencySection() {
    final currencyInfo = _selectedCurrency != null
        ? CurrencyInfo.byCode(_selectedCurrency!)
        : null;
    final currencyLabel = currencyInfo != null
        ? '${currencyInfo.symbol}  ${currencyInfo.isoCode} - ${currencyInfo.name}'
        : (_selectedCurrency != null ? _selectedCurrency! : "No currency".i18n);

    final isProUser = ServiceConfig.isPremium;
    final isDefaultWallet = passedWallet?.isDefault ?? false;
    final isRestricted = !isProUser && isDefaultWallet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _getPageSeparatorLabel("Currency".i18n),
        Divider(thickness: 0.5),
        ListTile(
          leading: Icon(Icons.currency_exchange,
              color: Theme.of(context).colorScheme.onSurface),
          title: Text(
            currencyLabel,
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
          trailing: isRestricted
              ? getProLabel(labelFontSize: 10.0)
              : _selectedCurrency != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _selectedCurrency = null),
                    )
                  : null,
          onTap: isRestricted
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PremiumSplashScreen(),
                    ),
                  );
                }
              : () async {
                  final result = await Navigator.push<String?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CurrencyPickerPage(
                        selectedCurrency: _selectedCurrency,
                      ),
                    ),
                  );
                  // null = user pressed back (no change)
                  // '' (empty string) = user tapped "No currency" (clear)
                  // 'USD' etc = user picked a currency
                  if (result == null) return; // back pressed, no change
                  final newCurrency = result.isEmpty ? null : result;
                  if (passedWallet != null &&
                      passedWallet!.currency != newCurrency &&
                      mounted) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text("Change Currency".i18n),
                        content: Text(
                            "Changing the currency does not convert existing record amounts. Are you sure?"
                                .i18n),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text("Cancel".i18n),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text("Change".i18n),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                  }
                  setState(() => _selectedCurrency = newCurrency);
                },
        ),
      ],
    );
  }

  AppBar _getAppBar() {
    return AppBar(
      title:
          Text(passedWallet == null ? "New Wallet".i18n : "Edit Wallet".i18n),
      actions: [
        if (passedWallet != null)
          IconButton(
            icon: passedWallet!.isArchived
                ? const Icon(Icons.unarchive)
                : const Icon(Icons.archive),
            tooltip:
                passedWallet!.isArchived ? "Unarchive".i18n : "Archive".i18n,
            onPressed: () async {
              bool isCurrentlyArchived = passedWallet!.isArchived;
              String message = isCurrentlyArchived
                  ? "Do you really want to unarchive this wallet?".i18n
                  : "Do you really want to archive this wallet?".i18n;

              AlertDialogBuilder dialog = AlertDialogBuilder(message)
                  .addTrueButtonName("Yes".i18n)
                  .addFalseButtonName("No".i18n);

              var confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => dialog.build(ctx),
              );

              if (confirmed == true) {
                await database.archiveWallet(
                    passedWallet!.id!, !isCurrentlyArchived);
                Navigator.of(context).pop();
              }
            },
          ),
        if (passedWallet != null && !passedWallet!.isDefault)
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0))),
            onSelected: (index) async {
              if (index == 1) {
                await _showDeleteDialog();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<int>(
                padding: EdgeInsets.all(20),
                value: 1,
                child: Text("Delete".i18n, style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _showDeleteDialog() async {
    final choice = await showDialog<_WalletDeletionChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Wallet".i18n),
        content: Text(
            "What should happen to the records in this wallet? Transfer records involving this wallet will always be deleted."
                .i18n),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true)
                .pop(_WalletDeletionChoice.deleteAll),
            child: Text("Delete all records".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true)
                .pop(_WalletDeletionChoice.moveToWallet),
            child: Text("Move records to another wallet".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true)
                .pop(_WalletDeletionChoice.keepInDefault),
            child: Text("Keep records in default wallet".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(null),
            child: Text("Cancel".i18n),
          ),
        ],
      ),
    );

    if (choice == null) return;

    _logger.info('Deleting wallet "${passedWallet!.name}" (ID ${passedWallet!.id}), choice: ${choice.name}');

    if (choice == _WalletDeletionChoice.moveToWallet) {
      final targetWallet = await Navigator.push<Wallet>(
        context,
        MaterialPageRoute(
          builder: (_) => WalletPickerPage(excludeWalletId: passedWallet!.id),
        ),
      );
      if (targetWallet == null || !mounted) return;
      _logger.debug('Moving records to wallet "${targetWallet.name}" (ID ${targetWallet.id})');
      await database.moveRecordsToWallet(passedWallet!.id!, targetWallet.id!);
    } else if (choice == _WalletDeletionChoice.keepInDefault) {
      final defaultWallet = await database.getDefaultWallet();
      if (!mounted) return;
      _logger.debug('Moving records to default wallet (ID ${defaultWallet!.id})');
      await database.moveRecordsToWallet(passedWallet!.id!, defaultWallet.id!);
    }

    await database.deleteWalletAndRecords(passedWallet!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    wallet.name = walletName!;
    wallet.currency = _selectedCurrency;

    // Calculate initial_amount from the entered balance
    final enteredBalanceText = _balanceController.text;
    final enteredBalance = tryParseSignedCurrencyString(enteredBalanceText) ??
        double.tryParse(enteredBalanceText) ??
        0.0;

    // initial_amount = entered_balance - sum_of_records
    // sum_of_records = wallet.balance - wallet.initialAmount
    final sumOfRecords =
        (wallet.balance ?? wallet.initialAmount) - wallet.initialAmount;
    wallet.initialAmount = enteredBalance - sumOfRecords;

    if (passedWallet == null) {
      _logger.info('Creating new wallet "${wallet.name}" (currency: ${wallet.currency ?? 'none'}, initialAmount: ${wallet.initialAmount})');
      await database.addWallet(wallet);
    } else {
      _logger.info('Updating wallet "${wallet.name}" (ID ${passedWallet!.id}, currency: ${wallet.currency ?? 'none'}, initialAmount: ${wallet.initialAmount})');
      await database.updateWallet(passedWallet!.id!, wallet);
    }

    await _checkMixedCurrencyPrompt();

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _checkMixedCurrencyPrompt() async {
    if (!mounted) return;
    if (wallet.currency == null || wallet.currency!.isEmpty) return;

    // Cheap check first — skip DB query if default is already configured
    final defaultCurrency = ServiceConfig.sharedPreferences!
        .getString(PreferencesKeys.defaultCurrency);
    if (defaultCurrency != null && defaultCurrency.isNotEmpty) return;

    final allWallets = await database.getAllWallets();
    if (!mounted) return;

    final activeCurrencies = allWallets
        .where((w) =>
            !w.isArchived && w.currency != null && w.currency!.isNotEmpty)
        .map((w) => w.currency!)
        .toSet();

    if (activeCurrencies.length <= 1) return;

    // Capture messenger before pop — ScaffoldMessenger persists above the navigator
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            "You have wallets with different currencies. Set up conversion rates."
                .i18n),
        action: SnackBarAction(
          label: "Set up".i18n,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CurrenciesPage()),
            );
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Name + preview
              _getPageSeparatorLabel("Name".i18n),
              Divider(thickness: 0.5),
              Row(
                children: [
                  _getWalletCirclePreview(),
                  _getNameField(),
                ],
              ),
              // Balance
              _getPageSeparatorLabel("Balance".i18n),
              Divider(thickness: 0.5),
              _getBalanceField(),
              // Currency
              _getCurrencySection(),
              // Color + Icon (shared component, sections are collapsible internally)
              IconColorPickerSection(
                initialIconEmoji: wallet.iconEmoji,
                initialIcon: wallet.icon,
                initialColor: wallet.color,
                colors: Wallet.colors,
                onChange: (iconEmoji, icon, iconCodePoint, color) {
                  setState(() {
                    wallet.iconEmoji = iconEmoji;
                    wallet.icon = icon;
                    wallet.iconCodePoint = iconCodePoint;
                    wallet.color = color;
                  });
                },
              ),
              SizedBox(height: 75),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveWallet,
        tooltip: "Save".i18n,
        child: const Icon(Icons.save),
      ),
    );
  }
}
