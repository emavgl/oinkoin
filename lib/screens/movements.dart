
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

class RandomMovements extends StatefulWidget {
  @override
  RandomMovementsState createState() => RandomMovementsState();
}

class RandomMovementsState extends State<RandomMovements> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);
  final Set<Movement> _saved = Set<Movement>();

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return Divider(); /*2*/
          final index = i ~/ 2; /*3*/
          if (index >= MovementsInMemoryDatabase.movements.length) {
            // TODO: change, this is just to show how to build an infinite/auto-reloading list
            MovementsInMemoryDatabase.movements.addAll(MovementsGenerator.getRandomMovements().take(10)); /*4*/
          }
          return _buildRow(MovementsInMemoryDatabase.movements[index]);
        });
  }

  Widget _buildRow(Movement movement) {
    final bool alreadySaved = _saved.contains(movement);
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
        setState(() {
          if (alreadySaved) {
            _saved.remove(movement);
          } else {
            _saved.add(movement);
          }
        });
      },
    );
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
            child: _buildSuggestions(),
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