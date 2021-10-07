import 'dart:core';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/components/year-picker.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/records/records-day-list.dart';
import 'package:piggybank/services/csv-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/feedback-page.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:share_plus/share_plus.dart';
import 'days-summary-box-card.dart';
import 'package:path_provider/path_provider.dart';
import './i18n/records-page.i18n.dart';
import 'package:launch_review/launch_review.dart';
import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';

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


  List<Record> records = new List();
  DatabaseInterface database = ServiceConfig.database;
  DateTime _from;
  DateTime _to;
  String _header;

  Future<bool> isThereSomeCategory() async {
    var categories = await database.getAllCategories();
    return categories.length > 0;
  }


  RateMyApp _rateMyApp = RateMyApp(
    preferencesPrefix: "rateMyApp_",
    minDays: 3,
    minLaunches: 7,
    remindDays: 2,
    remindLaunches: 5,
  );

  @override
  void initState() {
    super.initState();
    DateTime _now = DateTime.now();
    _header = getMonthStr(_now);

    RecurrentRecordService().updateRecurrentRecords().then((_) {
      getRecordsByMonth(_now.year, _now.month).then((fetchedRecords) {
        setState(() {
          records = fetchedRecords;
        });
      });
    });

    // Rate my App
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rateMyApp.init().then((_) {
        if ( _rateMyApp.shouldOpenDialog) {
          _rateMyApp.showStarRateDialog(context,
            title: 'Rate this app'.i18n,
            // The dialog title.
            message: "If you like this app, please take a little bit of your time to review it !\nIt really helps us and it shouldn\'t take you more than one minute.".i18n,
            actionsBuilder: (context,
                stars) { // Triggered when the user updates the star rating.
              return [
                // Return a list of actions (that will be shown at the bottom of the dialog).
                FlatButton(
                  child: Text('OK'),
                  onPressed: () async {
                    var starsNumber = stars == null ? 0 : stars.round();
                    print('Thanks for the ' + (stars == null ? '0' : stars
                        .round().toString()) + ' star(s) !');
                    // You can handle the result as you want (for instance if the user puts 1 star then open your contact page, if he puts more then open the store page, etc...).
                    // This allows to mimic the behavior of the default "Rate" button. See "Advanced > Broadcasting events" for more information :
                    Navigator.pop<RateMyAppDialogButton>(
                        context, RateMyAppDialogButton.rate);
                    if (starsNumber <= 3) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => FeedbackPage()),
                      );
                      await _rateMyApp.callEvent(
                          RateMyAppEventType.noButtonPressed);
                    } else {
                      LaunchReview.launch();
                      await _rateMyApp.callEvent(
                          RateMyAppEventType.rateButtonPressed);
                    }
                    //Navigator.of(context, rootNavigator: true).pop('dialog');
                  },
                ),
              ];
            },
            // Set to false if you want to show the native Apple app rating dialog on iOS.
            dialogStyle: DialogStyle( // Custom dialog styles.
              titleAlign: TextAlign.center,
              messageAlign: TextAlign.center,
              messagePadding: EdgeInsets.only(bottom: 20),
            ),
            starRatingOptions: StarRatingOptions(),
            // Custom star bar rating options.
            onDismissed: () =>
                _rateMyApp.callEvent(RateMyAppEventType
                    .laterButtonPressed), // Called when the user dismissed the dialog (either by taping outside or by pressing the "back" button).
          );
        }
      });
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
    /// Open the dialog to pick a Month
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
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
  }

  pickYear() async {
    /// Open the dialog to pick a Year
    DateTime currentDate = DateTime.now();
    DateTime lastDate = DateTime(currentDate.year, 1);
    DateTime firstDate = DateTime(currentDate.year - 5, currentDate.month);
    DateTime yearPicked = await showYearPicker(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: lastDate, context: context,
    );
    if (yearPicked != null) {
      DateTime from = DateTime(yearPicked.year, 1, 1);
      DateTime to = DateTime(yearPicked.year, 12, 31, 23, 59);
      var newRecords = await getRecordsByInterval(from, to);
      setState(() {
        _from = from;
        _to = to;
        _header = getDateRangeStr(_from, _to);
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
  }

  pickDateRange() async {
    /// Open the dialog to pick a date range
    DateTime currentDate = DateTime.now();
    DateTime firstDate = DateTime(currentDate.year - 5, currentDate.month);
    DateTimeRange initialDateTimeRange = DateTimeRange(start: DateTime.now().subtract(Duration(days: 7)), end: currentDate);
    DateTimeRange dateTimeRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: currentDate,
      initialDateRange: initialDateTimeRange,
      locale: I18n.forcedLocale, // do not change, it has some bug if not used forced locale
    );
    if (dateTimeRange != null) {
      var startDate = DateTime(dateTimeRange.start.year, dateTimeRange.start.month, dateTimeRange.start.day);
      var endDate = DateTime(dateTimeRange.end.year, dateTimeRange.end.month, dateTimeRange.end.day, 23, 59);
      var newRecords = await getRecordsByInterval(startDate, endDate);
      setState(() {
        _from = startDate;
        _to = endDate;
        _header = getDateRangeStr(_from, _to);
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
  }

  goToPremiumSplashScreen() async {
    Navigator.of(context, rootNavigator: true).pop('dialog'); // close the dialog
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScren()),
    );
  }

  _buildSelectDateDialog() {
    return SimpleDialog(
        title: Text('Shows records per'.i18n),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () async { return await pickMonth(); },
            child: ListTile(
              title: Text("Month".i18n),
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
              onPressed: ServiceConfig.isPremium ? pickYear : goToPremiumSplashScreen,
              child: ListTile(
                title: Text("Year".i18n),
                subtitle: !ServiceConfig.isPremium ? Text("Available on Piggybank Pro".i18n) : null,
                enabled: ServiceConfig.isPremium,
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
          onPressed: ServiceConfig.isPremium ? pickDateRange : goToPremiumSplashScreen,
          child: ListTile(
            title: Text("Date Range".i18n),
            subtitle: !ServiceConfig.isPremium ? Text("Available on Piggybank Pro".i18n) : null,
            enabled: ServiceConfig.isPremium,
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

  updateRecurrentRecordsAndFetchRecords() async {
    /// Refetch the list of movements in the selected range
    /// from the database. We call this method all the times we land back to
    /// this page after have visited the page add-movement.
    var recurrentRecordService = RecurrentRecordService();
    await recurrentRecordService.updateRecurrentRecords();
    var newRecords = await getRecordsByInterval(_from, _to);
    setState(() {
      records = newRecords;
    });
  }

  navigateToAddNewMovementPage() async {
    /// Navigate to CategoryTabPageView (first step for adding new movement)
    /// Refetch the movements from db where it returns.
    var categoryIsSet = await isThereSomeCategory();
    if (categoryIsSet) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CategoryTabPageView(goToEditMovementPage: true,)),
      );
      await updateRecurrentRecordsAndFetchRecords();
    } else {
      AlertDialogBuilder noCategoryDialog = AlertDialogBuilder("No Category is set yet.".i18n)
          .addTrueButtonName("OK")
          .addSubtitle("You need to set a category first. Go to Category tab and add a new category.".i18n);
      await showDialog(context: context, builder: (BuildContext context) {
        return noCategoryDialog.build(context);
      });
    }
  }

  navigateToStatisticsPage() {
    /// Navigate to the Statistics Page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StatisticsPage(_from, _to, records)),
    );
  }

  onTabChange() async {
    // Navigator.of(context).popUntil((route) => route.isFirst);
    await updateRecurrentRecordsAndFetchRecords();
  }

  AssetImage getBackgroundImage() {
    if (!ServiceConfig.isPremium) {
      return AssetImage('assets/background.jpg');
    } else {
      try {
        var now = DateTime.now();
        String month = now.month.toString();
        return AssetImage('assets/bkg_' + month + '.jpg');
      } on Exception catch (_) {
        return AssetImage('assets/background.jpg');
      }
    }
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
              PopupMenuButton<int>(
                onSelected: (index) async {
                  if (index == 1) {
                    var csvStr = CSVExporter.createCSVFromRecordList(this.records);
                    final path = await getApplicationDocumentsDirectory();
                    var backupJsonOnDisk = File(path.path + "/records.csv");
                    await backupJsonOnDisk.writeAsString(csvStr);
                    Share.shareFiles([backupJsonOnDisk.path]);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return {"Export CSV".i18n: 1}.entries.map((entry) {
                    return PopupMenuItem<int>(
                      value: entry.value,
                      child: Text(entry.key),
                    );
                  }).toList();
                },
              ),
            ],
            pinned: true,
            expandedHeight: 150,
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
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.srcATop),
                  child: Container(
                    decoration:
                    BoxDecoration(
                        image: DecorationImage(
                            fit: BoxFit.cover,
                            image: getBackgroundImage()))
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
                      child: DaysSummaryBox(records)
                  ),
                  Divider(indent: 50, endIndent: 50),
                  records.length == 0 ? Container(
                      child: Column(
                        children: <Widget>[
                          Image.asset(
                              'assets/no_entry.png', width: 200,
                          ),
                          Text("No entries yet.".i18n,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.0,) ,)
                        ],
                      )
                  ) : Container(
                    child: new RecordsDayList(records, onListBackCallback: updateRecurrentRecordsAndFetchRecords,),
                  ),
                  SizedBox(height: 75),
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () async => await navigateToAddNewMovementPage(),
          tooltip: 'Add a new record'.i18n,
          label: Text('Add'.i18n),
          icon: const Icon(Icons.add),
        ),
      );
  }

}