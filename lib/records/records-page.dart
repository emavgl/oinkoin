import 'dart:core';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/components/year-picker.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/records/records-day-list.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/csv-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/records-utility-functions.dart';
import 'days-summary-box-card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/i18n.dart';
import 'dart:io';

class TabRecords extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  TabRecords({Key? key}) : super(key: key);

  @override
  TabRecordsState createState() => TabRecordsState();
}

class TabRecordsState extends State<TabRecords> {
  List<Record?> records = [];
  DatabaseInterface database = ServiceConfig.database;
  String _header = "";

  // Datetime defining a custom time interval
  // Normally null, but if the user change the interval
  // they are set and eventually used in updateRecurrentRecordsAndFetchRecords
  DateTime? _customIntervalFrom;
  DateTime? _customIntervalTo;

  final GlobalKey<CategoryTabPageViewState> _categoryTabPageViewStateKey =
      GlobalKey();

  Future<bool> isThereSomeCategory() async {
    var categories = await database.getAllCategories();
    return categories.length > 0;
  }

  @override
  void initState() {
    super.initState();
    RecurrentRecordService().updateRecurrentRecords().then((_) {
      getRecordsByUserDefinedInterval(database).then((fetchedRecords) {
        setState(() {
          records = fetchedRecords;
          _header = getHeaderForUserDefinedInterval();
        });
        BackupService.createAutomaticBackup().then((_) {
          BackupService.removeOldAutomaticBackups();
        });
      });
    });
  }

