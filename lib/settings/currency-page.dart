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
  List<String> _currencyNames = ["Euro", "Dollar", "Pound sterling"];
  List<String> _currencies = ["€", "\$", "£"];
  List<IconData> _icons = [FontAwesomeIcons.euroSign, FontAwesomeIcons.dollarSign, FontAwesomeIcons.poundSign];
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

  @override
  void initState() {
    super.initState();
    getCurrency().then((value) {
      setState(() {
        indexSelected = _currencies.indexOf(value);
      });
    });
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildList() {
    return ListView.separated(
        shrinkWrap: true,
        separatorBuilder: (context, index) => Divider(),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currencies.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCurrency(i);
        });
  }

  Widget _buildCurrency(int index) {
    return InkWell(
        onTap: () async {
          await setCurrency(_currencies[index]);
          setState(() {
            indexSelected = index;
          });
        },
        child: ListTile(
            leading: Container(
                width: 40,
                height: 40,
                child: Icon(
                  _icons[index],
                  size: 20,
                  color: Colors.white,
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
            title: Text(_currencyNames[index], style: _biggerFont)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child: Column(
            children: <Widget>[
            AppBar(
              title: Text('Select the currency'.i18n)
            ),
            _buildList()]
      )
    );
  }

}
