import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/edit-record-page.dart';

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

class MovementGroupState extends State<RecordsPerDayCard> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _trailingBiggerFont =
      const TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

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

  Widget _buildLeadingIconRecurrentMovement(Record movement) {
    return Stack(
      children: [
        Container(
            width: 40,
            height: 40,
            child: Icon(
              movement.category!.icon,
              size: 20,
              color: Colors.white,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: movement.category!.color,
            )),
        Container(
            margin: EdgeInsets.only(left: 30, top: 20),
            width: 20,
            height: 20,
            child: Icon(
              Icons.repeat,
              size: 10,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: BoxDecoration(
//              border: Border.all(color: Colors.black),
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
            ))
      ],
    );
  }

  Widget _buildLeadingIconMovement(Record movement) {
    return Container(
        margin: EdgeInsets.only(right: 10),
        width: 40,
        height: 40,
        child: Icon(
          movement.category!.icon,
          size: 20,
          color: Colors.white,
        ),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: movement.category!.color,
        ));
  }

  Widget _buildMovementRow(Record movement) {
    /// Returns a ListTile rendering the single movement row
    return ListTile(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => EditRecordPage(
                        passedRecord: movement,
                      )));
          if (widget.onListBackCallback != null)
            await widget.onListBackCallback!();
        },
        title: Text(
          movement.title == null || movement.title!.trim().isEmpty
              ? movement.category!.name!
              : movement.title!,
          style: _biggerFont,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          getCurrencyValueString(movement.value),
          style: _trailingBiggerFont,
        ),
        leading: movement.recurrencePatternId == null
            ? _buildLeadingIconMovement(movement)
            : _buildLeadingIconRecurrentMovement(movement));
  }

  @override
  Widget build(BuildContext context) {
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
