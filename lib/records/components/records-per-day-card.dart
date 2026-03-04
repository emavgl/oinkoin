import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/service-config.dart';

import '../../components/category_icon_circle.dart';
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
  const RecordsPerDayCard(this._movementDay, {this.onListBackCallback});

  @override
  MovementGroupState createState() => MovementGroupState();
}

class MovementGroupState extends State<RecordsPerDayCard>
    with AutomaticKeepAliveClientMixin {
  final _titleFontStyle = const TextStyle(fontSize: 18.0);
  final _currencyFontStyle =
      const TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal);

  late int _numberOfNoteLinesToShow;
  late bool _visualiseTags;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    _numberOfNoteLinesToShow = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.homepageRecordNotesVisible)!;
    _visualiseTags = PreferencesUtils.getOrDefault<bool>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.visualiseTagsInMainPage)!;
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

  Widget _buildMovementRow(Record movement) {
    /// Returns a ListTile rendering the single movement row

    final listTile = ListTile(
      onTap: () async {
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
      },
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
          if (_visualiseTags && movement.tags.isNotEmpty)
            _buildTagChipsRow(movement.tags),
        ],
      ),
      trailing: Text(
        getCurrencyValueString(movement.value),
        style: _currencyFontStyle,
      ),
      leading: CategoryIconCircle(
        iconEmoji: movement.category?.iconEmoji,
        iconDataFromDefaultIconSet: movement.category?.icon,
        backgroundColor: movement.category?.color,
        overlayIcon: movement.recurrencePatternId != null ? Icons.repeat : null,
      ),
    );

    // Apply reduced opacity for future records
    if (movement.isFutureRecord) {
      return Opacity(
        opacity: 0.5,
        child: listTile,
      );
    }

    return listTile;
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
                        getCurrencyValueString(widget._movementDay.balance),
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
