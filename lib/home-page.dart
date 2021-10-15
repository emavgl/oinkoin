
import 'package:flutter/material.dart';
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'categories/categories-tab-page-edit.dart';
import 'i18n/shell.i18n.dart';

class HomePage extends StatefulWidget {

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final GlobalKey<RecordsPageState> _recordPageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // How I have implemented navigation: https://stackoverflow.com/questions/45235570/how-to-use-bottomnavigationbar-with-navigator
    return Scaffold(
      body: new Stack(
          children: <Widget>[
          new Offstage(
            offstage: _currentIndex != 0,
            child: new TickerMode(
            enabled: _currentIndex == 0,
            child: new MaterialApp(home: new RecordsPage(key: _recordPageKey), title: "Oinkoin",),
          ),
          ),
          new Offstage(
            offstage: _currentIndex != 1,
            child: new TickerMode(
              enabled: _currentIndex == 1,
              child: new MaterialApp(home: new CategoryTabPageEdit(), title: "Oinkoin"),
            ),
          ),
            new Offstage(
              offstage: _currentIndex != 2,
              child: new TickerMode(
                enabled: _currentIndex == 2,
                child: new MaterialApp(home: new SettingsPage(), title: "Oinkoin"),
              ),
            ),
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) async {
          setState((){
            this._currentIndex = index; }
          );
          if (this._currentIndex == 0) {
            await _recordPageKey.currentState.onTabChange();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        fixedColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(
            label: "Home".i18n,
            icon: Icon(Icons.home)
          ),
          BottomNavigationBarItem(
              label: "Categories".i18n,
              icon: Icon(Icons.category)
          ),
          BottomNavigationBarItem(
              label: "Settings".i18n,
              icon: Icon(Icons.settings)
          ),
        ]
      )
      );
  }
}