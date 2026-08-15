import 'dart:async';

import 'package:flutter/material.dart';
import 'package:piggybank/components/amount_input_field.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/helpers/date_picker_utils.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/records/components/custom_interval_dialog.dart';
import 'package:piggybank/records/components/filter_modal_content.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/records/components/records-day-list.dart';
import 'package:piggybank/wallets/wallet-picker-page.dart';
import 'package:piggybank/statistics/statistics-page.dart';

List<Record> _matchingBudgetRecords(
  Budget budget,
  Iterable<Record> records,
  BudgetCycle cycle,
) {
  return records.where((record) {
    final recordDate = record.dateTime;
    final cycleEnd = DateTime(
      cycle.end.year,
      cycle.end.month,
      cycle.end.day,
      23,
      59,
      59,
    );
    final inCycle =
        !recordDate.isBefore(cycle.start) && !recordDate.isAfter(cycleEnd);
    final hasCategories = budget.categoryNames.isNotEmpty;
    final hasTags = budget.tags.isNotEmpty;
    final hasWallets =
        ServiceConfig.walletsEnabled && budget.walletIds.isNotEmpty;
    final matchesWallet =
        !hasWallets ||
        budget.walletIds.contains(record.walletId) ||
        (record.isTransfer &&
            budget.walletIds.contains(record.transferWalletId));
    if (!inCycle ||
        record.category?.categoryType != budget.recordCategoryType ||
        !matchesWallet) {
      return false;
    }
    final matchesCategories =
        !hasCategories || budget.categoryNames.contains(record.category?.name);
    final matchesTags =
        !hasTags ||
        (budget.tagOrLogic
            ? budget.tags.any(record.tags.contains)
            : budget.tags.every(record.tags.contains));

    if (hasCategories && hasTags) {
      return budget.categoryTagOrLogic
          ? matchesCategories || matchesTags
          : matchesCategories && matchesTags;
    }
    return matchesCategories && matchesTags;
  }).toList();
}

class _BudgetEmptyState extends StatefulWidget {
  final List<String> messages;

  const _BudgetEmptyState({required this.messages});

  @override
  State<_BudgetEmptyState> createState() => _BudgetEmptyStateState();
}

class _BudgetEmptyStateState extends State<_BudgetEmptyState> {
  static const _messageSlotHeight = 80.0;

  Timer? _timer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNextMessage();
  }

  void _scheduleNextMessage() {
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % widget.messages.length;
      });
      _scheduleNextMessage();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/no_entry.png', width: 200),
            const SizedBox(height: 12),
            SizedBox(
              height: _messageSlotHeight,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = animation.drive(
                        Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeOut)),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      widget.messages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  BudgetsPageState createState() => BudgetsPageState();
}

