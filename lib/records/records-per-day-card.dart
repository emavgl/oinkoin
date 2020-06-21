
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/edit-record-page.dart';
import './i18n/movements-group-card.i18n.dart';

class RecordsPerDayCard extends StatefulWidget {

  /// RecordsCard renders a MovementPerDay object as a Card
  /// The card contains an header with date and the balance of the day
  /// and a body, containing the list of movements included in the MovementsPerDay object

  final Function refreshParentMovementList;
  final RecordsPerDay _movementDay;
  const RecordsPerDayCard(this._movementDay, this.refreshParentMovementList);

  @override
  MovementGroupState createState() => MovementGroupState();
}

class MovementGroupState extends State<RecordsPerDayCard> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

  Widget _buildMovements() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget._movementDay.records.length,
        separatorBuilder: (context, index) {
          return Divider();
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          var reversed_index = widget._movementDay.records.length - i - 1;
          return _buildMovementRow(widget._movementDay.records[reversed_index]);
        });
  }

  Widget _buildMovementRow(Record movement) {
    /// Returns a ListTile rendering the single movement row
    return ListTile(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => EditRecordPage(passedRecord: movement,)
              )
          );
          await widget.refreshParentMovementList();
        },
        title: Text(
          movement.title != null ? movement.title : movement.category.name,
          style: _biggerFont,
        ),
        trailing: Text(
          movement.value.toString(),
          style: _biggerFont,
        ),
        leading: Container(
          width: 40,
          height: 40,
          child: Icon(movement.category.icon, size: 20, color: Colors.white,),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: movement.category.color,
        )
        )
    );
  }

  String extractMonthString(DateTime dateTime) {
    return new DateFormat("MMMM").format(dateTime);
  }

  String extractYearString(DateTime dateTime) {
    return new DateFormat("y").format(dateTime);
  }

  String extractWeekdayString(DateTime dateTime) {
    return new DateFormat("EEEE").format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
          child: Column(
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget._movementDay.dateTime.day.toString(),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    extractWeekdayString(widget._movementDay.dateTime).i18n,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right
                                  ),
                                  Text(
                                    extractMonthString(widget._movementDay.dateTime).i18n + ' ' + extractYearString(widget._movementDay.dateTime),
                                    style: TextStyle(fontSize: 13),
                                    textAlign: TextAlign.right
                                  )
                                ],
                              )
                            )
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
                          child: Text(
                            widget._movementDay.balance.toStringAsFixed(1),
                            style: TextStyle(fontSize: 15),
                          ),
                        )
                    ]
                  )
              ),
              new Divider(),
              _buildMovements(),
            ],
          )
      ),
    );
  }
}