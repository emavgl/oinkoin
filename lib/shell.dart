
import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-tab-page.dart';
import 'package:piggybank/settings/settings-page.dart';

import 'i18n/shell.i18n.dart';

import 'movements/movements-page.dart';

class Shell extends StatefulWidget {

  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _currentIndex = 0;

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
            child: new MaterialApp(home: new MovementsPage()),
          ),
          ),
          new Offstage(
            offstage: _currentIndex != 1,
            child: new TickerMode(
              enabled: _currentIndex == 1,
              child: new MaterialApp(home: new CategoryTabPage()),
            ),
          ),
            new Offstage(
              offstage: _currentIndex != 2,
              child: new TickerMode(
                enabled: _currentIndex == 2,
                child: new MaterialApp(home: new SettingsPage()),
              ),
            ),
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) { setState((){ this._currentIndex = index; }); },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        fixedColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(
            title: Text("Home".i18n),
            icon: Icon(Icons.home)
          ),
          BottomNavigationBarItem(
              title: Text("Categories".i18n),
              icon: Icon(Icons.category)
          ),
          BottomNavigationBarItem(
              title: Text("Settings".i18n),
              icon: Icon(Icons.settings)
          ),
        ]
      )
      );
  }
}