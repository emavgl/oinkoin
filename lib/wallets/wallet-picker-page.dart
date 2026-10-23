import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  /// When provided, wallet balances shown are a point-in-time snapshot as of
  /// this date (inclusive) instead of the live balance, and a banner informs
  /// the user of this.
  final DateTime? asOfDate;

  /// Always lists hidden wallets instead of requiring "Show hidden wallets".
  /// Used by transfer flows, where hidden wallets stay usable as origin or
  /// destination because moving money between own wallets is not spending.
  final bool showHiddenWallets;

  WalletPickerPage({
    this.excludeWalletId,
    this.multiSelect = false,
    this.initiallySelected = const [],
    this.preferencesKey,
    this.asOfDate,
    this.showHiddenWallets = false,
  });

  @override
  _WalletPickerPageState createState() => _WalletPickerPageState();
}

class _WalletPickerPageState extends State<WalletPickerPage> {
  DatabaseInterface database = ServiceConfig.database;
  List<Wallet>? _wallets;
  late Set<int?> _selectedIds;
  bool _saveAsDefault = false;
  bool _showHidden = false;

  /// Wallets actually listed: hidden ones are shown only when revealed, or
  /// when they were already selected (so a saved selection never vanishes).
  List<Wallet> get _visibleWallets => (_wallets ?? [])
      .where((w) =>
          !w.isHidden ||
          widget.showHiddenWallets ||
          _showHidden ||
          _selectedIds.contains(w.id))
      .toList();

  bool get _hasHiddenWallets =>
      _wallets?.any((w) => w.isHidden) ?? false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelected.map((w) => w.id).toSet();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = widget.asOfDate != null
        ? await database.getWalletsBalanceAsOf(widget.asOfDate!,
            profileId: ProfileService.instance.activeProfileId)
        : await database.getAllWallets(
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
    final visible = _visibleWallets;
    setState(() {
      if (visible.every((w) => _selectedIds.contains(w.id))) {
        _selectedIds.removeAll(visible.map((w) => w.id));
      } else {
        _selectedIds.addAll(visible.map((w) => w.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleWallets = _visibleWallets;
    final allSelected = _wallets != null &&
        visibleWallets.isNotEmpty &&
        visibleWallets.every((w) => _selectedIds.contains(w.id));

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text("Select Wallet".i18n),
        actions: [
          if (_hasHiddenWallets && !widget.showHiddenWallets)
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              onSelected: (value) {
                if (value == 1) {
                  setState(() => _showHidden = !_showHidden);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<int>(
                  padding: const EdgeInsets.all(20),
                  value: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Show hidden wallets".i18n,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (_showHidden) const Icon(Icons.check, size: 20),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _wallets == null
          ? Center(child: CircularProgressIndicator())
          : visibleWallets.isEmpty
              ? Center(child: Text("No wallets available".i18n))
              : Column(
                  children: [
                    if (widget.asOfDate != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(
                          "Balance as of %s"
                              .i18n
                              .fill([DateFormat.yMMMd().format(widget.asOfDate!)]),
                          style: const TextStyle(
                              fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),
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
                        itemCount: visibleWallets.length,
                        itemBuilder: (context, i) {
                          final wallet = visibleWallets[i];
                          final isSelected = _selectedIds.contains(wallet.id);

                          if (widget.multiSelect) {
                            return Opacity(
                              opacity: wallet.isHidden ? 0.6 : 1.0,
                              child: ListTile(
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
                              ),
                            );
                          }

                          return Opacity(
                            opacity: wallet.isHidden ? 0.6 : 1.0,
                            child: ListTile(
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
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: widget.multiSelect
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.preferencesKey != null) ...[
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
                          horizontal: 20, vertical: 4),
                    ),
                    const Divider(height: 1),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmSelection,
                        child: Text("Apply".i18n),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );

    return scaffold;
  }
}
