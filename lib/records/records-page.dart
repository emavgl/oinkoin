import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:piggybank/i18n.dart';

import 'components/days-summary-box-card.dart';
import 'components/records-day-list.dart';
import 'components/tab_records_app_bar.dart';
import 'components/tab_records_date_picker.dart';
import 'components/tab_records_search_app_bar.dart';
import 'controllers/tab_records_controller.dart';

class TabRecords extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  TabRecords({Key? key}) : super(key: key);

  @override
  TabRecordsState createState() => TabRecordsState();
}

class TabRecordsState extends State<TabRecords> {
  late final TabRecordsController _controller;
  late final AppLifecycleListener _listener;
  late AppLifecycleState? _state;
  bool _isAppBarExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = TabRecordsController(
      onStateChanged: () => setState(() {}),
    );

    _state = SchedulerBinding.instance.lifecycleState;
    _listener = AppLifecycleListener(
      onStateChange: _handleOnResume,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize();
    });
  }

  void _handleOnResume(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) {
      _controller.onResume();
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.runAutomaticBackup(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      appBar: _buildAppBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        setState(() {
          _isAppBarExpanded = scrollInfo.metrics.pixels < 100;
        });
        return true;
      },
      child: CustomScrollView(
        slivers: _buildSlivers(),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    return <Widget>[
      if (!_controller.isSearchingEnabled) _buildMainSliverAppBar(),
      _buildSummarySection(),
      const SliverToBoxAdapter(
        child: Divider(indent: 50, endIndent: 50),
      ),
      if (_controller.filteredRecords.isEmpty) _buildEmptyState(),
      RecordsDayList(
        _controller.filteredRecords,
        onListBackCallback: _controller.updateRecurrentRecordsAndFetchRecords,
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 75),
      ),
    ];
  }

  Widget _buildMainSliverAppBar() {
    return TabRecordsAppBar(
      controller: _controller,
      isAppBarExpanded: _isAppBarExpanded,
      onDatePickerPressed: () => _showDatePicker(),
      onStatisticsPressed: () => _controller.navigateToStatisticsPage(context),
      onSearchPressed: () => _controller.startSearch(),
      onMenuItemSelected: (index) =>
          _controller.handleMenuAction(context, index),
    );
  }

  TabRecordsSearchAppBar? _buildAppBar() {
    if (!_controller.isSearchingEnabled) return null;

    return TabRecordsSearchAppBar(
      controller: _controller,
      onBackPressed: () => _controller.stopSearch(),
      onDatePickerPressed: () => _showDatePicker(),
      onStatisticsPressed: () => _controller.navigateToStatisticsPage(context),
      onMenuItemSelected: (index) =>
          _controller.handleMenuAction(context, index),
      onFilterPressed: () => _controller.showFilterModal(context),
    );
  }

  Widget _buildSummarySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 10, 6, 5),
        height: 100,
        child: DaysSummaryBox(
            _controller.overviewRecords ?? _controller.filteredRecords),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Image.asset('assets/images/no_entry.png', width: 200),
          const SizedBox(height: 10),
          Text(
            "No entries yet.".i18n,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _controller.navigateToAddNewRecord(context),
      tooltip: 'Add a new record'.i18n,
      child: Semantics(
        identifier: 'add-record',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    await showDialog(
      context: context,
      builder: (context) => TabRecordsDatePicker(
        controller: _controller,
        onDateSelected: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
  }

  // Public method for external navigation callbacks
  onTabChange() async {
    await _controller.onTabChange();
  }
}