class BudgetsPageState extends State<BudgetsPage> {
  final DatabaseInterface _database = ServiceConfig.database;
  List<Budget> _budgets = [];
  List<Record> _records = [];
  bool _showArchived = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileId = ProfileService.instance.activeProfileId;
    final budgets = await _database.getBudgets(profileId: profileId);
    final records = (await _database.getAllRecords(profileId: profileId))
        .whereType<Record>()
        .toList();
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _records = records;
      _loading = false;
    });
  }

  Future<void> onTabChange() => _loadData();

  Future<void> _createBudget() async {
    final created = await Navigator.push<Budget>(
      context,
      MaterialPageRoute(builder: (_) => const CreateBudgetPage()),
    );
    if (created != null) await _loadData();
  }

  Future<void> _deleteBudget(Budget budget) async {
    if (budget.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete budget?'.i18n),
        content: Text('Are you sure you want to delete this budget?'.i18n),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.i18n),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete'.i18n),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _database.deleteBudget(budget.id!);
      await _loadData();
    }
  }

  double _budgetProgress(Budget budget, BudgetCycle cycle) {
    final matchingRecords = _matchingBudgetRecords(budget, _records, cycle);
    final total = matchingRecords.fold<double>(
      0,
      (sum, record) => sum + (record.value ?? 0).abs(),
    );
    return budget.targetAmount == 0 ? 0 : total / budget.targetAmount;
  }

  String _budgetAmount(Budget budget, double ratio) {
    final amount = budget.targetAmount * ratio;
    return '${getCurrencyValueString(amount.clamp(0, budget.targetAmount))} / ${getCurrencyValueString(budget.targetAmount)}';
  }

  String _cycleLabel(Budget budget, BudgetCycle cycle) {
    return 'From %s to %s'.i18n.fill([
      getDateStr(cycle.start),
      getDateStr(cycle.end),
    ]);
  }

  Widget _buildBudgetCard(Budget budget) {
    final cycle = budget.currentCycle();
    final ratio = _budgetProgress(budget, cycle);
    final color = budget.budgetType == BudgetType.expense
        ? Colors.red[600]!
        : Colors.green[600]!;
    final icon = budget.budgetType == BudgetType.expense
        ? Icons.remove_circle_outline
        : Icons.savings_outlined;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BudgetDetailPage(budget: budget)),
          );
          await _loadData();
        },
        onLongPress: () => _deleteBudget(budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cycleLabel(budget, cycle),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 8,
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_budgetAmount(budget, ratio)),
                  Text('${(ratio * 100).round()}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetTypeList(BudgetType type) {
    final budgets = _budgets
        .where(
          (budget) =>
              budget.budgetType == type && budget.isArchived == _showArchived,
        )
        .toList();
    if (budgets.isEmpty) {
      return _BudgetEmptyState(
        messages: [
          'Saving for your next vacation? Set a savings budget and track your progress.'
              .i18n,
          'Spending too much at the bar? Set a monthly budget and keep an eye on your progress.'
              .i18n,
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: budgets.length,
        itemBuilder: (context, index) => _buildBudgetCard(budgets[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_showArchived ? 'Archived budgets'.i18n : 'Budgets'.i18n),
          leading: _showArchived
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showArchived = false),
                )
              : null,
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 1) {
                  setState(() => _showArchived = !_showArchived);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<int>(
                  value: 1,
                  child: Text(
                    _showArchived
                        ? 'Show active budgets'.i18n
                        : 'Show archived budgets'.i18n,
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Expense budgets'.i18n),
              Tab(text: 'Saving budgets'.i18n),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildBudgetTypeList(BudgetType.expense),
                  _buildBudgetTypeList(BudgetType.saving),
                ],
              ),
        floatingActionButton: _showArchived
            ? null
            : Stack(
                children: [
                  FloatingActionButton(
                    onPressed: ServiceConfig.isPremium
                        ? _createBudget
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PremiumSplashScreen(),
                              ),
                            );
                          },
                    tooltip: 'Add a new budget'.i18n,
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
                              builder: (_) => PremiumSplashScreen(),
                            ),
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
      ),
    );
  }
}

enum _BudgetAction { edit, delete, archive }

class BudgetDetailPage extends StatefulWidget {
  final Budget budget;

  const BudgetDetailPage({super.key, required this.budget});

  @override
  State<BudgetDetailPage> createState() => _BudgetDetailPageState();
}

