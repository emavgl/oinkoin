import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/wallets/edit-wallet-page.dart';
import 'package:piggybank/wallets/wallet-picker-page.dart';
import 'package:piggybank/wallets/wallet-sort-option.dart';
import 'package:piggybank/wallets/wallets-list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletsTabPage extends StatefulWidget {
  WalletsTabPage({Key? key}) : super(key: key);

  @override
  WalletsTabPageState createState() => WalletsTabPageState();
}

class WalletsTabPageState extends State<WalletsTabPage> {
  DatabaseInterface database = ServiceConfig.database;
  List<Wallet>? _wallets;
  List<Wallet> _selectedWallets = [];
  bool _walletPrefsLoaded = false;
  int? _walletPrefsProfileId;
  bool _showArchived = false;
  bool _showBreakdown = false;

  WalletSortOption _selectedSortOption = WalletSortOption.original;
  WalletSortOption _storedDefaultOption = WalletSortOption.original;
  bool _isDefaultOrder = false;

  // When true the user is in drag-to-reorder mode; drag handles and OK button are visible.
  bool _inCustomOrderMode = false;
  // Holds the pending reordered list while the user drags (before pressing OK).
  List<Wallet>? _pendingOrderWallets;

  @override
  void initState() {
    super.initState();
    _loadWallets().then((_) => _initializeSortPreference());
  }

  Future<void> _initializeSortPreference() async {
    final key = PreferencesKeys.walletListSortOption;
    if (ServiceConfig.sharedPreferences!.containsKey(key)) {
      final savedIndex = ServiceConfig.sharedPreferences?.getInt(key);
      if (savedIndex != null && savedIndex < WalletSortOption.values.length) {
        setState(() {
          _storedDefaultOption = WalletSortOption.values[savedIndex];
          _selectedSortOption = WalletSortOption.values[savedIndex];
        });
      }
    }
  }

  Future<void> _storeOnUserPreferences() async {
    if (_isDefaultOrder) {
      await ServiceConfig.sharedPreferences
          ?.setInt(PreferencesKeys.walletListSortOption, _selectedSortOption.index);
      setState(() {
        _storedDefaultOption = _selectedSortOption;
      });
    }
    _isDefaultOrder = false;
  }

  Future<void> _loadWallets() async {
    final wallets = await database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    final allNonArchived = wallets.where((w) => !w.isArchived).toList();

    List<Wallet> updatedSelection = _selectedWallets;
    if (_selectedWallets.isNotEmpty) {
      // Re-sync so balances stay fresh after external edits
      final selectedIds = _selectedWallets.map((w) => w.id).toSet();
      updatedSelection =
          allNonArchived.where((w) => selectedIds.contains(w.id)).toList();
    } else if (!_walletPrefsLoaded ||
        _walletPrefsProfileId != ProfileService.instance.activeProfileId) {
      // First load, or profile switched: restore saved selection for this profile
      _walletPrefsLoaded = true;
      _walletPrefsProfileId = ProfileService.instance.activeProfileId;
      updatedSelection = [];
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(
              PreferencesKeys.walletsTabWalletFilter(
                  ProfileService.instance.activeProfileId!)) ??
          [];
      if (savedIds.isNotEmpty) {
        final idSet = savedIds.map(int.tryParse).toSet();
        updatedSelection =
            allNonArchived.where((w) => idSet.contains(w.id)).toList();
      }
    }

    setState(() {
      _wallets = wallets;
      _selectedWallets = updatedSelection;
      // Exit custom order mode on reload
      _inCustomOrderMode = false;
      _pendingOrderWallets = null;
    });
  }

  Future<void> onTabChange() async {
    await _loadWallets();
  }

  /// Confirm the pending drag order and persist it to the database.
  Future<void> _confirmCustomOrder() async {
    final ordered = _pendingOrderWallets ?? _walletsByArchiveStatusSorted;
    // Only persist the non-archived wallets order; archived stay unchanged.
    await database.resetWalletOrderIndexes(ordered);
    setState(() {
      _inCustomOrderMode = false;
      _pendingOrderWallets = null;
    });
    await _loadWallets();
  }

