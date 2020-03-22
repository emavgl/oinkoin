
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
        subtitle: Container(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
      child: Container(
          child: Column(
            children: <Widget>[
              Text(
                widget._movementDay.dateTime.toString(),
                style: _biggerFont,
              ),
              Divider(),
              _buildMovements()
            ],
          )
      ),
    );
  }
}