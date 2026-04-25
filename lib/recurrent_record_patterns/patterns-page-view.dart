import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

import '../components/category_icon_circle.dart';
import '../models/recurrent-period.dart';
import 'package:piggybank/i18n.dart';

class PatternsPageView extends StatefulWidget {
  @override
  PatternsPageViewState createState() => PatternsPageViewState();
}

class PatternsPageViewState extends State<PatternsPageView> {
  List<RecurrentRecordPattern>? _recurrentRecordPatterns;
  Map<int, Wallet> _walletsById = {};
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileId = ProfileService.instance.activeProfileId;
    final results = await Future.wait([
      database.getRecurrentRecordPatterns(profileId: profileId),
      database.getAllWallets(profileId: profileId),
    ]);
    if (!mounted) return;
    setState(() {
      _recurrentRecordPatterns = results[0] as List<RecurrentRecordPattern>;
      final wallets = results[1] as List<Wallet>;
      _walletsById = {
        for (final w in wallets)
          if (w.id != null) w.id!: w
      };
    });
  }

  fetchRecurrentRecordPatternsFromDatabase() async {
    var patterns = await database.getRecurrentRecordPatterns();
    if (!mounted) return;
    setState(() {
      _recurrentRecordPatterns = patterns;
    });
  }

  Map<int, String?> _buildWalletCurrencyMap() {
    final defaultCurrency = getDefaultCurrency();
    final effectiveDefault =
        (defaultCurrency != null && defaultCurrency.isNotEmpty)
            ? defaultCurrency
            : null;
    return {
      for (final entry in _walletsById.entries)
        entry.key:
            (entry.value.currency != null && entry.value.currency!.isNotEmpty)
                ? entry.value.currency
                : effectiveDefault
    };
  }

  Widget _buildPatternAmountWidget(RecurrentRecordPattern pattern) {
    final wallet =
        pattern.walletId != null ? _walletsById[pattern.walletId] : null;

    final patternCurrency = wallet?.currency;

    // No currency set
    if (patternCurrency == null || patternCurrency.isEmpty) {
      return Text(getCurrencyValueString(pattern.value), style: _biggerFont);
    }

    return buildAmountWithCurrencyWidget(pattern.value!, patternCurrency,
        mainStyle: _biggerFont);
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFontSize = const TextStyle(fontSize: 14.0);

  String _recurrenceSubtitle(RecurrentRecordPattern pattern) {
    final dt = pattern.localDateTime;
    switch (pattern.recurrentPeriod) {
      case RecurrentPeriod.EveryDay:
        return '';
      case RecurrentPeriod.EveryWeek:
      case RecurrentPeriod.EveryTwoWeeks:
      case RecurrentPeriod.EveryFourWeeks:
        return DateFormat.EEEE().format(DateTime(dt.year, dt.month, dt.day));
      case RecurrentPeriod.EveryYear:
        return DateFormat.MMMd().format(DateTime(dt.year, dt.month, dt.day));
      default:
        // EveryMonth, EveryThreeMonths, EveryFourMonths
        return "${"Day".i18n} ${dt.day}";
    }
  }

  Widget _buildRecurrentPatternRow(RecurrentRecordPattern pattern) {
    /// Returns a ListTile rendering the single movement row
    final subtitle = _recurrenceSubtitle(pattern);
    return Container(
      margin: EdgeInsets.only(top: 10, bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditRecordPage(
                passedRecurrentRecordPattern: pattern,
              ),
            ),
          );
          await fetchRecurrentRecordPatternsFromDatabase();
        },
        title: Text(
          pattern.title == null || pattern.title!.trim().isEmpty
              ? pattern.category!.name!
              : pattern.title!,
          style: _biggerFont,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: _subtitleFontSize)
            : null,
        trailing: _buildPatternAmountWidget(pattern),
        leading: CategoryIconCircle(
          iconEmoji: pattern.category?.iconEmoji,
          iconDataFromDefaultIconSet: pattern.category?.icon,
          backgroundColor: pattern.category?.color,
        ),
      ),
    );
  }

  Map<RecurrentPeriod, List<RecurrentRecordPattern>> _groupPatternsByPeriod() {
    Map<RecurrentPeriod, List<RecurrentRecordPattern>> grouped = {};

    for (var pattern in _recurrentRecordPatterns!) {
      if (pattern.recurrentPeriod != null) {
        if (!grouped.containsKey(pattern.recurrentPeriod)) {
          grouped[pattern.recurrentPeriod!] = [];
        }
        grouped[pattern.recurrentPeriod!]!.add(pattern);
      }
    }

    for (var entry in grouped.entries) {
      final period = entry.key;
      entry.value.sort((a, b) {
        final aDate = a.localDateTime;
        final bDate = b.localDateTime;
        switch (period) {
          case RecurrentPeriod.EveryWeek:
          case RecurrentPeriod.EveryTwoWeeks:
          case RecurrentPeriod.EveryFourWeeks:
            return aDate.weekday.compareTo(bDate.weekday);
          case RecurrentPeriod.EveryYear:
            final cmp = aDate.month.compareTo(bDate.month);
            return cmp != 0 ? cmp : aDate.day.compareTo(bDate.day);
          default:
            return aDate.day.compareTo(bDate.day);
        }
      });
    }

    return grouped;
  }

  String _formatGroupSum(List<RecurrentRecordPattern> patterns) {
    final walletCurrencyMap = _buildWalletCurrencyMap();
    final defaultCurrency = getDefaultCurrency();

    // Collect unique currencies among the patterns
    final currencies = patterns
        .where((p) => p.walletId != null)
        .map((p) => walletCurrencyMap[p.walletId])
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet();

    if (currencies.isEmpty) {
      final total =
          patterns.fold<double>(0.0, (sum, p) => sum + (p.value ?? 0.0));
      return getCurrencyValueString(total);
    }

    if (currencies.length == 1) {
      final total =
          patterns.fold<double>(0.0, (sum, p) => sum + (p.value ?? 0.0));
      return formatCurrencyAmount(total, currencies.first);
    }

    // Mixed currencies — convert all to default currency
    if (defaultCurrency != null) {
      final rates = getConversionRates();
      double total = 0.0;
      for (final p in patterns) {
        final value = p.value ?? 0.0;
        final currency =
            p.walletId != null ? walletCurrencyMap[p.walletId] : null;
        if (currency == null ||
            currency.isEmpty ||
            currency == defaultCurrency) {
          total += value;
        } else {
          final rate = rates['${currency}_$defaultCurrency'];
          total += rate != null ? value * rate : value;
        }
      }
      return formatCurrencyAmount(total, defaultCurrency);
    }

    // No default currency set — fallback to raw sum
    final total =
        patterns.fold<double>(0.0, (sum, p) => sum + (p.value ?? 0.0));
    return getCurrencyValueString(total);
  }

  Widget _buildGroupHeader(RecurrentPeriod period, String formattedSum) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            recurrentPeriodString(period),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            formattedSum,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget buildRecurrentRecordPatternsList() {
    return _recurrentRecordPatterns != null
        ? new Container(
            margin: EdgeInsets.all(5),
            child: _recurrentRecordPatterns!.length == 0
                ? new Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                          child: new Column(
                        children: <Widget>[
                          Image.asset(
                            'assets/images/no_entry_2.png',
                            width: 200,
                          ),
                          Container(
                              child: Text(
                            "No recurrent records yet.".i18n,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.0,
                            ),
                          ))
                        ],
                      ))
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(6.0),
                    itemCount: _groupPatternsByPeriod().length,
                    itemBuilder: (context, index) {
                      var groupedPatterns = _groupPatternsByPeriod();
                      var period = groupedPatterns.keys.elementAt(index);
                      var patterns = groupedPatterns[period]!;

                      return Container(
                        margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                        child: Column(
                          children: [
                            _buildGroupHeader(
                                period, _formatGroupSum(patterns)),
                            Divider(thickness: 0.5),
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              separatorBuilder: (context, index) => Divider(),
                              itemCount: patterns.length,
                              itemBuilder: (context, i) {
                                return _buildRecurrentPatternRow(patterns[i]);
                              },
                            ),
                          ],
                        ),
                      );
                    }))
        : new Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Recurrent Records'.i18n)),
        body: buildRecurrentRecordPatternsList());
  }
}
