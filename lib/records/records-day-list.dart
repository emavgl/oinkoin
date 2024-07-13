import 'package:flutter/cupertino.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/records-per-day-card.dart';

class RecordsDayList extends StatelessWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  final List<Record?> records;
  final Function? onListBackCallback;

  RecordsDayList(this.records, {this.onListBackCallback});

  @override
  Widget build(BuildContext context) {
    List<RecordsPerDay> _daysShown = groupRecordsByDay(records);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return RecordsPerDayCard(
            _daysShown[index],
            onListBackCallback: onListBackCallback,
          );
        },
        childCount: _daysShown.length,
      ),
    );
  }
}
