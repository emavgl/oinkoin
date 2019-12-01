
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movement.dart';

class RandomMovements extends StatefulWidget {
  @override
  RandomMovementsState createState() => RandomMovementsState();
}

class RandomMovementsState extends State<RandomMovements> {
  final _movements = <Movement>[];
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final Set<Movement> _saved = Set<Movement>();

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return Divider(); /*2*/
          final index = i ~/ 2; /*3*/
          if (index >= _movements.length) {
            _movements.addAll(MovementsGenerator.getRandomMovements().take(10)); /*4*/
          }
          return _buildRow(_movements[index]);
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movements'),
        actions: <Widget>[      // Add 3 lines from here...
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
        ],
      ),
      body: _buildSuggestions(),
    );
  }
}