  Future<void> _showSelectDateDialog() async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return _buildSelectDateDialog();
        });
  }

  pickMonth() async {
    /// Open the dialog to pick a Month
    DateTime? currentDate = _customIntervalFrom ?? DateTime.now();
    int currentYear = DateTime.now().year;
    DateTime? dateTime = await showMonthPicker(
      context: context,
      lastDate: DateTime(currentYear + 1, 12),
      initialDate: currentDate,
      locale: I18n.locale,
    );
    if (dateTime != null) {
      _customIntervalFrom = new DateTime(dateTime.year, dateTime.month, 1);
      _customIntervalTo = getEndOfMonth(dateTime.year, dateTime.month);
      var newRecords =
          await getRecordsByMonth(database, dateTime.year, dateTime.month);
      setState(() {
        _header = getMonthStr(dateTime);
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true)
        .pop('dialog'); // close the dialog
  }

  pickYear() async {
    /// Open the dialog to pick a Year
    DateTime currentDate = DateTime.now();
    DateTime initialDate = DateTime(currentDate.year, 1);
    DateTime lastDate = DateTime(currentDate.year + 1, 1);
    DateTime firstDate = DateTime(1950, currentDate.month);
    DateTime? yearPicked = await showYearPicker(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      context: context,
    );
    if (yearPicked != null) {
      _customIntervalFrom = new DateTime(yearPicked.year, 1, 1);
      _customIntervalTo = new DateTime(yearPicked.year, 12, 31, 23, 59);
      var newRecords = await getRecordsByYear(database, yearPicked.year);
      setState(() {
        _header = getDateRangeStr(_customIntervalFrom!, _customIntervalTo!);
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true)
        .pop('dialog'); // close the dialog
  }

  pickDateRange() async {
    /// Open the dialog to pick a date range
    DateTime currentDate = DateTime.now();
    DateTime lastDate = DateTime(currentDate.year + 1, currentDate.month + 1);
    DateTime firstDate = DateTime(currentDate.year - 5, currentDate.month);
    DateTimeRange initialDateTimeRange = DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 7)), end: currentDate);
    DateTimeRange? dateTimeRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateTimeRange,
      locale: I18n
          .forcedLocale, // do not change, it has some bug if not used forced locale
    );
    if (dateTimeRange != null) {
      _customIntervalFrom = DateTime(dateTimeRange.start.year,
          dateTimeRange.start.month, dateTimeRange.start.day);
      _customIntervalTo = DateTime(dateTimeRange.end.year,
          dateTimeRange.end.month, dateTimeRange.end.day, 23, 59);
      var newRecords = await getRecordsByInterval(
          database, _customIntervalFrom, _customIntervalTo);
      setState(() {
        _header = getDateRangeStr(_customIntervalFrom!, _customIntervalTo!);
        records = newRecords;
      });
    }
    Navigator.of(context, rootNavigator: true)
        .pop('dialog'); // close the dialog
  }

  goToPremiumSplashScreen() async {
    Navigator.of(context, rootNavigator: true)
        .pop('dialog'); // close the dialog
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScreen()),
    );
  }

  _buildSelectDateDialog() {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    var boxBackgroundColor = isDarkMode
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondary;
    return SimpleDialog(
      title: Text('Shows records per'.i18n),
      children: <Widget>[
        SimpleDialogOption(
            onPressed: () async {
              return await pickMonth();
            },
            child: ListTile(
              title: Text("Month".i18n),
              leading: Container(
                  width: 40,
                  height: 40,
                  child: Icon(
                    FontAwesomeIcons.calendarDays,
                    size: 20,
                    color: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: boxBackgroundColor,
                  )),
            )),
        SimpleDialogOption(
            onPressed:
                ServiceConfig.isPremium ? pickYear : goToPremiumSplashScreen,
            child: ListTile(
              title: Text("Year".i18n),
              subtitle: !ServiceConfig.isPremium
                  ? Text("Available on Oinkoin Pro".i18n)
                  : null,
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
                    color: boxBackgroundColor,
                  )),
            )),
        SimpleDialogOption(
            onPressed: ServiceConfig.isPremium
                ? pickDateRange
                : goToPremiumSplashScreen,
            child: ListTile(
              title: Text("Date Range".i18n),
              subtitle: !ServiceConfig.isPremium
                  ? Text("Available on Oinkoin Pro".i18n)
                  : null,
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
                    color: boxBackgroundColor,
                  )),
            )),
        Visibility(
          visible: _customIntervalFrom != null, // custom time was chosen
          child: SimpleDialogOption(
              onPressed: () async {
                _customIntervalFrom = null;
                _customIntervalTo = null;
                await updateRecurrentRecordsAndFetchRecords();
                Navigator.of(context, rootNavigator: true)
                    .pop('dialog'); // close the dialog
              },
              child: ListTile(
                title: Text("Reset to default dates".i18n),
                leading: Container(
                    width: 40,
                    height: 40,
                    child: Icon(
                      FontAwesomeIcons.calendarXmark,
                      size: 20,
                      color: Colors.white,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: boxBackgroundColor,
                    )),
              )),
        )
      ],
    );
  }

  updateRecurrentRecordsAndFetchRecords() async {
    /// Refetch the list of movements in the selected range
    /// from the database. We call this method all the times we land back to
    /// this page after have visited the page add-movement.
    var recurrentRecordService = RecurrentRecordService();
    await recurrentRecordService.updateRecurrentRecords();
    List<Record?> newRecords;
    if (_customIntervalFrom != null) {
      // A custom interval got chosen
      newRecords = await getRecordsByInterval(
          database, _customIntervalFrom, _customIntervalTo);
    } else {
      // Use the pre-defined choice of the user
      newRecords = await getRecordsByUserDefinedInterval(database);

      // Need to change the header also here
      // Since the user can define a new settings and come back to this page
      setState(() {
        _header = getHeaderForUserDefinedInterval();
      });
    }
    setState(() {
      records = newRecords;
    });
  }

  navigateToAddNewMovementPage() async {
    /// Navigate to CategoryTabPageView (first step for adding new movement)
    /// Refresh the movements from db where it returns.
    var categoryIsSet = await isThereSomeCategory();
    if (categoryIsSet) {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CategoryTabPageView(
                  goToEditMovementPage: true,
                  key: _categoryTabPageViewStateKey,
                )),
      );
      await updateRecurrentRecordsAndFetchRecords();
    } else {
      AlertDialogBuilder noCategoryDialog = AlertDialogBuilder(
              "No Category is set yet.".i18n)
          .addTrueButtonName("OK")
          .addSubtitle(
              "You need to set a category first. Go to Category tab and add a new category.".i18n);
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return noCategoryDialog.build(context);
          });
    }
  }

  navigateToStatisticsPage() {
    /// Navigate to the Statistics Page
    if (_customIntervalTo == null) {
      getUserDefinedInterval(database).then((userDefinedInterval) =>
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    StatisticsPage(userDefinedInterval[0], userDefinedInterval[1], records)),
          )
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                StatisticsPage(_customIntervalFrom, _customIntervalTo, records)),
      );
    }
  }

  onTabChange() async {
    // Navigator.of(context).popUntil((route) => route.isFirst);
    await updateRecurrentRecordsAndFetchRecords();
    await _categoryTabPageViewStateKey.currentState?.refreshCategories();
  }

  @override
  Widget build(BuildContext context) {
    double headerFontSize = _header.length > 13 ? 18 : 22;
    double headerPaddingBottom = _header.length > 13 ? 15 : 13;
    return Scaffold(
      body: new CustomScrollView(slivers: [
        SliverAppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
          actions: <Widget>[
            IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () async => await _showSelectDateDialog(),
                color: Colors.white),
            IconButton(
                icon: Icon(Icons.donut_small),
                onPressed: () => navigateToStatisticsPage(),
                color: Colors.white),
            PopupMenuButton<int>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(10.0),
                ),
              ),
              onSelected: (index) async {
                if (index == 1) {
                  var csvStr =
                      CSVExporter.createCSVFromRecordList(this.records);
                  final path = await getApplicationDocumentsDirectory();
                  var backupJsonOnDisk = File(path.path + "/records.csv");
                  await backupJsonOnDisk.writeAsString(csvStr);
                  Share.shareFiles([backupJsonOnDisk.path]);
                }
              },
              itemBuilder: (BuildContext context) {
                return {"Export CSV".i18n: 1}.entries.map((entry) {
                  return PopupMenuItem<int>(
                    padding: EdgeInsets.all(20),
                    value: entry.value,
                    child: Text(entry.key,
                        style: TextStyle(
                          fontSize: 16,
                        )),
                  );
                }).toList();
              },
            ),
          ],
          pinned: true,
          expandedHeight: 180,
          flexibleSpace: FlexibleSpaceBar(
              stretchModes: <StretchMode>[
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
                StretchMode.fadeTitle,
              ],
              centerTitle: false,
              titlePadding:
                  EdgeInsets.fromLTRB(15, 15, 15, headerPaddingBottom),
              title: Text(_header,
                  style:
                      TextStyle(color: Colors.white, fontSize: headerFontSize)),
              background: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.1), BlendMode.srcATop),
                  child: Container(
                      decoration: BoxDecoration(
                          image: DecorationImage(
                              fit: BoxFit.cover,
                              image: getBackgroundImage()))))),
        ),
        SliverList(
            delegate: SliverChildListDelegate(
          [
            Container(
                margin: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                height: 100,
                child: DaysSummaryBox(records)),
            Divider(indent: 50, endIndent: 50),
            records.length == 0
                ? Container(
                    child: Column(
                    children: <Widget>[
                      Image.asset(
                        'assets/images/no_entry.png',
                        width: 200,
                      ),
                      Text(
                        "No entries yet.".i18n,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22.0,
                        ),
                      )
                    ],
                  ))
                : Container()
          ],
        )),
        RecordsDayList(
          records,
          onListBackCallback: updateRecurrentRecordsAndFetchRecords,
        ),
        SliverList(
            delegate: SliverChildListDelegate([
          SizedBox(
            height: 75,
          )
        ]))
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => await navigateToAddNewMovementPage(),
        tooltip: 'Add a new record'.i18n,
        child: const Icon(Icons.add),
      ),
    );
  }
}