class _BudgetDetailPageState extends State<BudgetDetailPage> {
  final DatabaseInterface _database = ServiceConfig.database;
  List<Record> _records = [];
  Map<int, String?> _walletCurrencyMap = {};
  Map<int, Wallet> _walletMap = {};
  late Budget _budget;
  DateTime _periodReferenceDate = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _periodReferenceDate = DateTime.now();
    ServiceConfig.walletsEnabledNotifier.addListener(
      _handleWalletsEnabledChanged,
    );
    _loadData();
  }

  @override
  void dispose() {
    ServiceConfig.walletsEnabledNotifier.removeListener(
      _handleWalletsEnabledChanged,
    );
    super.dispose();
  }

  void _handleWalletsEnabledChanged() {
    if (!mounted || ServiceConfig.walletsEnabled || _budget.walletIds.isEmpty) {
      return;
    }
    setState(() => _budget.walletIds = []);
  }

  Future<void> _loadData() async {
    final profileId = ProfileService.instance.activeProfileId;
    final records = (await _database.getAllRecords(profileId: profileId))
        .whereType<Record>()
        .toList();
    final wallets = await _database.getAllWallets(profileId: profileId);
    if (!mounted) return;
    setState(() {
      _records = records;
      _walletCurrencyMap = {
        for (final wallet in wallets)
          if (wallet.id != null) wallet.id!: wallet.currency,
      };
      _walletMap = {
        for (final wallet in wallets)
          if (wallet.id != null) wallet.id!: wallet,
      };
      _loading = false;
    });
  }

  BudgetCycle get _selectedCycle => _budget.currentCycle(_periodReferenceDate);

  BudgetCycle get _latestCycle => _budget.currentCycle();

  bool get _canShiftBack =>
      _budget.isRecurring &&
      _selectedCycle.start.isAfter(
        DateTime(
          _budget.startDate.year,
          _budget.startDate.month,
          _budget.startDate.day,
        ),
      );

  bool get _canShiftForward =>
      _budget.isRecurring && _selectedCycle.start.isBefore(_latestCycle.start);

  List<Record> _currentRecords() {
    return _matchingBudgetRecords(_budget, _records, _selectedCycle);
  }

  void _shiftPeriod(int direction) {
    if (direction < 0 && !_canShiftBack) return;
    if (direction > 0 && !_canShiftForward) return;
    final reference = direction < 0
        ? _selectedCycle.start.subtract(const Duration(days: 1))
        : _selectedCycle.end.add(const Duration(days: 1));
    final nextCycle = _budget.currentCycle(reference);
    setState(() => _periodReferenceDate = nextCycle.start);
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  Future<void> _selectPeriod() async {
    final minimum = DateTime(
      _budget.startDate.year,
      _budget.startDate.month,
      _budget.startDate.day,
    );
    final today = DateTime.now();
    final configuredEnd = _budget.endDate == null
        ? today
        : DateTime(
            _budget.endDate!.year,
            _budget.endDate!.month,
            _budget.endDate!.day,
          );
    final maximum = configuredEnd.isBefore(today) ? configuredEnd : today;
    final effectiveMaximum = maximum.isBefore(minimum) ? minimum : maximum;
    final selectedEnd = _clampDate(
      _selectedCycle.end,
      minimum,
      effectiveMaximum,
    );
    final selectedStart = _clampDate(
      _selectedCycle.start,
      minimum,
      selectedEnd,
    );

    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: minimum,
      lastDate: effectiveMaximum,
      initialDateRange: DateTimeRange(start: selectedStart, end: selectedEnd),
      builder: (context, child) =>
          DatePickerUtils.buildDatePickerWithFirstDayOfWeek(
            context,
            child,
            getFirstDayOfWeekIndex(),
          ),
    );
    if (selectedRange == null || !mounted) return;

    final snappedCycle = _budget.currentCycle(selectedRange.start);
    if (snappedCycle.start.isAfter(_latestCycle.start)) return;
    setState(() => _periodReferenceDate = snappedCycle.start);
  }

  double _currentAmount() {
    return _currentRecords().fold<double>(
      0,
      (sum, record) => sum + (record.value ?? 0).abs(),
    );
  }

  Future<void> _editBudget() async {
    final updated = await Navigator.push<Budget>(
      context,
      MaterialPageRoute(builder: (_) => CreateBudgetPage(budget: _budget)),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _budget = updated;
      _periodReferenceDate = DateTime.now();
    });
    await _loadData();
  }

  Future<void> _deleteBudget() async {
    if (_budget.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete budget?'.i18n),
        content: Text('Are you sure you want to delete this budget?'.i18n),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.i18n),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete'.i18n),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteBudget(_budget.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _archiveBudget() async {
    if (_budget.id == null) return;
    final isCurrentlyArchived = _budget.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          (isCurrentlyArchived ? 'Unarchive budget?' : 'Archive budget?').i18n,
        ),
        content: Text(
          (isCurrentlyArchived
                  ? 'Do you really want to unarchive this budget?'
                  : 'Do you really want to archive this budget?')
              .i18n,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No'.i18n),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Yes'.i18n),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.archiveBudget(_budget.id!, !isCurrentlyArchived);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _handleAction(_BudgetAction action) async {
    switch (action) {
      case _BudgetAction.edit:
        await _editBudget();
        break;
      case _BudgetAction.delete:
        await _deleteBudget();
        break;
      case _BudgetAction.archive:
        await _archiveBudget();
        break;
    }
  }

  Future<void> _openStatistics() async {
    final from = DateTime(
      _budget.startDate.year,
      _budget.startDate.month,
      _budget.startDate.day,
    );
    final now = DateTime.now();
    final selectedCycle = _selectedCycle;
    final configuredEnd = _budget.endDate == null
        ? now
        : DateTime(
            _budget.endDate!.year,
            _budget.endDate!.month,
            _budget.endDate!.day,
            23,
            59,
            59,
          );
    final selectedEnd = DateTime(
      selectedCycle.end.year,
      selectedCycle.end.month,
      selectedCycle.end.day,
      23,
      59,
      59,
    );
    final to = [
      configuredEnd,
      selectedEnd,
      now,
    ].reduce((a, b) => a.isBefore(b) ? a : b);
    final history = _matchingBudgetRecords(
      _budget,
      _records,
      BudgetCycle(from, to),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatisticsPage(
          from,
          to,
          history,
          walletCurrencyMap: _walletCurrencyMap,
          walletMap: _walletMap,
        ),
      ),
    );
  }

  Widget _buildPeriodLabel(BudgetCycle cycle) {
    final template = 'From %s to %s'.i18n;
    final firstPlaceholder = template.indexOf('%s');
    final secondPlaceholder = template.indexOf('%s', firstPlaceholder + 2);
    const textStyle = TextStyle(fontSize: 16);
    const dateStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

    if (firstPlaceholder < 0 || secondPlaceholder < 0) {
      return Text(template, textAlign: TextAlign.center, style: textStyle);
    }

    return Text.rich(
      TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: template.substring(0, firstPlaceholder)),
          TextSpan(text: getDateStr(cycle.start), style: dateStyle),
          TextSpan(
            text: template.substring(firstPlaceholder + 2, secondPlaceholder),
          ),
          TextSpan(text: getDateStr(cycle.end), style: dateStyle),
          TextSpan(text: template.substring(secondPlaceholder + 2)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgressHeader() {
    final cycle = _selectedCycle;
    final amount = _currentAmount();
    final ratio = _budget.targetAmount == 0
        ? 0.0
        : amount / _budget.targetAmount;
    final color = _budget.budgetType == BudgetType.expense
        ? Colors.red[600]!
        : Colors.green[600]!;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  if (_budget.isRecurring)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Previous'.i18n,
                      onPressed: _loading || !_canShiftBack
                          ? null
                          : () => _shiftPeriod(-1),
                    ),
                  Expanded(child: Center(child: _buildPeriodLabel(cycle))),
                  if (_budget.isRecurring)
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Next'.i18n,
                      onPressed: _loading || !_canShiftForward
                          ? null
                          : () => _shiftPeriod(1),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      getCurrencyValueString(amount),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '(${(ratio * 100).round()}%)',
                        style: TextStyle(fontSize: 16, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '/ ${getCurrencyValueString(_budget.targetAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  minHeight: 9,
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRecords = _currentRecords();
    return Scaffold(
      appBar: AppBar(
        title: Text(_budget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Date Range'.i18n,
            onPressed: _loading ? null : _selectPeriod,
          ),
          IconButton(
            icon: const Icon(Icons.donut_small),
            tooltip: 'Statistics'.i18n,
            onPressed: _loading ? null : _openStatistics,
          ),
          PopupMenuButton<_BudgetAction>(
            onSelected: _handleAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _BudgetAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Edit'.i18n),
                ),
              ),
              PopupMenuItem(
                value: _BudgetAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  title: Text('Delete'.i18n),
                ),
              ),
              PopupMenuItem(
                value: _BudgetAction.archive,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _budget.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(
                    _budget.isArchived ? 'Unarchive'.i18n : 'Archive'.i18n,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildProgressHeader()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Records'.i18n,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (currentRecords.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('No entries found'.i18n)),
                    ),
                  )
                else
                  RecordsDayList(
                    List<Record?>.from(currentRecords),
                    isSliver: true,
                    walletCurrencyMap: _walletCurrencyMap,
                    onListBackCallback: _loadData,
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 75)),
              ],
            ),
    );
  }
}

