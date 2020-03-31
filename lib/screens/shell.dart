
import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/screens/graphspage.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

import '../components/movements-group-card.dart';
import 'movementspage.dart';

class Shell extends StatefulWidget {

  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);
  List<MovementsPerDay> _daysShown = MovementsInMemoryDatabase.movementsDays;

  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _currentIndex = 0;

  Widget _buildDays() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget._daysShown.length,
      padding: const EdgeInsets.all(6.0),
      itemBuilder: /*1*/ (context, i) {
        return MovementsGroupCard(widget._daysShown[i]);
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
    // How I have implemented navigation: https://stackoverflow.com/questions/45235570/how-to-use-bottomnavigationbar-with-navigator
    return Scaffold(
      body: new Stack(
          children: <Widget>[
          new Offstage(
            offstage: _currentIndex != 0,
            child: new TickerMode(
            enabled: _currentIndex == 0,
            child: new MaterialApp(home: new MovementsPage()),
          ),
          ),
          new Offstage(
            offstage: _currentIndex != 1,
            child: new TickerMode(
              enabled: _currentIndex == 1,
              child: new MaterialApp(home: new GraphsPage()),
            ),
          ),
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) { setState((){ this._currentIndex = index; }); },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        fixedColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(
            title: Text("Home"),
            icon: Icon(Icons.home)
          ),
          BottomNavigationBarItem(
              title: Text("Graphs"),
              icon: Icon(Icons.donut_small)
          ),
          BottomNavigationBarItem(
              title: Text("Categories"),
              icon: Icon(Icons.category)
          ),
          BottomNavigationBarItem(
              title: Text("Settings"),
              icon: Icon(Icons.settings)
          ),
        ]
      )
      );
  }
}