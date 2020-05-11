
import 'dart:core';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/movements/days-summary-box-card.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/movements/edit-movement-page.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import './i18n/movements-page.i18n.dart';

import 'movements-group-card.dart';
import "package:collection/collection.dart";

class MovementsPage extends StatefulWidget {

  @override
  MovementsPageState createState() => MovementsPageState();
}

class MovementsPageState extends State<MovementsPage> {

  Future<List<MovementsPerDay>> getMovementsDaysDateTime( _from, DateTime _to) async {
    List<Movement> _movements = await database.getAllMovementsInInterval(_from, _to);
    var movementsGroups = groupBy(_movements, (movement) => movement.date);
    List<MovementsPerDay> movementsPerDay = List();
    movementsGroups.forEach((k, groupedMovements) {
      if (groupedMovements.isNotEmpty) {
        DateTime groupedDay = groupedMovements[0].dateTime;
        movementsPerDay.add(new MovementsPerDay(groupedDay, movements: groupedMovements));
      }
    });
    return movementsPerDay;
  }

  List<MovementsPerDay> _daysShown = new List();
  DatabaseService database = new InMemoryDatabase();

  @override
  void initState() {
    super.initState();

    // get movements given a range
    DateTime _from = DateTime.parse("2020-05-01 00:01:00");
    DateTime _to = DateTime.parse("2020-06-01 00:00:00");
    getMovementsDaysDateTime(_from, _to).then((movementsDay) => {
      _daysShown = movementsDay
    });
  }

  Widget _buildDays() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
      title: Text("My title".i18n),
      content: Text("This is my message.".i18n),
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

  // TODO why do you make the transition from on screen to the other async? the cookbook (https://flutter.dev/docs/cookbook/navigation/navigation-basics) does not mention it
  navigateToAddNewMovementPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditMovementPage()),
    );
  }

  navigateToStatisticsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StatisticsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: new CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).primaryColor,
            actions: <Widget>[
              IconButton(icon: Icon(Icons.calendar_today), onPressed: (){}, color: Colors.white),
              IconButton(icon: Icon(Icons.donut_small), onPressed: () => navigateToStatisticsPage(), color: Colors.white),
              IconButton(icon: Icon(Icons.filter_list), onPressed: (){}, color: Colors.white)
            ],
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: <StretchMode>[
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
                StretchMode.fadeTitle,
              ],
              centerTitle: false,
              titlePadding: EdgeInsets.all(15),
              title: Text('April'.i18n + ' 2020', style: TextStyle(color: Colors.white)),
              background: ColorFiltered(
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.8), BlendMode.dstATop),
                  child: Container(
                    decoration:
                    BoxDecoration(
                        image: DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage("https://papers.co/wallpaper/papers.co-ag84-google-lollipop-march-mountain-background-6-wallpaper.jpg")))
                  )
              )
            ),
          ),
          SliverToBoxAdapter(
            child: new ConstrainedBox(
              constraints: new BoxConstraints(),
              child: new Column(
                children: <Widget>[
                  Container(
                      margin: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                      height: 100,
                      child: DaysSummaryBox(_daysShown)
                  ),
                  Divider(indent: 50, endIndent: 50),
                  Container(
                    child: _buildDays(),
                  )
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => await navigateToAddNewMovementPage(),
        tooltip: 'Add new movement',
        child: const Icon(Icons.add),
      ),
      );
  }
}