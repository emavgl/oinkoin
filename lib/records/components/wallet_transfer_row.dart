import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/components/wallet_icon_square.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/wallets/wallet-picker-page.dart';

/// Displays source wallet and optional transfer destination in a single row.
/// When [showTransferSide] is true, shows both source and destination with an
/// arrow between them (expense + more than one wallet).
class WalletTransferRow extends StatelessWidget {
  final Wallet? selectedWallet;
  final Wallet? selectedDestinationWallet;
  final bool showTransferSide;
  final bool readOnly;
  final AutoSizeGroup walletNameSizeGroup;
  final ValueChanged<Wallet?> onSourceChanged;
  final ValueChanged<Wallet?> onDestinationChanged;

  const WalletTransferRow({
    Key? key,
    required this.selectedWallet,
    required this.selectedDestinationWallet,
    required this.showTransferSide,
    required this.readOnly,
    required this.walletNameSizeGroup,
    required this.onSourceChanged,
    required this.onDestinationChanged,
  }) : super(key: key);

  Future<void> _pickSourceWallet(BuildContext context) async {
    if (readOnly) return;
    final selected = await Navigator.push<Wallet>(
      context,
      MaterialPageRoute(builder: (_) => WalletPickerPage()),
    );
    if (selected != null) {
      onSourceChanged(selected);
    }
  }

  Future<void> _pickDestinationWallet(BuildContext context) async {
    if (readOnly) return;
    final selected = await Navigator.push<Wallet>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPickerPage(excludeWalletId: selectedWallet?.id),
      ),
    );
    if (selected != null) {
      onDestinationChanged(selected);
    }
  }

  Widget _buildSourceWidget(BuildContext context) {
    return InkWell(
      onTap: () => _pickSourceWallet(context),
      child: Semantics(
        identifier: 'wallet-field',
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            selectedWallet != null
                ? WalletIconSquare(
                    iconEmoji: selectedWallet!.iconEmoji,
                    iconDataFromDefaultIconSet: selectedWallet!.icon,
                    backgroundColor: selectedWallet!.color,
                    size: 40,
                  )
                : Icon(Icons.account_balance_wallet_outlined, size: 40),
            Flexible(
              child: Container(
                margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                child: AutoSizeText(
                  formatWalletDisplay(selectedWallet,
                      emptyLabel: "Select wallet".i18n),
                  style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  minFontSize: 10,
                  group: walletNameSizeGroup,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationWidget(BuildContext context) {
    return InkWell(
      onTap: () => _pickDestinationWallet(context),
      onLongPress: readOnly ? null : () => onDestinationChanged(null),
      child: Semantics(
        identifier: 'destination-wallet-field',
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (selectedDestinationWallet != null)
              WalletIconSquare(
                iconEmoji: selectedDestinationWallet!.iconEmoji,
                iconDataFromDefaultIconSet: selectedDestinationWallet!.icon,
                backgroundColor: selectedDestinationWallet!.color,
              ),
            Flexible(
              child: Container(
                margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      formatWalletDisplay(selectedDestinationWallet,
                          emptyLabel: "No transfer".i18n),
                      style: TextStyle(
                          fontSize: 18,
                          color: selectedDestinationWallet != null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4)),
                      maxLines: 2,
                      minFontSize: 10,
                      group: walletNameSizeGroup,
                    ),
                    if (selectedDestinationWallet?.isArchived == true)
                      Text(
                        "Archived".i18n,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _buildSourceWidget(context);

    if (!showTransferSide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: source,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: source),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: _buildDestinationWidget(context)),
        ],
      ),
    );
  }
}
