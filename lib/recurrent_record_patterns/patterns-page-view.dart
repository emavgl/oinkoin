import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

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
    return Card(
        elevation: 0,
        child: Container(
          margin: EdgeInsets.only(top: 10, bottom: 10),
          child: ListTile(
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditRecordPage(
                              passedReccurrentRecordPattern: pattern,
                            )));
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
              subtitle: Text(
                recurrentPeriodString(pattern.recurrentPeriod),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _subtitleFontSize,
              ),
              trailing: Text(
                getCurrencyValueString(pattern.value),
                style: _biggerFont,
              ),
              leading: Container(
                  width: 40,
                  height: 40,
                  child: Icon(
                    pattern.category!.icon,
                    size: 20,
                    color: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pattern.category!.color,
                  ))),
        ));
  }

  Widget buildRecurrentRecordPatternsList() {
    return _recurrentRecordPatterns != null
        ? new Container(
            margin: EdgeInsets.all(5),
            child: _recurrentRecordPatterns!.length == 0
                ? new Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      new Column(
                        children: <Widget>[
                          Image.asset(
                            'assets/images/no_entry_2.png',
                            width: 200,
                          ),
                          Text(
                            "No recurrent records yet.".i18n,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.0,
                            ),
                          )
                        ],
                      )
                    ],
                  )
                : ListView.separated(
                    separatorBuilder: (context, index) => Divider(),
                    itemCount: _recurrentRecordPatterns!.length,
                    padding: const EdgeInsets.all(6.0),
                    itemBuilder: /*1*/ (context, i) {
                      return _buildRecurrentPatternRow(
                          _recurrentRecordPatterns![i]);
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
