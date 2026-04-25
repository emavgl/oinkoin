import 'package:flutter/material.dart';
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

class WalletPickerPage extends StatefulWidget {
  /// A page for selecting a wallet. Returns the selected Wallet via Navigator.pop.
  /// Used both in EditRecordPage (to pick a wallet for a record) and
  /// in EditWalletPage (to pick a target wallet when deleting/moving records).
  ///
  /// When [multiSelect] is true, shows checkboxes and an OK button; pops with
  /// a List<Wallet> instead of a single Wallet.

  final int? excludeWalletId;
  final bool multiSelect;
  final List<Wallet> initiallySelected;

  /// When provided, shows a "Save as default" checkbox. On confirm, saves the
  /// selection under this key in SharedPreferences.
  final String? preferencesKey;

  WalletPickerPage({
    this.excludeWalletId,
    this.multiSelect = false,
    this.initiallySelected = const [],
    this.preferencesKey,
  });

  @override
  _WalletPickerPageState createState() => _WalletPickerPageState();
}

class _WalletPickerPageState extends State<WalletPickerPage> {
  DatabaseInterface database = ServiceConfig.database;
  List<Wallet>? _wallets;
  late Set<int?> _selectedIds;
  bool _saveAsDefault = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelected.map((w) => w.id).toSet();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(PreferencesKeys.walletListSortOption);
    final sortOption = (savedIndex != null &&
            savedIndex < WalletSortOption.values.length)
        ? WalletSortOption.values[savedIndex]
        : WalletSortOption.original;

    var filtered =
        wallets.where((w) => !w.isArchived && w.id != widget.excludeWalletId).toList();
    switch (sortOption) {
      case WalletSortOption.byName:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case WalletSortOption.byAmountAsc:
        filtered.sort((a, b) => (a.balance ?? 0.0).compareTo(b.balance ?? 0.0));
        break;
      case WalletSortOption.byAmountDesc:
        filtered.sort((a, b) => (b.balance ?? 0.0).compareTo(a.balance ?? 0.0));
        break;
      case WalletSortOption.original:
        break;
    }
    setState(() {
      _wallets = filtered;
    });
  }

  void _toggleSelection(Wallet wallet) {
    setState(() {
      if (_selectedIds.contains(wallet.id)) {
        _selectedIds.remove(wallet.id);
      } else {
        _selectedIds.add(wallet.id);
      }
    });
  }

  Future<void> _confirmSelection() async {
    final selected =
        _wallets!.where((w) => _selectedIds.contains(w.id)).toList();
    if (_saveAsDefault && widget.preferencesKey != null) {
      final prefs = await SharedPreferences.getInstance();
      final ids = selected.map((w) => w.id.toString()).toList();
      await prefs.setStringList(widget.preferencesKey!, ids);
    }
    if (mounted) Navigator.of(context).pop(selected);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _wallets!.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _wallets!.map((w) => w.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _wallets != null && _selectedIds.length == _wallets!.length;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text("Select Wallet".i18n),
      ),
      body: _wallets == null
          ? Center(child: CircularProgressIndicator())
          : _wallets!.isEmpty
              ? Center(child: Text("No wallets available".i18n))
              : Column(
                  children: [
                    if (widget.multiSelect)
                      ListTile(
                        title: Text(
                          allSelected ? "Deselect all".i18n : "Select all".i18n,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Checkbox(
                          value: allSelected,
                          onChanged: (_) => _toggleSelectAll(),
                        ),
                        onTap: _toggleSelectAll,
                      ),
                    if (widget.multiSelect) const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        separatorBuilder: (_, __) => Divider(thickness: 0.5),
                        itemCount: _wallets!.length,
                        itemBuilder: (context, i) {
                          final wallet = _wallets![i];
                          final isSelected = _selectedIds.contains(wallet.id);

                          if (widget.multiSelect) {
                            return ListTile(
                              leading: WalletIconSquare(
                                iconEmoji: wallet.iconEmoji,
                                iconDataFromDefaultIconSet: wallet.icon,
                                backgroundColor: wallet.color,
                              ),
                              title: Text(wallet.name,
                                  style: TextStyle(fontSize: 18)),
                              subtitle: wallet.balance != null
                                  ? Text(formatWalletBalance(wallet))
                                  : null,
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(wallet),
                              ),
                              onTap: () => _toggleSelection(wallet),
                            );
                          }

                          return ListTile(
                            leading: WalletIconSquare(
                              iconEmoji: wallet.iconEmoji,
                              iconDataFromDefaultIconSet: wallet.icon,
                              backgroundColor: wallet.color,
                            ),
                            title: Text(wallet.name,
                                style: TextStyle(fontSize: 18)),
                            subtitle: wallet.isPredefined
                                ? Text("Predefined".i18n)
                                : null,
                            trailing: wallet.balance != null
                                ? Text(
                                    formatWalletBalance(wallet),
                                    style: TextStyle(fontSize: 16),
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(wallet),
                          );
                        },
                      ),
                    ),
                    if (widget.multiSelect &&
                        widget.preferencesKey != null) ...[
                      const Divider(height: 1),
                      CheckboxListTile(
                        value: _saveAsDefault,
                        onChanged: (v) =>
                            setState(() => _saveAsDefault = v ?? false),
                        title: Text(
                          "Save as default selection".i18n,
                          style: const TextStyle(fontSize: 17),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                    ],
                  ],
                ),
    );

    if (!widget.multiSelect) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmSelection();
      },
      child: scaffold,
    );
  }
}
