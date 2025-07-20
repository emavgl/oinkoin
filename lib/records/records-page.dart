import 'dart:core';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/components/year-picker.dart' as yp;
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/records/records-day-list.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/csv-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';
import 'package:piggybank/settings/constants/overview-time-interval.dart';
import 'package:piggybank/statistics/statistics-page.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/records-utility-functions.dart';
import 'days-summary-box-card.dart';

class TabRecords extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  TabRecords({Key? key}) : super(key: key);

  @override
  TabRecordsState createState() => TabRecordsState();
}

class TabRecordsState extends State<TabRecords> {
  List<Record?> records = [];
  List<Record?>? overviewRecords =
      null; // it is important this to be null, meaning records will be used!

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

  late final AppLifecycleListener _listener;
  late AppLifecycleState? _state;

  @override
  void initState() {
    super.initState();
    _state = SchedulerBinding.instance.lifecycleState;
    _listener = AppLifecycleListener(
      onStateChange: _handleOnResume,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateRecurrentRecordsAndFetchRecords();
    });
  }

  // Should handle state change, in particular resumed
  // Reason: if the user keep the app in background for long time
  // but the app it does not close, initState is not fired again
  // and the backup will not be created. So it is important to run
  // also the automaticBackup()
  void _handleOnResume(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) {
      updateRecurrentRecordsAndFetchRecords().then((_) {
        runAutomaticBackup();
      });
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    runAutomaticBackup();
  }

  void runAutomaticBackup() {
    log("Checking if automatic backup should be fired!");
    BackupService.shouldCreateAutomaticBackup().then((shouldBackup) {
      if (shouldBackup) {
        log("Automatic backup fired!");
        BackupService.createAutomaticBackup().then((operationSuccess) {
          if (!operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(BackupService.ERROR_MSG),
            ));
          } else {
            BackupService.removeOldAutomaticBackups();
          }
        });
      } else {
        log("Automatic backup not needed.");
      }
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
        initialDate: currentDate);
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
    DateTime? yearPicked = await yp.showYearPicker(
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
        _header = getYearStr(_customIntervalFrom!);
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
        locale: I18n.locale);
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
      var hti = getHomepageTimeIntervalEnumSetting();

      // Use the pre-defined choice of the user
      newRecords = await getRecordsByHomepageTimeInterval(database, hti);

      // Need to change the header also here
      // Since the user can define a new settings and come back to this page
      setState(() {
        _header = getHeaderFromHomepageTimeInterval(hti);
      });
    }
    setState(() {
      records = newRecords;
    });
    OverviewTimeInterval overviewTimeIntervalEnum =
        getHomepageOverviewWidgetTimeIntervalEnumSetting();
    if (overviewTimeIntervalEnum != OverviewTimeInterval.DisplayedRecords) {
      HomepageTimeInterval recordTimeIntervalEnum =
          mapOverviewTimeIntervalToHomepageTimeInterval(
              overviewTimeIntervalEnum);
      var fetchedRecords = await getRecordsByHomepageTimeInterval(
          database, recordTimeIntervalEnum);
      setState(() {
        overviewRecords = fetchedRecords;
      });
    }
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
              "You need to set a category first. Go to Category tab and add a new category."
                  .i18n);
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
      var hti = getHomepageTimeIntervalEnumSetting();
      getTimeIntervalFromHomepageTimeInterval(database, hti)
          .then((userDefinedInterval) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => StatisticsPage(userDefinedInterval[0],
                        userDefinedInterval[1], records)),
              ));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => StatisticsPage(
                _customIntervalFrom, _customIntervalTo, records)),
      );
    }
  }

  onTabChange() async {
    // Navigator.of(context).popUntil((route) => route.isFirst);
    await updateRecurrentRecordsAndFetchRecords();
    await _categoryTabPageViewStateKey.currentState?.refreshCategories();
  }

  bool _isAppBarExpanded = true;

  @override
  Widget build(BuildContext context) {
    double headerFontSize = _header.length > 13 ? 18 : 22;
    double headerPaddingBottom = _header.length > 13 ? 15 : 13;

    bool canShiftBack = canShift(-1, _customIntervalFrom, _customIntervalTo,
        getHomepageTimeIntervalEnumSetting());

    bool canShiftForward = canShift(1, _customIntervalFrom, _customIntervalTo,
        getHomepageTimeIntervalEnumSetting());

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          setState(() {
            _isAppBarExpanded = scrollInfo.metrics.pixels < 100;
          });
          return true;
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).primaryColor,
            actions: <Widget>[
              IconButton(
                  icon: Semantics(
                      identifier: 'select-date',
                      child: Icon(Icons.calendar_today)),
                  onPressed: () async => await _showSelectDateDialog(),
                  color: Colors.white),
              IconButton(
                  icon: Semantics(
                      identifier: 'statistics', child: Icon(Icons.donut_small)),
                  onPressed: () => navigateToStatisticsPage(),
                  color: Colors.white),
              PopupMenuButton<int>(
                icon: Semantics(
                    identifier: 'three-dots',
                    child: Icon(Icons.more_vert, color: Colors.white)),
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
                    SharePlus.instance.share(
                        ShareParams(files: [XFile(backupJsonOnDisk.path)]));
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
                titlePadding: !_isAppBarExpanded
                    ? EdgeInsets.fromLTRB(15, 15, 15, headerPaddingBottom)
                    : EdgeInsets.fromLTRB(canShiftBack ? 0 : 15, 15,
                        canShiftForward ? 0 : 15, headerPaddingBottom),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (_isAppBarExpanded && canShiftBack)
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: IconButton(
                          icon: Icon(Icons.arrow_left,
                              color: Colors.white, size: 24),
                          onPressed: () async => shiftMonthOrYear(-1),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ),
                    Expanded(
                      child: Semantics(
                        identifier: 'date-text',
                        child: Text(
                          _header,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: Colors.white, fontSize: headerFontSize),
                        ),
                      ),
                    ),
                    if (_isAppBarExpanded && canShiftForward)
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: IconButton(
                          icon: Icon(Icons.arrow_right,
                              color: Colors.white, size: 24),
                          onPressed: () async => shiftMonthOrYear(1),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ),
                  ],
                ),
                background: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.1), BlendMode.srcATop),
                    child: Container(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                fit: BoxFit.cover,
                                image: getBackgroundImage()))))),
          ),
          SliverList(
              delegate: SliverChildListDelegate([
            Container(
                margin: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                height: 100,
                child: DaysSummaryBox(overviewRecords ?? records)),
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
          ])),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => await navigateToAddNewMovementPage(),
        tooltip: 'Add a new record'.i18n,
        child: Semantics(
          identifier: 'add-record',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void shiftMonthOrYear(int shift) async {
    DateTime newFrom;
    DateTime newTo;
    List<Record?> newRecords = [];
    String newHeader;
    if (_customIntervalFrom != null) {
      if (isFullMonth(_customIntervalFrom!, _customIntervalTo!)) {
        newFrom = DateTime(
            _customIntervalFrom!.year, _customIntervalFrom!.month + shift, 1);
        newTo = getEndOfMonth(newFrom.year, newFrom.month);
        newHeader = getMonthStr(newFrom);
        newRecords =
            await getRecordsByMonth(database, newFrom.year, newFrom.month);
      } else {
        // Is full-year
        newFrom = DateTime(_customIntervalFrom!.year + shift, 1, 1);
        newTo = new DateTime(newFrom.year, 12, 31, 23, 59);
        newRecords = await getRecordsByYear(database, newFrom.year);
        newHeader = getYearStr(newFrom);
      }
    } else {
      HomepageTimeInterval hti = getHomepageTimeIntervalEnumSetting();
      DateTime d = DateTime.now();
      if (hti == HomepageTimeInterval.CurrentMonth) {
        newFrom = DateTime(d.year, d.month + shift, 1);
        newTo = getEndOfMonth(newFrom.year, newFrom.month);
        newHeader = getMonthStr(newFrom);
        newRecords =
            await getRecordsByMonth(database, newFrom.year, newFrom.month);
      } else {
        // hti == CurrentYear
        newFrom = DateTime(d.year + shift, 1, 1);
        newTo = new DateTime(newFrom.year, 12, 31, 23, 59);
        newRecords = await getRecordsByYear(database, newFrom.year);
        newHeader = getYearStr(newFrom);
      }
    }
    setState(() {
      _customIntervalFrom = newFrom;
      _customIntervalTo = newTo;
      _header = newHeader;
      records = newRecords;
    });
  }
}
