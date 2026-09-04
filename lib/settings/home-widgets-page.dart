import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/home-widget-service.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

/// Settings > Home screen widgets: pin widgets and assign budgets to
/// pinned budget widget instances.
class HomeWidgetsPage extends StatefulWidget {
  const HomeWidgetsPage({super.key});

  @override
  HomeWidgetsPageState createState() => HomeWidgetsPageState();
}

class HomeWidgetsPageState extends State<HomeWidgetsPage> {
  static final _logger = Logger.withClass(HomeWidgetsPage);
  final DatabaseInterface _database = ServiceConfig.database;

  List<Budget> _budgets = [];
  List<HomeWidgetInfo> _budgetInstances = [];
  Map<String, int> _mapping = {};
  bool _pinSupported = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await _database.getBudgets(
        profileId: ProfileService.instance.activeProfileId);
    budgets.removeWhere((b) => b.isArchived);
    List<HomeWidgetInfo> installed = const [];
    try {
      installed = (await HomeWidget.getInstalledWidgets())
          .where((w) =>
              w.androidClassName == HomeWidgetService.budgetProvider)
          .toList();
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to list installed widgets');
    }
    final mapping = await HomeWidgetService.getBudgetMapping();
    bool pinSupported = false;
    try {
      pinSupported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to check pin support');
    }
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _budgetInstances = installed;
      _mapping = mapping;
      _pinSupported = pinSupported;
    });
  }

  Future<void> _pin(String qualifiedName) async {
    try {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: qualifiedName);
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to request widget pin');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not add the widget".i18n)),
        );
      }
    }
    await _load();
  }

  Future<void> _assignBudget(int widgetId, int? budgetId) async {
    await HomeWidgetService.setBudgetMapping(widgetId, budgetId);
    await HomeWidgetService.refreshAll();
    await _load();
  }

  Future<void> _refreshNow() async {
    setState(() => _refreshing = true);
    await HomeWidgetService.refreshAll();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home screen widgets".i18n)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              "Pin widgets showing your totals. They follow the homepage time interval and refresh when you open the app."
                  .i18n,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_pinSupported) ...[
            _PinRow(
              title: "Overview".i18n,
              onPin: () => _pin(HomeWidgetService.overviewProvider),
            ),
            _PinRow(
              title: "Income".i18n,
              onPin: () => _pin(HomeWidgetService.incomeProvider),
            ),
            _PinRow(
              title: "Expenses".i18n,
              onPin: () => _pin(HomeWidgetService.expensesProvider),
            ),
            _PinRow(
              title: "Balance".i18n,
              onPin: () => _pin(HomeWidgetService.balanceProvider),
            ),
            _PinRow(
              title: "Budget".i18n,
              subtitle: "Pick which budget below after pinning".i18n,
              onPin: () => _pin(HomeWidgetService.budgetProvider),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                "Add widgets from your launcher's widget picker.".i18n,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_budgetInstances.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                "Pinned budget widgets".i18n,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final instance in _budgetInstances)
              _BudgetInstanceRow(
                widgetId: instance.androidWidgetId!,
                budgets: _budgets,
                selectedBudgetId:
                    _mapping[instance.androidWidgetId.toString()],
                onChanged: (budgetId) => _assignBudget(
                    instance.androidWidgetId!, budgetId),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _refreshing ? null : _refreshNow,
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text("Refresh widgets".i18n),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onPin;

  const _PinRow({required this.title, this.subtitle, required this.onPin});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: IconButton(
        icon: const Icon(Icons.add_to_home_screen),
        tooltip: "Add to home screen".i18n,
        onPressed: onPin,
      ),
    );
  }
}

class _BudgetInstanceRow extends StatelessWidget {
  final int widgetId;
  final List<Budget> budgets;
  final int? selectedBudgetId;
  final ValueChanged<int?> onChanged;

  const _BudgetInstanceRow({
    required this.widgetId,
    required this.budgets,
    required this.selectedBudgetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("Budget widget".i18n + " #$widgetId"),
      trailing: DropdownButton<int?>(
        value: selectedBudgetId,
        hint: Text("Pick a budget".i18n),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text("None".i18n),
          ),
          for (final budget in budgets)
            if (budget.id != null)
              DropdownMenuItem<int?>(
                value: budget.id,
                child: Text(budget.name),
              ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
