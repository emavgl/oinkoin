import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:i18n_extension/i18n_extension.dart';
import 'package:local_auth/local_auth.dart'; // Ensure this is added in pubspec.yaml
import 'package:piggybank/i18n.dart';
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categories/categories-tab-page-edit.dart';

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

  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _categoriesNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>();

  Future<bool> _authenticate() async {
    // Skip biometric authentication on desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }

    var pref = await SharedPreferences.getInstance();
    var enableAppLock = PreferencesUtils.getOrDefault<bool>(
        pref, PreferencesKeys.enableAppLock)!;
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
    print("Shell build called");
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        // Get the current tab's navigator
        NavigatorState? currentNavigator;
        switch (_currentIndex) {
          case 0:
            currentNavigator = _homeNavigatorKey.currentState;
            break;
          case 1:
            currentNavigator = _categoriesNavigatorKey.currentState;
            break;
          case 2:
            currentNavigator = _settingsNavigatorKey.currentState;
            break;
        }

        // Check if the current tab's navigator can pop
        if (currentNavigator != null && currentNavigator.canPop()) {
          // Let the current tab handle the back navigation
          currentNavigator.pop();
        } else if (_currentIndex != 0) {
          // If we're at the root of a non-Home tab, navigate to Home
          setState(() {
            _currentIndex = 0;
          });
        }
        // If we're at Home and can't pop, do nothing (system will handle it)
      },
      child: Scaffold(
        body: Stack(children: <Widget>[
        Offstage(
          offstage: _currentIndex != 0,
          child: TickerMode(
            enabled: _currentIndex == 0,
            child: MaterialApp(
              navigatorKey: _homeNavigatorKey,
              home: TabRecords(key: _tabRecordsKey),
              localizationsDelegates: I18n.localizationsDelegates,
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
              navigatorKey: _categoriesNavigatorKey,
              home: TabCategories(key: _tabCategoriesKey),
              title: "Oinkoin",
              localizationsDelegates: I18n.localizationsDelegates,
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
              navigatorKey: _settingsNavigatorKey,
              home: TabSettings(),
              localizationsDelegates: I18n.localizationsDelegates,
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
      ),
    );
  }
}
