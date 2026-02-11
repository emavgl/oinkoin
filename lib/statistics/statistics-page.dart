import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-tab-page.dart';
import 'package:piggybank/statistics/balance-tab-page.dart';
import 'package:piggybank/i18n.dart';

class StatisticsPage extends StatefulWidget {
  final List<Record?> records;
  final DateTime? from;
  final DateTime? to;
  StatisticsPage(this.from, this.to, this.records);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  String? _selectedIntervalTitle;
  DateTime? _selectedDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedIntervalTitle = null;
        _selectedDate = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title =
        _selectedIntervalTitle ?? getDateRangeStr(widget.from!, widget.to!);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(title),
              pinned: false,
              floating: false,
              snap: false,
              forceElevated: innerBoxIsScrolled,
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: "Expenses".i18n.toUpperCase()),
                  Tab(text: "Income".i18n.toUpperCase()),
                  Tab(text: "Balance".i18n.toUpperCase()),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            StatisticsTabPage(
              widget.from,
              widget.to,
              widget.records
                  .where((element) =>
                      element!.category!.categoryType == CategoryType.expense)
                  .toList(),
              selectedDate: _selectedDate,
              showRecordsToggle: true,
              onIntervalSelected: (newTitle, date, amount) {
                setState(() {
                  _selectedIntervalTitle = newTitle;
                  _selectedDate = date;
                });
              },
            ),
            StatisticsTabPage(
              widget.from,
              widget.to,
              widget.records
                  .where((element) =>
                      element!.category!.categoryType == CategoryType.income)
                  .toList(),
              selectedDate: _selectedDate,
              showRecordsToggle: true,
              onIntervalSelected: (newTitle, date, amount) {
                setState(() {
                  _selectedIntervalTitle = newTitle;
                  _selectedDate = date;
                });
              },
            ),
            BalanceTabPage(
              widget.from,
              widget.to,
              widget.records,
              selectedDate: _selectedDate,
              showRecordsToggle: true,
              onIntervalSelected: (newTitle, date) {
                setState(() {
                  _selectedIntervalTitle = newTitle;
                  _selectedDate = date;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
