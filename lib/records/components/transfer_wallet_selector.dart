import 'package:flutter/material.dart';
import 'package:piggybank/components/markup_text.dart';
import 'package:piggybank/components/wallet_icon_square.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/wallets/wallet-sort-option.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Displays the localized instruction for the current transfer wallet step.
class TransferWalletInstruction extends StatelessWidget {
  final bool hasOrigin;

  const TransferWalletInstruction({
    Key? key,
    required this.hasOrigin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final instructionStyle = TextStyle(
      fontSize: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return hasOrigin
        ? MarkupText(
            "Select the <b>destination</b> wallet".i18n,
            style: instructionStyle,
          )
        : MarkupText(
            "Select the <b>origin</b> wallet".i18n,
            style: instructionStyle,
          );  }
}



/// Selects the two distinct wallets needed to create a transfer.
///
/// The origin remains in the list after it is selected and is disabled as a
/// destination. The component is deliberately independent from the category
/// picker so it can be reused by other transfer entry points.
class TransferWalletSelector extends StatefulWidget {
  final void Function(Wallet origin, Wallet destination) onContinue;

  const TransferWalletSelector({
    Key? key,
    required this.onContinue,
  }) : super(key: key);

  @override
  State<TransferWalletSelector> createState() => _TransferWalletSelectorState();
}

class _TransferWalletSelectorState extends State<TransferWalletSelector> {
  final DatabaseInterface _database = ServiceConfig.database;
  List<Wallet>? _wallets;
  Wallet? _origin;
  Wallet? _destination;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await _database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(PreferencesKeys.walletListSortOption);
    final sortOption = (savedIndex != null &&
            savedIndex < WalletSortOption.values.length)
        ? WalletSortOption.values[savedIndex]
        : WalletSortOption.original;

    final activeWallets =
        wallets.where((wallet) => !wallet.isArchived).toList();
    switch (sortOption) {
      case WalletSortOption.byName:
        activeWallets.sort((a, b) => a.name.compareTo(b.name));
        break;
      case WalletSortOption.byAmountAsc:
        activeWallets
            .sort((a, b) => (a.balance ?? 0.0).compareTo(b.balance ?? 0.0));
        break;
      case WalletSortOption.byAmountDesc:
        activeWallets
            .sort((a, b) => (b.balance ?? 0.0).compareTo(a.balance ?? 0.0));
        break;
      case WalletSortOption.original:
        break;
    }

    if (!mounted) return;
    setState(() {
      _wallets = activeWallets;
    });
  }

  void _selectWallet(Wallet wallet) {
    setState(() {
      if (_origin != null && wallet.id == _origin!.id) {
        // Tapping the selected origin starts the transfer selection over.
        _origin = null;
        _destination = null;
        return;
      }
      if (_origin == null) {
        _origin = wallet;
        return;
      }
      // The origin remains visible but cannot be selected as its own
      // destination. Tapping any other wallet selects/replaces the destination.
      _destination = wallet;
    });
  }

  bool _isWalletSelected(Wallet wallet) {
    return wallet.id == _origin?.id || wallet.id == _destination?.id;
  }

  Widget _buildSelectionSeparator({
    required Wallet? previousWallet,
    required Wallet? nextWallet,
  }) {
    final previousSelected =
        previousWallet != null && _isWalletSelected(previousWallet);
    final nextSelected = nextWallet != null && _isWalletSelected(nextWallet);
    final selectionColor = Theme.of(context).colorScheme.secondaryContainer;
    final dividerColor = Theme.of(context).dividerColor;

    return SizedBox(
      height: 16,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: previousSelected ? selectionColor : null,
            ),
          ),
          SizedBox(
            height: 0.5,
            child: Container(color: dividerColor),
          ),
          Expanded(
            child: Container(
              color: nextSelected ? selectionColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletRow(Wallet wallet) {
    final isOrigin = wallet.id == _origin?.id;
    final isDestination = wallet.id == _destination?.id;
    final isSelected = isOrigin || isDestination;
    final selectionColor = Theme.of(context).colorScheme.secondaryContainer;

    return ListTile(
      tileColor: isSelected ? selectionColor : null,
      leading: WalletIconSquare(
        iconEmoji: wallet.iconEmoji,
        iconDataFromDefaultIconSet: wallet.icon,
        backgroundColor: wallet.color,
        overlayIcon: isOrigin
            ? Icons.north_east
            : isDestination
                ? Icons.south_west
                : null,
      ),
      title: Text(wallet.name, style: const TextStyle(fontSize: 18)),
      trailing: _buildWalletBalanceWidget(wallet),
      onTap: () => _selectWallet(wallet),
    );
  }

  Widget _buildWalletBalanceWidget(Wallet wallet) {
    final balance = wallet.balance ?? 0.0;
    final walletCurrency = wallet.currency;
    final color = getAmountColor(balance, Theme.of(context).brightness);
    final style =
        TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal, color: color);

    if (walletCurrency == null || walletCurrency.isEmpty) {
      return Text(getCurrencyValueString(balance), style: style);
    }

    return buildAmountWithCurrencyWidget(wallet.balance ?? 0.0, walletCurrency,
        mainStyle: style,
        brightness: Theme.of(context).brightness);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _wallets;
    if (wallets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (wallets.isEmpty) {
      return Center(child: Text("No wallets available".i18n));
    }

    final canContinue = _origin != null && _destination != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TransferWalletInstruction(
                  hasOrigin: _origin != null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: wallets.length * 2,
            itemBuilder: (context, index) {
              if (index.isEven) {
                final separatorIndex = index ~/ 2;
                return _buildSelectionSeparator(
                  previousWallet: separatorIndex == 0
                      ? null
                      : wallets[separatorIndex - 1],
                  nextWallet: wallets[separatorIndex],
                );
              }

              return _buildWalletRow(wallets[index ~/ 2]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: canContinue
                    ? () => widget.onContinue(_origin!, _destination!)
                    : null,
                child: Text("Continue".i18n),
              ),
            ),
          ),        ),
      ],
    );
  }
}
