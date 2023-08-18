import 'package:flutter/material.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/recurrent_record_patterns/view-recurrent-pattern-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

import './i18n/recurrent-patterns.i18n.dart';


class PatternsPageView extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  bool? goToEditMovementPage;
  PatternsPageView();

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
                        builder: (context) => ViewRecurrentPatternPage(passedPattern: pattern,)
                    )
                );
                await fetchRecurrentRecordPatternsFromDatabase();
              },
              title: Text(
                pattern.title == null || pattern.title!.trim().isEmpty ? pattern.category!.name! : pattern.title! ,
                style: _biggerFont,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                pattern.value.toString(),
                style: _biggerFont,
              ),
              leading: Container(
                  width: 40,
                  height: 40,
                  child: Icon(pattern.category!.icon, size: 20, color: Colors.white,),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pattern.category!.color,
                  )
              )
          ),
        )
    );
  }

  Widget buildRecurrentRecordPatternsList() {
    return _recurrentRecordPatterns != null ? new Container(
        margin: EdgeInsets.all(5),
        child: _recurrentRecordPatterns!.length == 0 ? new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            new Column(
              children: <Widget>[
                Image.asset(
                  'assets/no_entry_2.png', width: 200,
                ),
                Text("No recurrent records yet.".i18n,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.0,) ,)
              ],
            )
          ],
        ) : ListView.separated(
            separatorBuilder: (context, index) => Divider(),
            itemCount: _recurrentRecordPatterns!.length,
            padding: const EdgeInsets.all(6.0),
            itemBuilder: /*1*/ (context, i) {
              return _buildRecurrentPatternRow(_recurrentRecordPatterns![i]);
        })
    ) : new Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Recurrent Records'.i18n)
        ),
        body: buildRecurrentRecordPatternsList()
    );
  }


}
