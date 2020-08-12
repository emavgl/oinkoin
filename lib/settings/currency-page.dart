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
    "US Dollar":"\$",
    "Canadian Dollar":"\$",
    "Euro":"€",
    "United Arab Emirates Dirham":"د.إ.‏",
    "Afghan Afghani":"؋",
    "Albanian Lek":"Lek",
    "Armenian Dram":"դր.",
    "Argentine Peso":"\$",
    "Australian Dollar":"\$",
    "Azerbaijani Manat":"ман.",
    "Bosnia-Herzegovina Convertible Mark":"KM",
    "Bangladeshi Taka":"৳",
    "Bulgarian Lev":"лв.",
    "Bahraini Dinar":"د.ب.‏",
    "Burundian Franc":"FBu",
    "Brunei Dollar":"\$",
    "Bolivian Boliviano":"Bs",
    "Brazilian Real":"R\$",
    "Botswanan Pula":"P",
    "Belarusian Ruble":"руб.",
    "Belize Dollar":"\$",
    "Congolese Franc":"FrCD",
    "Swiss Franc":"CHF",
    "Chilean Peso":"\$",
    "Chinese Yuan":"CN¥",
    "Colombian Peso":"\$",
    "Costa Rican Colón":"₡",
    "Cape Verdean Escudo":"CV\$",
    "Czech Republic Koruna":"Kč",
    "Djiboutian Franc":"Fdj",
    "Danish Krone":"kr",
    "Dominican Peso":"RD\$",
    "Algerian Dinar":"د.ج.‏",
    "Estonian Kroon":"kr",
    "Egyptian Pound":"ج.م.‏",
    "Eritrean Nakfa":"Nfk",
    "Ethiopian Birr":"Br",
    "British Pound Sterling":"£",
    "Georgian Lari":"GEL",
    "Ghanaian Cedi":"GH₵",
    "Guinean Franc":"FG",
    "Guatemalan Quetzal":"Q",
    "Hong Kong Dollar":"\$",
    "Honduran Lempira":"L",
    "Croatian Kuna":"kn",
    "Hungarian Forint":"Ft",
    "Indonesian Rupiah":"Rp",
    "Israeli New Sheqel":"₪",
    "Indian Rupee":"টকা",
    "Iraqi Dinar":"د.ع.‏",
    "Iranian Rial":"﷼",
    "Icelandic Króna":"kr",
    "Jamaican Dollar":"\$",
    "Jordanian Dinar":"د.أ.‏",
    "Japanese Yen":"￥",
    "Kenyan Shilling":"Ksh",
    "Cambodian Riel":"៛",
    "Comorian Franc":"FC",
    "South Korean Won":"₩",
    "Kuwaiti Dinar":"د.ك.‏",
    "Kazakhstani Tenge":"тңг.",
    "Lebanese Pound":"ل.ل.‏",
    "Sri Lankan Rupee":"SL Re",
    "Lithuanian Litas":"Lt",
    "Latvian Lats":"Ls",
    "Libyan Dinar":"د.ل.‏",
    "Moroccan Dirham":"د.م.‏",
    "Moldovan Leu":"MDL",
    "Malagasy Ariary":"MGA",
    "Macedonian Denar":"MKD",
    "Myanma Kyat":"K",
    "Macanese Pataca":"MOP\$",
    "Mauritian Rupee":"MURs",
    "Mexican Peso":"\$",
    "Malaysian Ringgit":"RM",
    "Mozambican Metical":"MTn",
    "Namibian Dollar":"N\$",
    "Nigerian Naira":"₦",
    "Nicaraguan Córdoba":"C\$",
    "Norwegian Krone":"kr",
    "Nepalese Rupee":"नेरू",
    "New Zealand Dollar":"\$",
    "Omani Rial":"ر.ع.‏",
    "Panamanian Balboa":"B/.",
    "Peruvian Nuevo Sol":"S/.",
    "Philippine Peso":"₱",
    "Pakistani Rupee":"₨",
    "Polish Zloty":"zł",
    "Paraguayan Guarani":"₲",
    "Qatari Rial":"ر.ق.‏",
    "Romanian Leu":"RON",
    "Serbian Dinar":"дин.",
    "Russian Ruble":"₽.",
    "Rwandan Franc":"FR",
    "Saudi Riyal":"ر.س.‏",
    "Sudanese Pound":"SDG",
    "Swedish Krona":"kr",
    "Singapore Dollar":"\$",
    "Somali Shilling":"Ssh",
    "Syrian Pound":"ل.س.‏",
    "Thai Baht":"฿",
    "Tunisian Dinar":"د.ت.‏",
    "Tongan Paʻanga":"T\$",
    "Turkish Lira":"TL",
    "Trinidad and Tobago Dollar":"\$",
    "New Taiwan Dollar":"NT\$",
    "Tanzanian Shilling":"TSh",
    "Ukrainian Hryvnia":"₴",
    "Ugandan Shilling":"USh",
    "Uruguayan Peso":"\$",
    "Uzbekistan Som":"UZS",
    "Venezuelan Bolívar":"Bs.F.",
    "Vietnamese Dong":"₫",
    "CFA Franc BEAC":"FCFA",
    "CFA Franc BCEAO":"CFA",
    "Yemeni Rial":"ر.ي.‏",
    "South African Rand":"R",
    "Zambian Kwacha":"ZK",
    "Zimbabwean Dollar":"ZWL\$"
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
        indexSelected = _currenciesList.indexWhere((element) => element.value == value);
      });
    });
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildList() {
    return ListView.separated(
        separatorBuilder: (context, index) => Divider(),
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
                child: Align(
                  alignment: Alignment.center,
                  child: Text(_currenciesList[index].key[0].toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 20),)
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
        body:  _buildList()
    );
  }

}
