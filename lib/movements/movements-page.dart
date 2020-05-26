
import 'dart:collection';
import 'dart:core';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';
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

  Future<List<MovementsPerDay>> getMovementsByMonth(int year, int month) async {
    /// Returns the list of movements of a given month identified by
    /// :year and :month integers.
    _from = new DateTime(year, month, 1);
    DateTime lastDayOfMonths = (_from.month < 12) ? new DateTime(_from.year, _from.month + 1, 0) : new DateTime(_from.year + 1, 1, 0);
    _to = lastDayOfMonths.add(Duration(hours: 23, minutes: 59));
    return await getMovementsDaysDateTime(_from, _to);
  }

  String getMonthHeader(DateTime dateTime) {
    /// Returns the header string identifying the current visualised month.
    Locale myLocale = I18n.locale;
    String localeRepr = DateFormat.yMMMM(myLocale.languageCode).format(dateTime);
    return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
  }

  List<MovementsPerDay> _daysShown = new List();
  DatabaseService database = new InMemoryDatabase();
  DateTime _from;
  DateTime _to;
  String _header;

  @override
  void initState() {
    super.initState();
    DateTime _now = DateTime.now();
    _header = getMonthHeader(_now);
    getMovementsByMonth(_now.year, _now.month).then((movementsDay) => {
      _daysShown = movementsDay
    });
  }

  Widget _buildDaysList() {
    /// Creates the list-view of MovementsGroup cards
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _daysShown.length,
      padding: const EdgeInsets.all(6.0),
      itemBuilder: /*1*/ (context, i) {
        return MovementsGroupCard(_daysShown[i], fetchMovementsFromDb);
      });
  }

  fetchMovementsFromDb() async {
    /// Refetch the list of movements in the selected range
    /// from the database. We call this method all the times we land back to
    /// this page after have visited the page add-movement.
    var newMovements = await getMovementsDaysDateTime(_from, _to);
    setState(() {
      _daysShown = newMovements;
    });
  }

  navigateToAddNewMovementPage() async {
    /// Navigate to CategoryTabPageView (first step for adding new movement)
    /// Refetch the movements from db where it returns.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryTabPageView(goToEditMovementPage: true,)),
    );
    await fetchMovementsFromDb();
  }

  navigateToStatisticsPage() {
    /// Navigate to the Statistics Page
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
              title: Text(_header, style: TextStyle(color: Colors.white)),
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
                    child: _buildDaysList(),
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