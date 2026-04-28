import 'package:flutter/material.dart';
import 'package:piggybank/components/wallet_icon_square.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/wallets/edit-wallet-page.dart';

class WalletsList extends StatefulWidget {
  /// A list of wallets. When [enableManualSorting] is true, drag handles
  /// are shown and the user can reorder items. Each reorder fires
  /// [onReorderPending] with the updated list (not yet persisted).

  final List<Wallet> wallets;
  final void Function()? onChanged;
  final bool enableManualSorting;
  final void Function(List<Wallet>)? onReorderPending;

  WalletsList(
    this.wallets, {
    this.onChanged,
    this.enableManualSorting = false,
    this.onReorderPending,
  });

  @override
  _WalletsListState createState() => _WalletsListState();
}

class _WalletsListState extends State<WalletsList> {
  DatabaseInterface database = ServiceConfig.database;
  late List<Wallet> _wallets;

  @override
  void initState() {
    super.initState();
    _wallets = List.from(widget.wallets);
  }

  @override
  void didUpdateWidget(WalletsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallets != widget.wallets) {
      _wallets = List.from(widget.wallets);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = _wallets.removeAt(oldIndex);
    _wallets.insert(newIndex, moved);
    setState(() {});
    if (widget.onReorderPending != null) {
      widget.onReorderPending!(List.from(_wallets));
    }
  }

  Future<void> _setAsPredefined(Wallet wallet) async {
    await database.setPredefinedWallet(wallet.id!);
    if (widget.onChanged != null) widget.onChanged!();
  }

  void _showPredefinedSheet(Wallet wallet) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Icon(
                  wallet.isPredefined
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 28,
                ),
                title: Text(
                  wallet.isPredefined
                      ? "Already predefined for new records".i18n
                      : "Set as predefined for new records".i18n,
                  style: const TextStyle(fontSize: 17),
                ),
                subtitle: Text(
                  "This wallet will be pre-selected when adding new entries"
                      .i18n,
                  style: const TextStyle(fontSize: 13),
                ),
                enabled: !wallet.isPredefined,
                onTap: wallet.isPredefined
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _setAsPredefined(wallet);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(Wallet wallet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditWalletPage(passedWallet: wallet)),
    );
    if (widget.onChanged != null) widget.onChanged!();
  }

  Widget _buildWalletBalanceWidget(Wallet wallet) {
    final balance = wallet.balance ?? 0.0;
    final walletCurrency = wallet.currency;
    const style = TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal);

    if (walletCurrency == null || walletCurrency.isEmpty) {
      return Text(getCurrencyValueString(balance), style: style);
    }

    return buildAmountWithCurrencyWidget(balance, walletCurrency,
        mainStyle: style);
  }

  @override
  Widget build(BuildContext context) {
    if (_wallets.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Image.asset('assets/images/no_entry_2.png', width: 200),
          Text(
            "No wallets yet.".i18n,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22.0),
          ),
        ],
      );
    }

    final cs = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _wallets.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final wallet = _wallets[index];
        final isLast = index == _wallets.length - 1;

        return Column(
          key: ValueKey(wallet.id),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: widget.enableManualSorting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(Icons.drag_handle,
                              color: cs.onSurface.withValues(alpha: 0.35)),
                        ),
                        const SizedBox(width: 8),
                        WalletIconSquare(
                          iconEmoji: wallet.iconEmoji,
                          iconDataFromDefaultIconSet: wallet.icon,
                          backgroundColor: wallet.color,
                          overlayIcon: wallet.isDefault ? Icons.check : null,
                        ),
                      ],
                    )
                  : WalletIconSquare(
                      iconEmoji: wallet.iconEmoji,
                      iconDataFromDefaultIconSet: wallet.icon,
                      backgroundColor: wallet.color,
                      overlayIcon: wallet.isDefault ? Icons.check : null,
                    ),
              title: Text(wallet.name, style: const TextStyle(fontSize: 18)),
              trailing: _buildWalletBalanceWidget(wallet),
              onTap: () => _openEdit(wallet),
              onLongPress: () => _showPredefinedSheet(wallet),
            ),
            if (!isLast) const Divider(thickness: 0.5),
          ],
        );
      },
    );
  }
}
