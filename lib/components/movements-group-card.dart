
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';
import 'package:intl/date_symbol_data_local.dart';

class MovementsGroupCard extends StatefulWidget {
  final MovementsPerDay _movementDay;
  const MovementsGroupCard(this._movementDay);

  @override
  MovementGroupState createState() => MovementGroupState();
}

class MovementGroupState extends State<MovementsGroupCard> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

  Widget _buildMovements() {
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget._movementDay.movements.length,
        separatorBuilder: (context, index) {
          return Divider();
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildMovementRow(widget._movementDay.movements[i]);
        });
  }

  Widget _buildMovementRow(Movement movement) {
    return ListTile(
        title: Text(
          movement.description,
          style: _biggerFont,
        ),
        trailing: Text(
          movement.value.toString(),
          style: _biggerFont,
        ),
        leading: Container(
          width: 40,
          height: 40,
          child: Icon(Icons.attach_money, size: 20, color: Colors.white,),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: movement.tags[0].color,
        )
        )
    );
  }

  String extractMonthString(DateTime dateTime) {
    return new DateFormat("MMMM y").format(dateTime);
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
                                    extractWeekdayString(widget._movementDay.dateTime),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right
                                  ),
                                  Text(
                                    extractMonthString(widget._movementDay.dateTime),
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