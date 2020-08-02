import 'dart:collection';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/components/year-picker.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/records-per-day-card.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'days-summary-box-card.dart';
import "package:collection/collection.dart";

class RecordsPage extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  RecordsPage({Key key}) : super(key: key);

  @override
  RecordsPageState createState() => RecordsPageState();
}

class RecordsPageState extends State<RecordsPage> {

  Future<List<Record>> getRecordsByInterval(DateTime _from, DateTime _to) async {
    return await database.getAllRecordsInInterval(_from, _to);
  }

  Future<List<Record>> getRecordsByMonth(int year, int month) async {
    /// Returns the list of movements of a given month identified by
    /// :year and :month integers.
    _from = new DateTime(year, month, 1);
    DateTime lastDayOfMonths = (_from.month < 12) ? new DateTime(_from.year, _from.month + 1, 0) : new DateTime(_from.year + 1, 1, 0);
    _to = lastDayOfMonths.add(Duration(hours: 23, minutes: 59));
    return await getRecordsByInterval(_from, _to);
  }

  List<RecordsPerDay> groupRecordsByDay(List<Record> records) {
    /// Groups the record in days using the object MovementsPerDay.
    /// It returns a list of MovementsPerDay object, containing at least 1 movement.
    var movementsGroups = groupBy(records, (records) => records.date);
    Queue<RecordsPerDay> movementsPerDay = Queue();
    movementsGroups.forEach((k, groupedMovements) {
      if (groupedMovements.isNotEmpty) {
        DateTime groupedDay = groupedMovements[0].dateTime;
        movementsPerDay.addFirst(new RecordsPerDay(groupedDay, records: groupedMovements));
      }
    });
    var movementsDayList = movementsPerDay.toList();
    movementsDayList.sort((b, a) => a.dateTime.compareTo(b.dateTime));
    return movementsDayList;
  }

  List<RecordsPerDay> _daysShown = new List();
  List<Record> _records = new List();
  DatabaseInterface database = ServiceConfig.database;
  DateTime _from;
  DateTime _to;
  String _header;

  @override
  void initState() {
    super.initState();
    DateTime _now = DateTime.now();
    _header = getMonthStr(_now);
    getRecordsByMonth(_now.year, _now.month).then((records) {
      setState(() {
        _records = records;
        _daysShown = groupRecordsByDay(records);
      });
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
        return RecordsPerDayCard(_daysShown[i], fetchMovementsFromDb);
      });
  }

  Future<void> _showSelectDateDialog() async {
    await showDialog(
        context: context,
        builder:  (BuildContext context) {
          return _buildSelectDateDialog();
        });
  }

  pickMonth() async {
    DateTime currentDate = _from;
    int currentYear = DateTime.now().year;
    DateTime dateTime = await showMonthPicker(
      context: context,
      firstDate: DateTime(currentYear - 5, 1),
      lastDate: DateTime(currentYear, 12),
      initialDate: currentDate,
      locale: I18n.locale,
    );
    if (dateTime != null) {
      var newRecords = await getRecordsByMonth(dateTime.year, dateTime.month);
      setState(() {
        _header = getMonthStr(_from);
        _records = newRecords;
        _daysShown = groupRecordsByDay(_records);
      });
    }
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
  }

  pickYear() async {
    DateTime currentDate = DateTime.now();
    DateTime lastDate = DateTime(currentDate.year, 1);
    DateTime firstDate = DateTime(currentDate.year - 5, currentDate.month);
    DateTime yearPicked = await showYearPicker(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: lastDate, context: context,
    );
    if (yearPicked != null) {
      DateTime _from = DateTime(yearPicked.year, 1, 1);
      DateTime _to = DateTime(yearPicked.year, 12, 31, 23, 59);
      var newRecords = await getRecordsByInterval(_from, _to);
      setState(() {
        _from = _from;
        _to = _to;
        _header = getDateRangeStr(_from, _to);
        _records = newRecords;
        _daysShown = groupRecordsByDay(_records);
      });
    }
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
  }

  _buildSelectDateDialog() {
    return SimpleDialog(
        title: const Text('Shows records per'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () async { return await pickMonth(); },
            child: ListTile(
              title: Text("Month"),
              leading: Container(
                width: 40,
                height: 40,
                child: Icon(
                  FontAwesomeIcons.calendarAlt,
                  size: 20,
                  color: Colors.white,
                ),
                decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).accentColor,
              )),
            )
          ),
          SimpleDialogOption(
              onPressed: () async { return await pickYear(); },
              child: ListTile(
                title: Text("Year"),
                leading: Container(
                    width: 40,
                    height: 40,
                    child: Icon(
                      FontAwesomeIcons.calendarDay,
                      size: 20,
                      color: Colors.white,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).accentColor,
                    )),
              )
          ),
          SimpleDialogOption(
          onPressed: () {},
          child: ListTile(
            title: Text("Date Range"),
            subtitle: Text("For Premium user only"),
            enabled: false,
            leading: Container(
              width: 40,
              height: 40,
              child: Icon(
              FontAwesomeIcons.calendarWeek,
              size: 20,
              color: Colors.white,
              ),
              decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).accentColor,
              )),
            )
          ),
        ],
      );
  }

  fetchMovementsFromDb() async {
    /// Refetch the list of movements in the selected range
    /// from the database. We call this method all the times we land back to
    /// this page after have visited the page add-movement.
    var newRecords = await getRecordsByInterval(_from, _to);
    setState(() {
      _records = newRecords;
      _daysShown = groupRecordsByDay(_records);
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
      MaterialPageRoute(builder: (context) => StatisticsPage(_from, _to, _records)),
    );
  }

  onTabChange() async {
    // Navigator.of(context).popUntil((route) => route.isFirst);
    await fetchMovementsFromDb();
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
              IconButton(icon: Icon(Icons.calendar_today), onPressed: () async => await _showSelectDateDialog(), color: Colors.white),
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
                            image: AssetImage('assets/background.jpg')))
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
                  _daysShown.length == 0 ? Container(
                      child: Column(
                        children: <Widget>[
                          Image.asset(
                              'assets/no_entry.png', width: 200,
                          ),
                          Text("No entries yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.0,) ,)
                        ],
                      )
                  ) : Container(
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