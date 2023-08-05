
import 'package:flutter/material.dart';
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'package:piggybank/style.dart';
import 'categories/categories-tab-page-edit.dart';
import 'i18n/shell.i18n.dart';

class Shell extends StatefulWidget {

  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
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
            child: new MaterialApp(home: new RecordsPage(key: _recordPageKey), title: "Oinkoin", theme: materialTheme,),
          ),
          ),
          new Offstage(
            offstage: _currentIndex != 1,
            child: new TickerMode(
              enabled: _currentIndex == 1,
              child: new MaterialApp(home: new CategoryTabPageEdit(), title: "Oinkoin", theme: materialTheme),
            ),
          ),
            new Offstage(
              offstage: _currentIndex != 2,
              child: new TickerMode(
                enabled: _currentIndex == 2,
                child: new MaterialApp(home: new SettingsPage(), title: "Oinkoin", theme: materialTheme,),
              ),
            ),
        ]
      ),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (int index) async {
            setState((){
              this._currentIndex = index; }
            );
            if (this._currentIndex == 0) {
              await _recordPageKey.currentState!.onTabChange();
            }
          },
          destinations: [
            NavigationDestination(
              label: "Home".i18n,
              icon: Icon(Icons.home)
            ),
            NavigationDestination(
                label: "Categories".i18n,
                icon: Icon(Icons.category)
            ),
            NavigationDestination(
                label: "Settings".i18n,
                icon: Icon(Icons.settings)
            ),
          ]
        )
    );
  }
}