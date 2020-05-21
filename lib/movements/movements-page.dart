
import 'dart:collection';
import 'dart:core';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
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
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  @override
  MovementsPageState createState() => MovementsPageState();
}

class MovementsPageState extends State<MovementsPage> {

  Future<List<MovementsPerDay>> getMovementsDaysDateTime(DateTime _from, DateTime _to) async {
    /// Fetches from the database all the movements between the two dates _from and _to.
    /// The movements are then grouped in days using the object MovementsPerDay.
    /// It returns a list of MovementsPerDay object, containing at least 1 movement.
    List<Movement> _movements = await database.getAllMovementsInInterval(_from, _to);
    var movementsGroups = groupBy(_movements, (movement) => movement.date);
    Queue<MovementsPerDay> movementsPerDay = Queue();
    movementsGroups.forEach((k, groupedMovements) {
      if (groupedMovements.isNotEmpty) {
        DateTime groupedDay = groupedMovements[0].dateTime;
        movementsPerDay.addFirst(new MovementsPerDay(groupedDay, movements: groupedMovements));
      }
    });
    return movementsPerDay.toList();
  }

  List<MovementsPerDay> _daysShown = new List();
  DatabaseService database = new InMemoryDatabase();

  // TODO: change the hard-coded date
  DateTime _from = DateTime.parse("2020-05-01 00:01:00");
  DateTime _to = DateTime.parse("2020-06-01 00:00:00");

  @override
  void initState() {
    super.initState();
    getMovementsDaysDateTime(_from, _to).then((movementsDay) => {
      _daysShown = movementsDay
    });
  }

  Widget _buildDays() {
    /// Creates the list-view of MovementsGroup cards
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _daysShown.length,
      padding: const EdgeInsets.all(6.0),
      itemBuilder: /*1*/ (context, i) {
        return MovementsGroupCard(_daysShown[i]);
      });
  }

  navigateToAddNewMovementPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryTabPageView()),
    );
    var newMovements = await getMovementsDaysDateTime(_from, _to);
    setState(() {
      _daysShown = newMovements;
    });
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
              title: Text('May'.i18n + ' 2020', style: TextStyle(color: Colors.white)),
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