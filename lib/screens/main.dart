
import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

import '../components/movements-group-card.dart';

class RandomMovements extends StatefulWidget {
  @override
  RandomMovementsState createState() => RandomMovementsState();
}

class RandomMovementsState extends State<RandomMovements> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);
  List<MovementsPerDay> _daysShown = MovementsInMemoryDatabase.movementsDays;



  Widget _buildDays() {
    return ListView.builder(
      itemCount: _daysShown.length,
      padding: const EdgeInsets.all(6.0),
      itemBuilder: /*1*/ (context, i) {
        return MovementsGroupCard(_daysShown[i]);
      });
  }

  showAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("OK"),
      onPressed: () => Navigator.of(context).pop() // dismiss dialog,
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("My title"),
      content: Text("This is my message."),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movements'),
        actions: <Widget>[      // Add 3 lines from here...
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            margin: const EdgeInsets.fromLTRB(6, 10, 6, 5),
            height: 100,
            child: DaysSummaryBox(this._daysShown)
          ),
          Divider(indent: 50, endIndent: 50),
          Expanded(
            child: _buildDays(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAlertDialog(context),
        tooltip: 'Increment Counter',
        child: const Icon(Icons.add),
      ),
    );
  }
}