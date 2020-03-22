
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

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
    return ListView.builder(
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return Divider(); /*2*/
          final index = i ~/ 2; /*3*/
          return _buildMovementRow(widget._movementDay.movements[index]);
        });
  }

  Widget _buildMovementRow(Movement movement) {
    return ListTile(
        title: Text(
          movement.dateTime.toString(),
          style: _biggerFont,
        ),
        trailing: Text(
          movement.value.toString(),
          style: _biggerFont,
        ),
        subtitle: Container(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    movement.dateTime.toString(),
                    style: _subtitleFont,
                  ),
                  Container(
                      color: movement.tags[0].color,
                      child:
                      Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(
                              movement.tags[0].name,
                              style: TextStyle(
                                color: Colors.white,
                              )
                          )
                      )
                  ),
                ]
            )),
        onTap: () {
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: _buildMovements(),
    );
  }
}