class CreateBudgetPage extends StatefulWidget {
  final Budget? budget;

  const CreateBudgetPage({super.key, this.budget});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> {
  final _expenseFormKey = GlobalKey<FormState>();
  final _savingFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final DatabaseInterface _database = ServiceConfig.database;

  BudgetType _budgetType = BudgetType.expense;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now().add(const Duration(days: 30));
  bool _useRecurrence = false;
  RecurrentPeriod? _recurrentPeriod;
  int? _customIntervalValue;
  CustomIntervalUnit? _customIntervalUnit;
  List<Category?> _categories = [];
  Set<String> _selectedCategoryNames = {};
  Set<String> _selectedTags = {};
  Set<int> _selectedWalletIds = {};
  List<Wallet> _selectedWallets = [];
  bool _categoryTagOrLogic = true;
  bool _tagOrLogic = false;
  Set<String> _allTags = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ServiceConfig.walletsEnabledNotifier.addListener(
      _handleWalletsEnabledChanged,
    );
    final budget = widget.budget;
    if (budget != null) {
      _budgetType = budget.budgetType;
      _nameController.text = budget.name;
      _amountController.text = budget.targetAmount % 1 == 0
          ? budget.targetAmount.toInt().toString()
          : budget.targetAmount.toString().replaceAll(
              '.',
              getDecimalSeparator(),
            );
      _startDate = budget.startDate;
      _endDate = budget.endDate;
      _useRecurrence = budget.isRecurring;
      _recurrentPeriod = budget.recurrentPeriod;
      _customIntervalValue = budget.customIntervalValue;
      _customIntervalUnit = budget.customIntervalUnit;
      _selectedCategoryNames = budget.categoryNames.toSet();
      _selectedTags = budget.tags.toSet();
      _selectedWalletIds = budget.walletIds.toSet();
      _categoryTagOrLogic = budget.categoryTagOrLogic;
      _tagOrLogic = budget.tagOrLogic;
    }
    _loadFilterOptions();
  }

