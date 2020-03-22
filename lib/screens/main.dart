
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

import 'movements-group.dart';

class RandomMovements extends StatefulWidget {
  @override
  RandomMovementsState createState() => RandomMovementsState();
}

class RandomMovementsState extends State<RandomMovements> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);
  final Set<Movement> _saved = Set<Movement>();

  Widget _buildDays() {
    return ListView.separated(
      separatorBuilder: (context, index) {
        return Divider();
      },
      itemCount: MovementsInMemoryDatabase.movementsDays.length,
      padding: const EdgeInsets.all(6.0),
      itemBuilder: /*1*/ (context, i) {
        return MovementsGroupCard(MovementsInMemoryDatabase.movementsDays[i]);
      });
  }

  List<Widget> _getTagList(Movement movement) {
    List<Widget> list = new List<Widget>();
    for(var tag in movement.tags) {
      var tagContainer = Container(
        child: Text(tag.name),
        color: tag.color,
      );
      list.add(tagContainer);
    }
    return list;
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final Iterable<ListTile> tiles = _saved.map(
                (Movement pair) {
              return ListTile(
                title: Text(
                  pair.description,
                  style: _biggerFont,
                ),
              );
            },
          );
          final List<Widget> divided = ListTile
              .divideTiles(
            context: context,
            tiles: tiles,
          )
              .toList();
          return Scaffold(         // Add 6 lines from here...
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );                       // ... to here.
        },
      ),
    );
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
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            margin: const EdgeInsets.all(10),
            height: 100,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.amber,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
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