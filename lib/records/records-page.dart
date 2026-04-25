import 'dart:core';

import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/logger.dart';

import '../models/wallet.dart';
import '../profiles/profiles-page.dart';
import '../services/profile-service.dart';
import '../services/service-config.dart';
import 'components/days-summary-box-card.dart';
import 'components/records-day-list.dart';
import 'components/tab_records_app_bar.dart';
import 'components/tab_records_date_picker.dart';
import 'components/tab_records_search_app_bar.dart';
import 'components/tab_records_selection_app_bar.dart';
import 'controllers/tab_records_controller.dart';

class TabRecords extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  TabRecords({Key? key}) : super(key: key);

  @override
  TabRecordsState createState() => TabRecordsState();
}

class TabRecordsState extends State<TabRecords> {
  static final _logger = Logger.withContext('TabRecords');

  late final TabRecordsController _controller;
  late final AppLifecycleListener _listener;
  bool _isAppBarExpanded = true;
  bool _isSelectMode = false;
  Set<int> _selectedRecordIds = {};

  @override
  void initState() {
    super.initState();
    _controller = TabRecordsController(
      onStateChanged: () => setState(() {}),
    );

    _listener = AppLifecycleListener(
      onStateChange: _handleOnResume,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize();
    });
  }

  void _handleOnResume(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) {
      _controller.onResume();
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.runAutomaticBackup(context);
  }

  void _enterSelectMode(int id) {
    _logger.debug('Entering select mode, initial record ID: $id');
    setState(() {
      _isSelectMode = true;
      _selectedRecordIds = {id};
    });
  }

  void _exitSelectMode() {
    _logger.debug('Exiting select mode (${_selectedRecordIds.length} records were selected)');
    setState(() {
      _isSelectMode = false;
      _selectedRecordIds = {};
    });
  }

  void _toggleRecord(int id) {
    setState(() {
      if (_selectedRecordIds.contains(id)) {
        _selectedRecordIds.remove(id);
      } else {
        _selectedRecordIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedRecordIds = _controller.filteredRecords
          .where((r) => r?.id != null)
          .map((r) => r!.id!)
          .toSet();
    });
  }

  Future<void> _batchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Delete records?".i18n),
        content: Text(
            "Are you sure you want to delete %s record(s)?".i18n.fill([_selectedRecordIds.length.toString()])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Delete".i18n),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Copy IDs before async operations
    final idsToDelete = List<int>.from(_selectedRecordIds);
    _logger.info('Batch deleting ${idsToDelete.length} records: $idsToDelete');

    // Exit select mode immediately
    if (mounted) {
      _exitSelectMode();
    }

    // Batch delete in database
    try {
      await ServiceConfig.database.deleteRecordsInBatch(idsToDelete);
      // Refresh list after deletion complete
      if (mounted) {
        await _controller.updateRecurrentRecordsAndFetchRecords();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, st) {
      _logger.handle(e, st, 'Error during batch delete');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting records: $e')),
        );
      }
    }
  }

  Future<void> _batchDuplicate() async {
    // Copy IDs before async operations
    final idsToDuplicate = List<int>.from(_selectedRecordIds);
    _logger.info('Batch duplicating ${idsToDuplicate.length} records: $idsToDuplicate');

    // Exit select mode immediately
    if (mounted) {
      _exitSelectMode();
    }

    try {
      // Batch duplicate in database
      await ServiceConfig.database.duplicateRecordsInBatch(idsToDuplicate);
      // Refresh list after duplication complete
      if (mounted) {
        await _controller.updateRecurrentRecordsAndFetchRecords();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, st) {
      _logger.handle(e, st, 'Error during batch duplicate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating records: $e')),
        );
      }
    }
  }

  Future<void> _batchMoveToWallet() async {
    final wallets = await ServiceConfig.database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    if (!mounted) return;
    final chosenWallet = await showDialog<Wallet>(
      context: context,
      builder: (_) => _WalletPickerDialog(wallets: wallets),
    );
    if (chosenWallet == null) return;

    // Copy IDs before async operations
    final idsToMove = List<int>.from(_selectedRecordIds);
    _logger.info('Batch moving ${idsToMove.length} records to wallet "${chosenWallet.name}" (ID ${chosenWallet.id})');

    // Exit select mode immediately
    if (mounted) {
      _exitSelectMode();
    }

    try {
      // Batch update wallet IDs (skips transfers with filter in DB)
      await ServiceConfig.database.updateRecordWalletInBatch(
          idsToMove, chosenWallet.id);
      // Refresh list after all updates complete
      if (mounted) {
        await _controller.updateRecurrentRecordsAndFetchRecords();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, st) {
      _logger.handle(e, st, 'Error during batch move to wallet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving records: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      appBar: _buildAppBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    return GestureDetector(
      onHorizontalDragEnd: (DragEndDetails details) {
        // Swipe left to right (positive velocity) = shift back (-1)
        // Swipe right to left (negative velocity) = shift forward (+1)
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 500) {
            // Swiped left to right - go back
            if (_controller.canShiftBack()) {
              _controller.shiftInterval(-1);
            }
          } else if (details.primaryVelocity! < -500) {
            // Swiped right to left - go forward
            if (_controller.canShiftForward()) {
              _controller.shiftInterval(1);
            }
          }
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: NotificationListener<ScrollNotification>(
          key: ValueKey(_controller.header),
          onNotification: (scrollInfo) {
            final isExpanded = scrollInfo.metrics.pixels < 100;
            if (_isAppBarExpanded != isExpanded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isAppBarExpanded = isExpanded;
                  });
                }
              });
            }
            return true;
          },
          child: CustomScrollView(
            slivers: _buildSlivers(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    return <Widget>[
      if (!_controller.isSearchingEnabled)
        _buildMainSliverAppBar(),
      _buildSummarySection(),
      if (_controller.filteredRecords.isEmpty) _buildEmptyState(),
      RecordsDayList(
        _controller.filteredRecords,
        onListBackCallback: _controller.updateRecurrentRecordsAndFetchRecords,
        walletCurrencyMap: _controller.walletCurrencyMap,
        isSelectMode: _isSelectMode,
        selectedRecordIds: _selectedRecordIds,
        onRecordLongPressed: _enterSelectMode,
        onRecordTapped: _toggleRecord,
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 75),
      ),
    ];
  }

  Widget _buildMainSliverAppBar() {
    return TabRecordsAppBar(
      controller: _controller,
      isAppBarExpanded: _isAppBarExpanded,
      profileName: _controller.activeProfileName,
      onProfileTapped: () => _navigateToProfilesPage(),
      onDatePickerPressed: () => _showDatePicker(),
      onStatisticsPressed: () => _controller.navigateToStatisticsPage(context),
      onSearchPressed: () => _controller.startSearch(),
      onMenuItemSelected: (index) =>
          _controller.handleMenuAction(context, index),
      isSelectMode: _isSelectMode,
      selectedCount: _selectedRecordIds.length,
      onClose: _exitSelectMode,
      onDelete: _batchDelete,
      onSelectAll: _selectAll,
      onDuplicate: _batchDuplicate,
      onMoveToWallet: ServiceConfig.isPremium ? _batchMoveToWallet : null,
    );
  }

  Future<void> _navigateToProfilesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilesPage()),
    );
    // On return, refresh data for the (possibly new) active profile
    await _controller.reloadProfileName();
    await _controller.updateRecurrentRecordsAndFetchRecords();
    await _controller.onTabChange();
    setState(() {});
  }

  PreferredSizeWidget? _buildAppBar() {
    if (!_controller.isSearchingEnabled) return null;

    if (_isSelectMode) {
      return TabRecordsSelectionAppBar(
        selectedCount: _selectedRecordIds.length,
        onClose: _exitSelectMode,
        onDelete: _batchDelete,
        onSelectAll: _selectAll,
        onDuplicate: _batchDuplicate,
        onMoveToWallet: ServiceConfig.isPremium ? _batchMoveToWallet : null,
      );
    }

    return TabRecordsSearchAppBar(
      controller: _controller,
      onBackPressed: () => _controller.stopSearch(),
      onDatePickerPressed: () => _showDatePicker(),
      onStatisticsPressed: () => _controller.navigateToStatisticsPage(context),
      onMenuItemSelected: (index) =>
          _controller.handleMenuAction(context, index),
      onFilterPressed: () => _controller.showFilterModal(context),
      hasActiveFilters: _controller.hasActiveFilters,
    );
  }

  Widget _buildSummarySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        height: 130,
        child: DaysSummaryBox(
          _controller.overviewRecords ?? _controller.filteredRecords,
          walletLabel: _controller.walletRowLabel,
          walletBalanceString: _controller.selectedWalletsBalanceString,
          walletCurrencyMap: _controller.walletCurrencyMap,
          onWalletRowTap: () => _controller.navigateToWalletPicker(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Image.asset('assets/images/no_entry.png', width: 200),
          const SizedBox(height: 10),
          Text(
            "No entries yet.".i18n,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _controller.navigateToAddNewRecord(context),
      tooltip: 'Add a new record'.i18n,
      child: Semantics(
        identifier: 'add-record',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    await showDialog(
      context: context,
      builder: (context) => TabRecordsDatePicker(
        controller: _controller,
        onDateSelected: () => setState(() {}),
      ),
    );
  }

  // Public method for external navigation callbacks
  onTabChange() async {
    await _controller.onTabChange();
  }
}

class _WalletPickerDialog extends StatelessWidget {
  final List<Wallet> wallets;

  const _WalletPickerDialog({required this.wallets});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Choose wallet'.i18n),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: wallets.length,
          itemBuilder: (context, index) {
            final wallet = wallets[index];
            return ListTile(
              title: Text(wallet.name),
              onTap: () => Navigator.pop(context, wallet),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.i18n),
        ),
      ],
    );
  }
}
