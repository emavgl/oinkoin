import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

import '../../components/category_icon_circle.dart';
import '../../services/database/database-interface.dart';
import '../../settings/constants/preferences-keys.dart';
import '../../settings/preferences-utils.dart';

class RecordsPerDayCard extends StatefulWidget {
  /// RecordsCard renders a MovementPerDay object as a Card
  /// The card contains an header with date and the balance of the day
  /// and a body, containing the list of movements included in the MovementsPerDay object
  /// refreshParentMovementList is a callback method called every time the card may change
  /// for example, from the deletion of a record or the editing of the record.
  /// The callback should re-fetch the newest version of the records list from the database and rebuild the card

  final Function? onListBackCallback;
  final RecordsPerDay _movementDay;
  final Map<int, String?> walletCurrencyMap;
  final bool isSelectMode;
  final Set<int> selectedRecordIds;
  final void Function(int)? onRecordLongPressed;
  final void Function(int)? onRecordTapped;

  const RecordsPerDayCard(this._movementDay,
      {this.onListBackCallback,
      this.walletCurrencyMap = const {},
      this.isSelectMode = false,
      this.selectedRecordIds = const {},
      this.onRecordLongPressed,
      this.onRecordTapped});

  @override
  _RecordsPerDayCardState createState() => _RecordsPerDayCardState();
}

