import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

import '../components/category_icon_circle.dart';
import '../models/recurrent-period.dart';
import 'package:piggybank/i18n.dart';

class PatternsPageView extends StatefulWidget {
  @override
  PatternsPageViewState createState() => PatternsPageViewState();
}

class PatternsPageViewState extends State<PatternsPageView> {
  List<RecurrentRecordPattern>? _recurrentRecordPatterns;
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    database.getRecurrentRecordPatterns().then((patterns) => {
          setState(() {
            _recurrentRecordPatterns = patterns;
          })
        });
  }

  fetchRecurrentRecordPatternsFromDatabase() async {
    var patterns = await database.getRecurrentRecordPatterns();
    setState(() {
      _recurrentRecordPatterns = patterns;
    });
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFontSize = const TextStyle(fontSize: 14.0);

  Widget _buildRecurrentPatternRow(RecurrentRecordPattern pattern) {
    /// Returns a ListTile rendering the single movement row
    return Container(
        margin: EdgeInsets.only(top: 10, bottom: 10),
        child: ListTile(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditRecordPage(
                  passedReccurrentRecordPattern: pattern,
                ),
              ),
            );
            await fetchRecurrentRecordPatternsFromDatabase();
          },
          title: Text(
            pattern.title == null || pattern.title!.trim().isEmpty
                ? pattern.category!.name!
                : pattern.title!,
            style: _biggerFont,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            getCurrencyValueString(pattern.value),
            style: _biggerFont,
          ),
          leading: CategoryIconCircle(
            iconEmoji: pattern.category?.iconEmoji,
            iconDataFromDefaultIconSet: pattern.category?.icon,
            backgroundColor: pattern.category?.color,
          ),
        ),
    );
  }

  Map<RecurrentPeriod, List<RecurrentRecordPattern>> _groupPatternsByPeriod() {
    Map<RecurrentPeriod, List<RecurrentRecordPattern>> grouped = {};

    for (var pattern in _recurrentRecordPatterns!) {
      if (pattern.recurrentPeriod != null) {
        if (!grouped.containsKey(pattern.recurrentPeriod)) {
          grouped[pattern.recurrentPeriod!] = [];
        }
        grouped[pattern.recurrentPeriod!]!.add(pattern);
      }
    }

    return grouped;
  }

  double _calculateGroupSum(List<RecurrentRecordPattern> patterns) {
    return patterns.fold(0.0, (sum, pattern) => sum + (pattern.value ?? 0.0));
  }

  Widget _buildGroupHeader(RecurrentPeriod period, double sum) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            recurrentPeriodString(period),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            getCurrencyValueString(sum),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget buildRecurrentRecordPatternsList() {
    return _recurrentRecordPatterns != null
        ? new Container(
            margin: EdgeInsets.all(5),
            child: _recurrentRecordPatterns!.length == 0
                ? new Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: new Column(
                          children: <Widget>[
                            Image.asset(
                              'assets/images/no_entry_2.png',
                              width: 200,
                            ),
                            Container(
                                child: Text(
                                  "No recurrent records yet.".i18n,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22.0,
                                  ),
                                )
                            )
                          ],
                        )
                      )
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(6.0),
                    itemCount: _groupPatternsByPeriod().length,
                    itemBuilder: (context, index) {
                      var groupedPatterns = _groupPatternsByPeriod();
                      var period = groupedPatterns.keys.elementAt(index);
                      var patterns = groupedPatterns[period]!;
                      var sum = _calculateGroupSum(patterns);

                      return Container(
                        margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                        child: Column(
                          children: [
                            _buildGroupHeader(period, sum),
                            Divider(thickness: 0.5),
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              separatorBuilder: (context, index) => Divider(),
                              itemCount: patterns.length,
                              itemBuilder: (context, i) {
                                return _buildRecurrentPatternRow(patterns[i]);
                              },
                            ),
                          ],
                        ),
                      );
                    }))
        : new Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Recurrent Records'.i18n)),
        body: buildRecurrentRecordPatternsList());
  }
}
