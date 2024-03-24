import 'package:flutter/material.dart';
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'package:piggybank/style.dart';
import 'categories/categories-tab-page-edit.dart';
import 'package:piggybank/i18n.dart';

class Shell extends StatefulWidget {
  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _currentIndex = 0;

  final GlobalKey<TabRecordsState> _tabRecordsKey = GlobalKey();
  final GlobalKey<TabCategoriesState> _tabCategoriesKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MaterialThemeInstance.currentTheme = themeData;
    ThemeData lightTheme = MaterialThemeInstance.lightTheme!;
    ThemeData darkTheme = MaterialThemeInstance.darkTheme!;
    ThemeMode themeMode = MaterialThemeInstance.themeMode!;
    // How I have implemented navigation: https://stackoverflow.com/questions/45235570/how-to-use-bottomnavigationbar-with-navigator
    return Scaffold(
        body: new Stack(children: <Widget>[
          new Offstage(
            offstage: _currentIndex != 0,
            child: new TickerMode(
              enabled: _currentIndex == 0,
              child: new MaterialApp(
                home: new TabRecords(key: _tabRecordsKey),
                title: "Oinkoin",
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
              ),
            ),
          ),
          new Offstage(
            offstage: _currentIndex != 1,
            child: new TickerMode(
              enabled: _currentIndex == 1,
              child: new MaterialApp(
                home: new TabCategories(key: _tabCategoriesKey),
                title: "Oinkoin",
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
              ),
            ),
          ),
          new Offstage(
            offstage: _currentIndex != 2,
            child: new TickerMode(
              enabled: _currentIndex == 2,
              child: new MaterialApp(
                home: new TabSettings(),
                title: "Oinkoin",
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
              ),
            ),
          ),
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (int index) async {
              setState(() {
                this._currentIndex = index;
              });
              // refresh data whenever changing the tab
              if (this._currentIndex == 0) {
                await _tabRecordsKey.currentState!.onTabChange();
              }
              if (this._currentIndex == 1) {
                await _tabCategoriesKey.currentState!.onTabChange();
              }
            },
            destinations: [
              NavigationDestination(
                  label: "Home".i18n,
                  selectedIcon: Icon(Icons.home),
                  icon: Icon(Icons.home_outlined)),
              NavigationDestination(
                  label: "Categories".i18n,
                  selectedIcon: Icon(Icons.category),
                  icon: Icon(Icons.category_outlined)),
              NavigationDestination(
                  label: "Settings".i18n,
                  selectedIcon: Icon(Icons.settings),
                  icon: Icon(Icons.settings_outlined)),
            ]));
  }
}
