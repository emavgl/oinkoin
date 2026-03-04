import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/components/records-per-day-card.dart';

class RecordsDayList extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  final List<Record?> records;
  final Function? onListBackCallback;
  final bool isSliver;
  final int batchSize;

  RecordsDayList(
    this.records, {
    this.onListBackCallback,
    this.isSliver = true,
    this.batchSize = 50,
  });

  @override
  State<RecordsDayList> createState() => _RecordsDayListState();
}

class _RecordsDayListState extends State<RecordsDayList> {
  int _displayedCount = 0;
  late List<RecordsPerDay> _daysShown;
  List<Record?>? _lastRecords;

  @override
  void initState() {
    super.initState();
    _updateDaysShown();
  }

  @override
  void didUpdateWidget(RecordsDayList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.records, widget.records) ||
        oldWidget.records.length != widget.records.length) {
      _updateDaysShown();
    }
  }

  void _updateDaysShown() {
    _daysShown = groupRecordsByDay(widget.records);
    _displayedCount = _daysShown.length.clamp(0, widget.batchSize);
    _lastRecords = widget.records;
  }

  void _loadMore() {
    if (_displayedCount >= _daysShown.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _displayedCount =
              (_displayedCount + widget.batchSize).clamp(0, _daysShown.length);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMore = _displayedCount < _daysShown.length;

    if (widget.isSliver) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (index == _displayedCount && hasMore) {
              _loadMore();
              return const SizedBox.shrink();
            }
            return RecordsPerDayCard(
              _daysShown[index],
              onListBackCallback: widget.onListBackCallback,
            );
          },
          childCount: _displayedCount + (hasMore ? 1 : 0),
        ),
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _displayedCount + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedCount && hasMore) {
            _loadMore();
            return const SizedBox.shrink();
          }
          return RecordsPerDayCard(
            _daysShown[index],
            onListBackCallback: widget.onListBackCallback,
          );
        },
      );
    }
  }
}