class _RecordsPerDayCardState extends State<RecordsPerDayCard>
    with AutomaticKeepAliveClientMixin {
  final _titleFontStyle = const TextStyle(fontSize: 18.0);
  final _currencyFontStyle =
      const TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal);

  late int _numberOfNoteLinesToShow;
  late bool _visualiseTags;
  late bool _showWalletInRecordList;
  Map<int, Wallet> _walletsById = {};
  final DatabaseInterface _database = ServiceConfig.database;

  @override
  bool get wantKeepAlive => true;

  /// Effective wallet→currency map: uses the passed-in map when non-empty,
  /// otherwise falls back to each wallet's own currency from _walletsById.
  Map<int, String?> get _effectiveCurrencyMap {
    if (widget.walletCurrencyMap.isNotEmpty) return widget.walletCurrencyMap;
    final defaultCurrency = getDefaultCurrency();
    return {
      for (final entry in _walletsById.entries)
        entry.key:
            (entry.value.currency != null && entry.value.currency!.isNotEmpty)
                ? entry.value.currency
                : defaultCurrency,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  void _loadPreferences() {
    final prefs = ServiceConfig.sharedPreferences!;
    _numberOfNoteLinesToShow = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.homepageRecordNotesVisible)!;
    _visualiseTags = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.visualiseTagsInMainPage)!;
    _showWalletInRecordList = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.showWalletInRecordList)!;
  }

  Future<void> _loadWallets() async {
    final wallets = await _database.getAllWallets(
        profileId: ProfileService.instance.activeProfileId);
    if (!mounted) return;
    setState(() {
      _walletsById = {
        for (final w in wallets)
          if (w.id != null) w.id!: w
      };
    });
  }

  Widget _buildRecordAmountWidget(Record record) {
    final wallet =
        record.walletId != null ? _walletsById[record.walletId] : null;

    final effectiveMap = _effectiveCurrencyMap;
    final recordCurrency = record.walletId != null
        ? effectiveMap[record.walletId]
        : wallet?.currency;

    // No currency info at all — fall back to plain number
    if (recordCurrency == null || recordCurrency.isEmpty) {
      return Text(getCurrencyValueString(record.value),
          style: _currencyFontStyle);
    }

    return buildAmountWithCurrencyWidget(record.value!, recordCurrency,
        mainStyle: _currencyFontStyle);
  }

  bool _dayHasMixedCurrencies(List<Record?> records) {
    final effectiveMap = _effectiveCurrencyMap;
    final currencies = <String?>{};
    for (final r in records) {
      if (r == null) continue;
      final c = effectiveMap[r.walletId];
      if (c != null && c.isNotEmpty) {
        currencies.add(c);
        if (currencies.length > 1) return true;
      }
    }
    return currencies.length > 1;
  }

  String _formatDayBalance() {
    final records = widget._movementDay.records ?? [];
    if (records.isEmpty) {
      return getCurrencyValueString(widget._movementDay.balance);
    }

    final effectiveMap = _effectiveCurrencyMap;
    final allSameCurrency = !_dayHasMixedCurrencies(records);

    if (allSameCurrency) {
      final result = computeConvertedTotal(records, effectiveMap);
      if (result.currency != null && result.currency!.isNotEmpty) {
        return formatAmountWithCurrency(result.total, result.currency!);
      }
      final defaultCurrency = getDefaultCurrency();
      if (defaultCurrency != null && defaultCurrency.isNotEmpty) {
        return formatAmountWithCurrency(result.total, defaultCurrency);
      }
      return getCurrencyValueString(result.total);
    } else {
      // Mixed currencies — show only in default currency
      final defaultCurrency = getDefaultCurrency();
      if (defaultCurrency != null) {
        final result =
            computeTotalInCurrency(records, effectiveMap, defaultCurrency);
        return formatCurrencyAmount(result.total, defaultCurrency);
      }
      return formatRecordsTotalResult(
          computeConvertedTotal(records, effectiveMap));
    }
  }

  Widget _buildMovements() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget._movementDay.records!.length,
        separatorBuilder: (context, index) {
          return Divider(
            thickness: 0.5,
            endIndent: 10,
            indent: 10,
          );
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          var reversedIndex = widget._movementDay.records!.length - i - 1;
          return _buildMovementRow(
              widget._movementDay.records![reversedIndex]!);
        });
  }

  Widget _buildLeading(Record movement, bool isSelected) {
    final base = CategoryIconCircle(
      iconEmoji: movement.category?.iconEmoji,
      iconDataFromDefaultIconSet: movement.category?.icon,
      backgroundColor: movement.category?.color,
      overlayIcon: movement.recurrencePatternId != null ? Icons.repeat : null,
      topOverlayIcon: movement.isTransfer ? Icons.swap_horiz : null,
    );
    if (!widget.isSelectMode) return base;
    return Stack(
      alignment: Alignment.center,
      children: [
        base,
        AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.88),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildMovementRow(Record movement) {
    /// Returns a ListTile rendering the single movement row

    final isSelected = widget.isSelectMode &&
        movement.id != null &&
        widget.selectedRecordIds.contains(movement.id);
    final canSelect = !movement.isFutureRecord && movement.id != null;

    final listTile = ListTile(
      onTap: widget.isSelectMode && canSelect
          ? () => widget.onRecordTapped?.call(movement.id!)
          : !widget.isSelectMode
              ? () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EditRecordPage(
                                passedRecord: movement,
                                readOnly: movement
                                    .isFutureRecord, // Future records are read-only
                              )));
                  if (widget.onListBackCallback != null)
                    await widget.onListBackCallback!();
                }
              : null,
      onLongPress: widget.isSelectMode || movement.isFutureRecord || movement.id == null
          ? null
          : () => widget.onRecordLongPressed?.call(movement.id!),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movement.title == null || movement.title!.trim().isEmpty
                ? movement.category!.name!
                : movement.title!,
            style: _titleFontStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_numberOfNoteLinesToShow > 0 &&
              movement.description != null &&
              movement.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                movement.description!,
                style: TextStyle(
                  fontSize: 15.0, // Slightly smaller than title
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color, // Lighter color
                ),
                softWrap: true,
                maxLines:
                    _numberOfNoteLinesToShow, // if index is 4, do not wrap
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_showWalletInRecordList &&
              !movement.isFutureRecord &&
              movement.walletId != null &&
              _walletsById.containsKey(movement.walletId))
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                movement.isTransfer &&
                        movement.transferWalletId != null &&
                        _walletsById.containsKey(movement.transferWalletId)
                    ? "${_walletsById[movement.walletId]!.name} → ${_walletsById[movement.transferWalletId]!.name}"
                    : _walletsById[movement.walletId]!.name,
                style: TextStyle(
                  fontSize: 13.0,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          if (_visualiseTags && movement.tags.isNotEmpty)
            _buildTagChipsRow(movement.tags),
        ],
      ),
      trailing: _buildRecordAmountWidget(movement),
      leading: _buildLeading(movement, isSelected),
    );

    Widget result = Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: listTile,
    );

    // Apply reduced opacity for future records
    if (movement.isFutureRecord) {
      return Opacity(
        opacity: 0.5,
        child: result,
      );
    }

    return result;
  }

  Widget _buildTagChipsRow(Set<String> tags) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          List<Widget> tagChips = [];
          for (final tag in tags) {
            final chip = Container(
                margin: EdgeInsets.symmetric(horizontal: 1),
                child: Chip(
                  label: Text(tag, style: TextStyle(fontSize: 12.0)),
                  visualDensity: VisualDensity.compact,
                ));
            tagChips.add(chip);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tagChips,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _loadPreferences();
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
      child: Container(
          child: Column(
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 8, 8, 0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget._movementDay.dateTime!.day.toString(),
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    extractWeekdayString(
                                        widget._movementDay.dateTime!),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right),
                                Text(
                                    extractMonthString(
                                            widget._movementDay.dateTime!) +
                                        ' ' +
                                        extractYearString(
                                            widget._movementDay.dateTime!),
                                    style: TextStyle(fontSize: 13),
                                    textAlign: TextAlign.right)
                              ],
                            ))
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 22, 0),
                      child: Text(
                        _formatDayBalance(),
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ])),
          new Divider(
            thickness: 0.5,
          ),
          _buildMovements(),
        ],
      )),
    );
  }
}
