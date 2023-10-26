
import 'package:flutter/cupertino.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/records/records-per-day-card.dart';


class RecordsDayList extends StatefulWidget {
  /// MovementsPage is the page showing the list of movements grouped per day.
  /// It contains also buttons for filtering the list of movements and add a new movement.

  List<Record?> records;
  Function? onListBackCallback;
  RecordsDayList(this.records, {this.onListBackCallback});

  @override
  RecordsDayListState createState() => RecordsDayListState();
}


class RecordsDayListState extends State<RecordsDayList> {

  @override
  Widget build(BuildContext context) {
    List<RecordsPerDay> _daysShown = groupRecordsByDay(widget.records);
    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _daysShown.length,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        itemBuilder: /*1*/ (context, i) {
          return RecordsPerDayCard(_daysShown[i], onListBackCallback: widget.onListBackCallback);
        });
  }

}