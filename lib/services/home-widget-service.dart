import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:home_widget/home_widget.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';import 'package:piggybank/home_widgets/widget_views.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android home screen widgets (overview, income, expenses, balance, and
/// one configurable widget per budget).
///
/// The widgets render compact Flutter views to bitmaps, so they look like
/// the app. Values follow the homepage time interval setting. Refresh
/// happens on app events (record/budget changes, launch) plus a manual
/// refresh; Android additionally redraws on its own schedule.
class HomeWidgetService {
  static final _logger = Logger.withClass(HomeWidgetService);

  static const String _providerPackage = 'com.example.piggybank.widget';
  static const String overviewProvider =
      '$_providerPackage.OinkoinOverviewWidgetProvider';
  static const String incomeProvider =
      '$_providerPackage.OinkoinIncomeWidgetProvider';
  static const String expensesProvider =
      '$_providerPackage.OinkoinExpensesWidgetProvider';
  static const String balanceProvider =
      '$_providerPackage.OinkoinBalanceWidgetProvider';
  static const String budgetProvider =
      '$_providerPackage.OinkoinBudgetWidgetProvider';

  static const String overviewImageKey = 'oinkoin_overview_image';
  static const String incomeImageKey = 'oinkoin_income_image';
  static const String expensesImageKey = 'oinkoin_expenses_image';
  static const String balanceImageKey = 'oinkoin_balance_image';
  static String budgetImageKey(int androidWidgetId) =>
      'oinkoin_budget_image_$androidWidgetId';

  /// Maps pinned budget widget instances to budget database ids.
  /// Managed from Settings > Home screen widgets (device-local).
  static const String budgetMappingKey = 'homeWidgetBudgetMap';

  /// Widgets are an Android-only feature in this app.
  static bool get isSupported => Platform.isAndroid;

  static DatabaseInterface get _database => ServiceConfig.database;

  /// Recomputes every widget image and pushes the update. Best effort:
  /// failures only log so callers (UI event handlers) never break.
  static Future<void> refreshAll() async {
    if (!isSupported) return;
    try {
      final prefs = ServiceConfig.sharedPreferences ??
          await SharedPreferences.getInstance();
      final profileId = ProfileService.instance.activeProfileId;
      final interval = getHomepageTimeIntervalEnumSetting();
      final monthStartDay = getHomepageRecordsMonthStartDay();
      final wallets = await _database.getAllWallets(profileId: profileId);
      final walletCurrencyMap = {
        for (final w in wallets)
          if (w.id != null) w.id!: w.currency,
      };
      final records = await getRecordsByHomepageTimeInterval(
        _database,
        interval,
        monthStartDay: monthStartDay,
        profileId: profileId,
      );
      final theme = await _resolveTheme(prefs);

      await _refreshTotals(theme, records, walletCurrencyMap);
      await _refreshBudgets(theme, profileId);
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to refresh home screen widgets');
    }
  }

  /// Daily totals over the interval for sparklines (signed for balance,
  /// absolute otherwise), capped to the most recent 31 days.
  static List<double> dailySeries(
    Iterable<Record?> records, {
    required bool isBalance,
  }) {
    final byDay = <DateTime, double>{};
    for (final record in records) {
      if (record?.value == null || record!.isTransfer) continue;
      final day = DateTime(
        record.localDateTime.year,
        record.localDateTime.month,
        record.localDateTime.day,
      );
      final value = isBalance ? record.value! : record.value!.abs();
      byDay[day] = (byDay[day] ?? 0) + value;
    }
    final days = byDay.keys.toList()..sort();
    final tail = days.length > 31 ? days.sublist(days.length - 31) : days;
    return [for (final day in tail) byDay[day]!];
  }

  static Future<void> _refreshTotals(
    ThemeData theme,
    List<Record?> records,
    Map<int, String?> walletCurrencyMap,
  ) async {
    final brightness = theme.brightness;
    final incomeRecords = records.where((r) =>
        r?.category?.categoryType == CategoryType.income && !r!.isTransfer);
    final expenseRecords = records.where((r) =>
        r?.category?.categoryType == CategoryType.expense && !r!.isTransfer);
    final balanceRecords =
        records.where((r) => r != null && !r.isTransfer);

    String text(Iterable<Record?> rs, {required bool isBalance}) {
      final result =
          computeConvertedTotal(rs, walletCurrencyMap, isAbsValue: !isBalance);
      return formatRecordsTotalResult(result);
    }

    final incomeTotal =
        computeConvertedTotal(incomeRecords, walletCurrencyMap).total;
    final expenseTotal =
        computeConvertedTotal(expenseRecords, walletCurrencyMap).total;
    final balanceResult = computeConvertedTotal(
        balanceRecords, walletCurrencyMap,
        isAbsValue: false);

    await _render(
      theme,
      HomeWidgetOverview(
        incomeText: text(incomeRecords, isBalance: false),
        incomeColor:
            getAmountColor(incomeTotal, brightness) ?? Colors.green,
        expensesText: text(expenseRecords, isBalance: false),
        expenseColor:
            getAmountColor(expenseTotal, brightness) ?? Colors.red,
        balanceText: text(balanceRecords, isBalance: true),
        balanceColor:
            getAmountColor(balanceResult.total, brightness) ?? Colors.green,
        sparkline: dailySeries(balanceRecords, isBalance: true),
      ),
      overviewImageKey,
      const Size(480, 240),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: overviewProvider);

    await _render(
      theme,
      HomeWidgetAmount(
        label: "Income".i18n,
        amount: text(incomeRecords, isBalance: false),
        color: getAmountColor(incomeTotal, brightness),
        sparkline: dailySeries(incomeRecords, isBalance: false),
      ),
      incomeImageKey,
      const Size(320, 200),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: incomeProvider);

    await _render(
      theme,
      HomeWidgetAmount(
        label: "Expenses".i18n,
        amount: text(expenseRecords, isBalance: false),
        color: getAmountColor(expenseTotal, brightness),
        sparkline: dailySeries(expenseRecords, isBalance: false),
      ),
      expensesImageKey,
      const Size(320, 200),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: expensesProvider);

    await _render(
      theme,
      HomeWidgetAmount(
        label: "Balance".i18n,
        amount: text(balanceRecords, isBalance: true),
        color: getAmountColor(balanceResult.total, brightness),
        sparkline: dailySeries(balanceRecords, isBalance: true),
      ),
      balanceImageKey,
      const Size(320, 200),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: balanceProvider);
  }

  static Future<void> _refreshBudgets(ThemeData theme, int? profileId) async {
    final budgets = (await _database.getBudgets(profileId: profileId))
        .where((b) => !b.isArchived)
        .toList();
    if (budgets.isEmpty) return;
    final byId = {for (final b in budgets) b.id: b};

    List<HomeWidgetInfo> installed = const [];
    try {
      installed = await HomeWidget.getInstalledWidgets();
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to list installed widgets');
      return;
    }
    final mapping = await getBudgetMapping();
    final allRecords = await _database.getAllRecords(profileId: profileId);

    for (final info in installed) {
      if (info.androidClassName != budgetProvider) continue;
      final widgetId = info.androidWidgetId;
      if (widgetId == null) continue;
      final budget = byId[mapping[widgetId.toString()]];
      if (budget == null) continue;
      final cycle = budget.currentCycle();
      final spent = matchingBudgetRecords(budget, allRecords.whereType<Record>(), cycle)
          .fold<double>(0, (sum, r) => sum + (r.value ?? 0).abs());
      final ratio =
          budget.targetAmount == 0 ? 0.0 : spent / budget.targetAmount;
      final color = budget.budgetType == BudgetType.expense
          ? Colors.red[600]!
          : Colors.green[600]!;
      await _render(
        theme,
        HomeWidgetBudget(
          name: budget.name,
          progressText:
              '${getCurrencyValueString(spent)} / ${getCurrencyValueString(budget.targetAmount)}',
          ratio: ratio.clamp(0.0, 1.0),
          color: color,
        ),
        budgetImageKey(widgetId),
        const Size(280, 240),
      );
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: budgetProvider);
  }

  /// Wraps [child] with the theming a bare render needs and screenshots it
  /// to the shared widget storage under [key]. Rendered at 3x so the
  /// bitmap stays crisp on high-density screens.
  static Future<void> _render(
    ThemeData theme,
    Widget child,
    String key,
    Size logicalSize,
  ) async {
    final wrapped = Theme(
      data: theme,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!,
          // Fill the frame so the card uses the whole widget area.
          child: SizedBox.fromSize(size: logicalSize, child: child),
        ),
      ),
    );
    await HomeWidget.renderFlutterWidget(wrapped,
        key: key, logicalSize: logicalSize, pixelRatio: 3.0);
  }

  static Future<ThemeData> _resolveTheme(SharedPreferences prefs) async {
    final modeIndex = prefs.getInt(PreferencesKeys.themeMode) ?? 0;
    final systemDark =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final dark = modeIndex == 2 || (modeIndex == 0 && systemDark);
    return dark
        ? await MaterialThemeInstance.getDarkTheme()
        : await MaterialThemeInstance.getLightTheme();
  }

  /// Budget database id per pinned budget-widget instance id.
  static Future<Map<String, int>> getBudgetMapping() async {
    final prefs = ServiceConfig.sharedPreferences ??
        await SharedPreferences.getInstance();
    final raw = prefs.getString(budgetMappingKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> setBudgetMapping(int androidWidgetId, int? budgetId) async {
    final prefs = ServiceConfig.sharedPreferences ??
        await SharedPreferences.getInstance();
    final mapping = await getBudgetMapping();
    if (budgetId == null) {
      mapping.remove(androidWidgetId.toString());
    } else {
      mapping[androidWidgetId.toString()] = budgetId;
    }
    await prefs.setString(budgetMappingKey, json.encode(mapping));
  }
}