  void _showSortOptions() {
    WalletSortOption pendingOption = _selectedSortOption;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, top: 16, right: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order by".i18n,
                        style: const TextStyle(fontSize: 22),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _isDefaultOrder ||
                                pendingOption == _storedDefaultOption,
                            onChanged: (value) {
                              setModalState(() {
                                _isDefaultOrder = value ?? false;
                              });
                            },
                          ),
                          Text("Make it default".i18n),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reorder),
                  title: Text(
                    "Custom order".i18n,
                    style: TextStyle(
                      color: pendingOption == WalletSortOption.original
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == WalletSortOption.original
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = WalletSortOption.original;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.abc),
                  title: Text(
                    "Name (Alphabetically)".i18n,
                    style: TextStyle(
                      color: pendingOption == WalletSortOption.byName
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == WalletSortOption.byName
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = WalletSortOption.byName;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward),
                  title: Text(
                    "Amount (Ascending)".i18n,
                    style: TextStyle(
                      color: pendingOption == WalletSortOption.byAmountAsc
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == WalletSortOption.byAmountAsc
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = WalletSortOption.byAmountAsc;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_downward),
                  title: Text(
                    "Amount (Descending)".i18n,
                    style: TextStyle(
                      color: pendingOption == WalletSortOption.byAmountDesc
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == WalletSortOption.byAmountDesc
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = WalletSortOption.byAmountDesc;
                    });
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedSortOption = pendingOption;
                          _inCustomOrderMode =
                              pendingOption == WalletSortOption.original;
                          _pendingOrderWallets = null;
                        });
                        _storeOnUserPreferences();
                        Navigator.pop(context);
                      },
                      child: Text("Apply".i18n),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The wallets used for balance/summary calculations.
  /// Returns the user's filter selection when active; otherwise all non-archived wallets.
  List<Wallet> get _displayWallets {
    if (_wallets == null) return [];
    if (_selectedWallets.isNotEmpty) return _selectedWallets;
    return _wallets!.where((w) => !w.isArchived).toList();
  }

  String _displayBalanceString() {
    return computeCombinedBalanceString(_displayWallets);
  }

  bool get _canShowBreakdown {
    if (_displayWallets.isEmpty) return false;
    final defaultCurrency = getDefaultCurrency();
    if (defaultCurrency == null || defaultCurrency.isEmpty) return false;
    final currencies = _displayWallets
        .map((w) => w.currency)
        .where((c) => c != null && c.isNotEmpty)
        .toSet();
    if (currencies.length > 1) return true;
    if (currencies.length == 1 && currencies.first != defaultCurrency)
      return true;
    final hasNoCurrency =
        _displayWallets.any((w) => w.currency == null || w.currency!.isEmpty);
    final hasExplicitCurrency = currencies.isNotEmpty;
    return hasNoCurrency && hasExplicitCurrency;
  }

  Widget _buildBreakdown() {
    final Map<String, double> groupTotals = {};
    double noCurrencyTotal = 0.0;
    for (final wallet in _displayWallets) {
      final balance = wallet.balance ?? 0.0;
      final currency = wallet.currency;
      if (currency == null || currency.isEmpty) {
        noCurrencyTotal += balance;
      } else {
        groupTotals[currency] = (groupTotals[currency] ?? 0.0) + balance;
      }
    }

    final entries = groupTotals.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final breakdownItems = <MapEntry<String, double>>[
      if (noCurrencyTotal != 0.0) MapEntry('', noCurrencyTotal),
      ...entries,
    ];

    final defaultCurrency = getDefaultCurrency();
    final conversionResult = computeCombinedBalanceResult(_displayWallets);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in breakdownItems) ...[
          if (item != breakdownItems.first) const SizedBox(height: 2),
          Text(
            item.key.isEmpty ? "No currency".i18n : item.key,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          Text(
            item.key.isEmpty
                ? getCurrencyValueString(item.value)
                : formatCurrencyAmount(item.value, item.key),
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
        if (defaultCurrency != null &&
            conversionResult.currency != null &&
            conversionResult.currency != '' &&
            conversionResult.currency != breakdownItems.first.key) ...[
          const SizedBox(height: 8),
          const Divider(thickness: 0.5),
          const SizedBox(height: 4),
          Text(
            "Total in $defaultCurrency".i18n,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          Text(
            formatCurrencyAmount(conversionResult.total, defaultCurrency),
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  String get _headerLabel {
    if (_selectedWallets.isEmpty) return "All accounts".i18n;
    if (_selectedWallets.length == 1) return _selectedWallets.first.name;
    return "%s Wallets".i18n.fill([_selectedWallets.length.toString()]);
  }

  Future<void> _clearWalletFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PreferencesKeys.walletsTabWalletFilter(
        ProfileService.instance.activeProfileId!));
    setState(() {
      _selectedWallets = [];
    });
  }

  Future<void> _navigateToWalletPicker() async {
    final allNonArchived = _wallets!.where((w) => !w.isArchived).toList();
    final result = await Navigator.push<List<Wallet>>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPickerPage(
          multiSelect: true,
          initiallySelected: _selectedWallets,
          preferencesKey: PreferencesKeys.walletsTabWalletFilter(
              ProfileService.instance.activeProfileId!),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedWallets = result.length == allNonArchived.length ? [] : result;
      });
    }
  }

  /// Wallets filtered by archive status (and active wallet filter) and sorted by the selected sort option.
  List<Wallet> get _walletsByArchiveStatusSorted {
    if (_wallets == null) return [];
    var filtered = _wallets!.where((w) => w.isArchived == _showArchived).toList();
    if (!_showArchived && _selectedWallets.isNotEmpty) {
      final selectedIds = _selectedWallets.map((w) => w.id).toSet();
      filtered = filtered.where((w) => selectedIds.contains(w.id)).toList();
    }
    switch (_selectedSortOption) {
      case WalletSortOption.byName:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case WalletSortOption.byAmountAsc:
        filtered.sort(
            (a, b) => (a.balance ?? 0.0).compareTo(b.balance ?? 0.0));
        break;
      case WalletSortOption.byAmountDesc:
        filtered.sort(
            (a, b) => (b.balance ?? 0.0).compareTo(a.balance ?? 0.0));
        break;
      case WalletSortOption.original:
        // already ordered by sort_order from the DB query
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? "Archived wallets".i18n : "Wallets".i18n),
        leading: _showArchived
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showArchived = false),
              )
            : _inCustomOrderMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _inCustomOrderMode = false;
                      _pendingOrderWallets = null;
                    }),
                  )
                : null,
        automaticallyImplyLeading: false,
        actions: [
          if (_inCustomOrderMode)
            TextButton(
              onPressed: _confirmCustomOrder,
              child: Text(
                "OK".i18n,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          else ...[
            if (!_showArchived)
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: _showSortOptions,
              ),
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              onSelected: (value) {
                if (value == 1) {
                  setState(() => _showArchived = !_showArchived);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<int>(
                  padding: const EdgeInsets.all(20),
                  value: 1,
                  child: Text(
                    _showArchived
                        ? "Show active wallets".i18n
                        : "Show archived wallets".i18n,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _wallets == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_showArchived) ...[
                    // Total balance header (hidden in archived view)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _navigateToWalletPicker,
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _headerLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _canShowBreakdown
                                ? () => setState(
                                    () => _showBreakdown = !_showBreakdown)
                                : null,
                            child: _showBreakdown && _canShowBreakdown
                                ? _buildBreakdown()
                                : Text(
                                    _displayBalanceString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 0.5),
                  ],
                  WalletsList(
                    _walletsByArchiveStatusSorted,
                    onChanged: _loadWallets,
                    enableManualSorting: _inCustomOrderMode,
                    onReorderPending: (wallets) {
                      _pendingOrderWallets = wallets;
                    },
                  ),
                  if (!_showArchived && _selectedWallets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextButton(
                        onPressed: _clearWalletFilter,
                        child: Text("Show all wallets".i18n),
                      ),
                    ),
                  const SizedBox(height: 75),
                ],
              ),
            ),
      floatingActionButton: (_showArchived || _inCustomOrderMode)
          ? null
          : Stack(
              children: [
                FloatingActionButton(
                  onPressed: ServiceConfig.isPremium
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    EditWalletPage(passedWallet: null)),
                          );
                          await _loadWallets();
                        }
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PremiumSplashScreen()),
                          );
                        },
                  tooltip: "Add wallet".i18n,
                  child: const Icon(Icons.add),
                ),
                if (!ServiceConfig.isPremium)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PremiumSplashScreen()),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                        child: getProLabel(labelFontSize: 10.0),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
