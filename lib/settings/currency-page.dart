import 'package:flutter/material.dart';
import './i18n/currency-page.i18n.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class CurrencyPage extends StatefulWidget {

  // Show list of available currencies

  CurrencyPage({Key key}) : super(key: key);

  @override
  CurrencyPageState createState() =>CurrencyPageState();
}

class CurrencyPageState extends State<CurrencyPage> {
  Map<String, String> _currencies = {
    "Euro": "€",
    "Dollar": "\$",
    "Pound sterling": "£",
    "Swiss franc":  "CHF",
    "Czech koruna": "Kč",
    "Danish krone": "kr.",
    "Norwegian krone": "kr",
    "Polish złoty": "zł",
    "Swedish krona": "kr"
  };

  List<MapEntry<String, String>> _currenciesList;
  int indexSelected = 0;
  DatabaseInterface database = ServiceConfig.database;

  Future<String> getCurrency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currency') ?? "€";
  }

  setCurrency(String currency) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString('currency', currency);
  }

  CurrencyPageState() {
    _currenciesList = _currencies.entries.toList();
  }

  @override
  void initState() {
    super.initState();

    getCurrency().then((value) {
      setState(() {
        indexSelected = _currencies[value].indexOf(value);
      });
    });
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildList() {
    return ListView.separated(
        shrinkWrap: true,
        separatorBuilder: (context, index) => Divider(),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currenciesList.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCurrency(i);
        });
  }

  Widget _buildCurrency(int index) {
    return InkWell(
        onTap: () async {
          await setCurrency(_currenciesList[index].value);
          setState(() {
            indexSelected = index;
          });
        },
        child: ListTile(
            leading: Container(
                width: 40,
                height: 40,
                child: Container(
                  padding: EdgeInsets.fromLTRB(14, 8, 0, 10),
                  child: Text(_currenciesList[index].value[0].toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 20),)
                ), 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.lightBlue,
                )),
            trailing: index == indexSelected ? Icon(
                Icons.check,
                size: 20,
                color: Colors.black,
              ) : null,
            title: Text("${_currenciesList[index].key} (${_currenciesList[index].value})", style: _biggerFont)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
              title: Text('Select the currency'.i18n)
            ),
        body: SingleChildScrollView(
              child: _buildList()
        )
    );
  }

}