  @override
  void dispose() {
    ServiceConfig.walletsEnabledNotifier.removeListener(
      _handleWalletsEnabledChanged,
    );
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleWalletsEnabledChanged() {
    if (!mounted || ServiceConfig.walletsEnabled) return;
    // Wallet filters are intentionally cleared when the feature is disabled.
    // The form may still be open while the setting changes in another tab.
    if (_selectedWalletIds.isNotEmpty || _selectedWallets.isNotEmpty) {
      setState(() {
        _selectedWalletIds = {};
        _selectedWallets = [];
      });
    }
  }

  Future<void> _loadFilterOptions() async {
    final categories = await _database.getCategoriesByType(
      _budgetType == BudgetType.expense
          ? CategoryType.expense
          : CategoryType.income,
    );
    final tags = await _database.getAllTags();
    final wallets = ServiceConfig.walletsEnabled
        ? await _database.getAllWallets(
            profileId: ProfileService.instance.activeProfileId,
          )
        : <Wallet>[];
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _allTags = tags;
      _selectedWallets = wallets
          .where(
            (wallet) =>
                !wallet.isArchived && _selectedWalletIds.contains(wallet.id),
          )
          .toList();
    });
  }

  void _changeBudgetType(int index) {
    final type = index == 0 ? BudgetType.expense : BudgetType.saving;
    if (_budgetType == type) return;
    setState(() {
      _budgetType = type;
      _selectedCategoryNames = {};
    });
    _loadFilterOptions();
  }

  Future<void> _pickDate({required bool endDate}) async {
    FocusScope.of(context).unfocus();
    final initialDate = endDate
        ? (_endDate ?? _startDate.add(const Duration(days: 30)))
        : _startDate;
    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: endDate ? _startDate : DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) =>
          DatePickerUtils.buildDatePickerWithFirstDayOfWeek(
            context,
            child,
            getFirstDayOfWeekIndex(),
          ),
    );
    if (result == null) return;
    setState(() {
      if (endDate) {
        _endDate = result;
      } else {
        _startDate = result;
        if (_endDate != null && _endDate!.isBefore(result)) {
          _endDate = result.add(const Duration(days: 30));
        }
      }
    });
  }

  Future<void> _pickRecurrence() async {
    final selected = await showModalBottomSheet<RecurrentPeriod>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final period in [
              RecurrentPeriod.EveryDay,
              RecurrentPeriod.EveryWeek,
              RecurrentPeriod.EveryTwoWeeks,
              RecurrentPeriod.EveryFourWeeks,
              RecurrentPeriod.EveryMonth,
              RecurrentPeriod.EveryThreeMonths,
              RecurrentPeriod.EveryFourMonths,
              RecurrentPeriod.EveryYear,
              RecurrentPeriod.Custom,
            ])
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(
                  recurrentPeriodDisplayString(
                    period,
                    customIntervalValue: _customIntervalValue,
                    customIntervalUnit: _customIntervalUnit,
                  ),
                ),
                onTap: () => Navigator.pop(context, period),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    if (selected == RecurrentPeriod.Custom) {
      final custom = await showDialog<CustomIntervalSelection>(
        context: context,
        builder: (context) => CustomIntervalDialog(
          initialValue: _customIntervalValue,
          initialUnit: _customIntervalUnit,
        ),
      );
      if (custom == null) return;
      setState(() {
        _recurrentPeriod = selected;
        _customIntervalValue = custom.value;
        _customIntervalUnit = custom.unit;
      });
    } else {
      setState(() {
        _recurrentPeriod = selected;
        _customIntervalValue = null;
        _customIntervalUnit = null;
      });
    }
  }

  Future<void> _showFilters() async {
    final selectedCategories = _categories
        .where(
          (category) =>
              category != null &&
              _selectedCategoryNames.contains(category.name),
        )
        .toList();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterModalContent(
        categories: _categories,
        tags: _allTags.toList(),
        currentlySelectedCategories: selectedCategories,
        currentlySelectedTags: _selectedTags.toList(),
        currentCategoryTagOrLogic: _categoryTagOrLogic,
        currentTagsOrLogic: _tagOrLogic,
        onApplyFilters: (categories, tags, categoryOr, tagOr) {
          setState(() {
            _selectedCategoryNames = categories
                .whereType<Category>()
                .map((category) => category.name!)
                .toSet();
            _selectedTags = tags.toSet();
            _categoryTagOrLogic = categoryOr;
            _tagOrLogic = tagOr;
          });
        },
      ),
    );
  }

  String _recurrenceLabel() {
    if (!_useRecurrence || _recurrentPeriod == null) {
      return 'No recurrence'.i18n;
    }
    return recurrentPeriodDisplayString(
      _recurrentPeriod,
      customIntervalValue: _customIntervalValue,
      customIntervalUnit: _customIntervalUnit,
    );
  }

  Future<void> _selectWallets() async {
    if (!ServiceConfig.walletsEnabled) return;
    final selected = await Navigator.push<List<Wallet>>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPickerPage(
          multiSelect: true,
          initiallySelected: _selectedWallets,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedWallets = selected;
      _selectedWalletIds = selected
          .where((wallet) => wallet.id != null)
          .map((wallet) => wallet.id!)
          .toSet();
    });
  }

  String _walletSelectionLabel() {
    if (_selectedWalletIds.isEmpty) return 'All wallets'.i18n;
    if (_selectedWallets.length == 1) return _selectedWallets.first.name;
    return '%s Wallets'.i18n.fill([_selectedWalletIds.length.toString()]);
  }

  Widget _buildWalletButton() {
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text('Wallets'.i18n),
      subtitle: Text(_walletSelectionLabel()),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectWallets,
    );
  }

  Future<void> _save() async {
    final formKey = _budgetType == BudgetType.expense
        ? _expenseFormKey
        : _savingFormKey;
    if (!formKey.currentState!.validate()) return;
    final amount = tryParseCurrencyString(_amountController.text);
    if (amount == null || amount <= 0) return;
    if (!_useRecurrence && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an end date.'.i18n)),
      );
      return;
    }
    if (_useRecurrence && _recurrentPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a recurrence interval.'.i18n)),
      );
      return;
    }

    setState(() => _saving = true);
    final budget = Budget(
      id: widget.budget?.id,
      name: _nameController.text.trim(),
      targetAmount: amount,
      budgetType: _budgetType,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      endDate: _useRecurrence || _endDate == null
          ? null
          : DateTime(_endDate!.year, _endDate!.month, _endDate!.day),
      recurrentPeriod: _useRecurrence ? _recurrentPeriod : null,
      customIntervalValue: _useRecurrence ? _customIntervalValue : null,
      customIntervalUnit: _useRecurrence ? _customIntervalUnit : null,
      categoryNames: _selectedCategoryNames.toList(),
      tags: _selectedTags.toList(),
      walletIds: ServiceConfig.walletsEnabled
          ? _selectedWalletIds.toList()
          : [],
      categoryTagOrLogic: _categoryTagOrLogic,
      tagOrLogic: _tagOrLogic,
      isArchived: widget.budget?.isArchived ?? false,
      profileId:
          widget.budget?.profileId ?? ProfileService.instance.activeProfileId,
      timeZoneName: widget.budget?.timeZoneName,
    );
    if (widget.budget == null) {
      await _database.addBudget(budget);
    } else {
      await _database.updateBudget(budget);
    }
    if (mounted) Navigator.pop(context, budget);
  }

  Widget _buildDateRow({required bool endDate}) {
    final date = endDate ? _endDate : _startDate;
    return ListTile(
      leading: Icon(endDate ? Icons.event_busy : Icons.calendar_today),
      title: Text(endDate ? 'End date'.i18n : 'Starting date'.i18n),
      subtitle: Text(date == null ? 'Not set'.i18n : getDateStr(date)),
      onTap: () => _pickDate(endDate: endDate),
    );
  }

  Widget _buildFilterButton() {
    final count = _selectedCategoryNames.length + _selectedTags.length;
    return ListTile(
      leading: const Icon(Icons.filter_list),
      title: Text('Categories and tags'.i18n),
      subtitle: Text(
        count == 0
            ? 'All categories and tags'.i18n
            : '${"%s selected".i18n.fill([count.toString()])}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showFilters,
    );
  }

  Widget _buildForm(BudgetType type) {
    return Form(
      key: type == BudgetType.expense ? _expenseFormKey : _savingFormKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Budget name'.i18n,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter a budget name.'.i18n
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AmountInputField(
              controller: _amountController,
              labelText: 'Target amount'.i18n,
              validator: (value) {
                final parsed = value == null
                    ? null
                    : tryParseCurrencyString(value);
                return parsed == null || parsed <= 0
                    ? 'Please enter a positive amount.'.i18n
                    : null;
              },
            ),
          ),
          const Divider(),
          _buildDateRow(endDate: false),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: Text('Recurring budget'.i18n),
            subtitle: Text('Use a starting day and recurrent interval'.i18n),
            value: _useRecurrence,
            onChanged: (value) => setState(() {
              _useRecurrence = value;
              if (!value && _endDate == null) {
                _endDate = _startDate.add(const Duration(days: 30));
              }
            }),
          ),
          if (_useRecurrence)
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text('Recurrent interval'.i18n),
              subtitle: Text(_recurrenceLabel()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickRecurrence,
            )
          else
            _buildDateRow(endDate: true),
          const Divider(),
          _buildFilterButton(),
          ValueListenableBuilder<bool>(
            valueListenable: ServiceConfig.walletsEnabledNotifier,
            builder: (context, walletsEnabled, _) =>
                walletsEnabled ? _buildWalletButton() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _budgetType == BudgetType.saving ? 1 : 0,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.budget == null ? 'New budget'.i18n : 'Edit'.i18n,
              ),
              bottom: TabBar(
                onTap: _changeBudgetType,
                tabs: [
                  Tab(text: 'Expense budgets'.i18n),
                  Tab(text: 'Saving budgets'.i18n),
                ],
              ),
            ),
            body: TabBarView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildForm(BudgetType.expense),
                _buildForm(BudgetType.saving),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...'.i18n : 'Save'.i18n),
              ),
            ),
          );
        },
      ),
    );
  }
}
