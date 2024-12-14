import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:local_auth/local_auth.dart'; // Ensure this is added in pubspec.yaml
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories/categories-tab-page-edit.dart';
import 'package:piggybank/i18n.dart';

class Shell extends StatefulWidget {
  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _currentIndex = 0;
  final LocalAuthentication auth = LocalAuthentication();
  Future<bool>? authFuture = null;

  final GlobalKey<TabRecordsState> _tabRecordsKey = GlobalKey();
  final GlobalKey<TabCategoriesState> _tabCategoriesKey = GlobalKey();

  Future<bool> _authenticate() async {
    var pref = await SharedPreferences.getInstance();
    var enableAppLock = pref.getBool("enableAppLock") ?? false;
    if (enableAppLock) {
      try {
        var authResult = await auth.authenticate(
          localizedReason: 'Authenticate to access the app'.i18n,
          options: const AuthenticationOptions(stickyAuth: true),
        );
        return authResult;
      } on PlatformException catch (e) {
        print('Authentication error: ${e.message}');
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    authFuture = _authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: authFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading spinner while authenticating
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError || !(snapshot.data ?? false)) {
          // Show lock icon with a retry button if authentication failed
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    "Authentication Failed",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Trigger a new authentication attempt
                        authFuture = _authenticate();
                      });
                    },
                    child: Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Authentication successful, build the main UI
          return _buildMainUI(context);
        }
      },
    );
  }


  Widget _buildMainUI(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MaterialThemeInstance.currentTheme = themeData;
    ThemeData lightTheme = MaterialThemeInstance.lightTheme!;
    ThemeData darkTheme = MaterialThemeInstance.darkTheme!;
    ThemeMode themeMode = MaterialThemeInstance.themeMode!;

    return Scaffold(
      body: Stack(children: <Widget>[
        Offstage(
          offstage: _currentIndex != 0,
          child: TickerMode(
            enabled: _currentIndex == 0,
            child: MaterialApp(
              home: TabRecords(key: _tabRecordsKey),
              title: "Oinkoin",
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
            ),
          ),
        ),
        Offstage(
          offstage: _currentIndex != 1,
          child: TickerMode(
            enabled: _currentIndex == 1,
            child: MaterialApp(
              home: TabCategories(key: _tabCategoriesKey),
              title: "Oinkoin",
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
            ),
          ),
        ),
        Offstage(
          offstage: _currentIndex != 2,
          child: TickerMode(
            enabled: _currentIndex == 2,
            child: MaterialApp(
              home: TabSettings(),
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
            _currentIndex = index;
          });
          // refresh data whenever changing the tab
          if (_currentIndex == 0) {
            await _tabRecordsKey.currentState?.onTabChange();
          }
          if (_currentIndex == 1) {
            await _tabCategoriesKey.currentState?.onTabChange();
          }
        },
        destinations: [
          NavigationDestination(
            label: "Home".i18n,
            selectedIcon: Semantics(
              identifier: 'home-tab-selected',
              child: Icon(Icons.home),
            ),
            icon: Semantics(
              identifier: 'home-tab',
              child: Icon(Icons.home_outlined),
            ),
          ),
          NavigationDestination(
            label: "Categories".i18n,
            selectedIcon: Semantics(
              identifier: 'categories-tab-selected',
              child: Icon(Icons.category),
            ),
            icon: Semantics(
              identifier: 'categories-tab',
              child: Icon(Icons.category_outlined),
            ),
          ),
          NavigationDestination(
            label: "Settings".i18n,
            selectedIcon: Semantics(
              identifier: 'settings-tab-selected',
              child: Icon(Icons.settings),
            ),
            icon: Semantics(
              identifier: 'settings-tab',
              child: Icon(Icons.settings_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
