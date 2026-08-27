import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:piggybank/comms/announcement-dialog.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/records/records-page.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/settings/settings-page.dart';
import 'package:piggybank/style.dart';
import 'package:piggybank/budgets/budgets-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categories/categories-tab-page-edit.dart';
import 'wallets/wallets-tab-page.dart';

class Shell extends StatefulWidget {
  @override
  ShellState createState() => ShellState();
}

class ShellState extends State<Shell> {
  /// Singleton-like access for external refresh calls (e.g., quick actions).
  static ShellState? _instance;

  /// Returns the current ShellState instance, if mounted.
  static ShellState? get instance => _instance;

  int _currentIndex = 0;
  final LocalAuthentication auth = LocalAuthentication();
  Future<bool>? authFuture = null;

  /// Ensures the startup announcement dialog is checked only once per app run,
  /// after authentication has succeeded and the main UI is on screen.
  bool _announcementDialogChecked = false;

  final GlobalKey<TabRecordsState> _tabRecordsKey = GlobalKey();
  final GlobalKey<TabCategoriesState> _tabCategoriesKey = GlobalKey();
  final GlobalKey<WalletsTabPageState> _tabWalletsKey = GlobalKey();
  final GlobalKey<BudgetsPageState> _tabBudgetsKey = GlobalKey();

  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _categoriesNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _walletsNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _budgetsNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _settingsNavigatorKey =
      GlobalKey<NavigatorState>();

  Future<bool> _authenticate() async {
    // Skip biometric authentication on desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }

    var pref = await SharedPreferences.getInstance();
    var enableAppLock = PreferencesUtils.getOrDefault<bool>(
      pref,
      PreferencesKeys.enableAppLock,
    )!;
    if (enableAppLock) {
      try {
        final authResult = await auth.authenticate(
          localizedReason: 'Authenticate to access the app'.i18n,
          persistAcrossBackgrounding: true,
        );
        return authResult;
      } on LocalAuthException catch (e) {
        print('Authentication error: ${e.code}');
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    authFuture = _authenticate();
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  /// Shows the pending startup announcement dialog (if any) once the main UI
  /// has been laid out. Runs a single time per app launch and only after the
  /// user has passed authentication.
  void _scheduleAnnouncementDialog() {
    if (_announcementDialogChecked) return;
    _announcementDialogChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowAnnouncementDialog(context);
    });
  }

  /// Refreshes the home tab's records list (e.g., after a quick action added a record).
  void refreshHomeTab() {
    _tabRecordsKey.currentState?.onTabChange();
  }

  /// Returns the fixed logical indexes currently represented in the
  /// NavigationBar, preserving the indexes used by the tab navigators.
  List<int> _visibleLogicalIndexes({
    required bool walletsEnabled,
    required bool budgetsEnabled,
  }) {
    return [
      0,
      if (walletsEnabled) 1,
      2,
      if (budgetsEnabled) 3,
      4,
    ];
  }

  /// Maps a logical tab index to the visual NavigationBar index.
  int _visualIndex(
    int logicalIndex,
    bool walletsEnabled,
    bool budgetsEnabled,
  ) {
    final index = _visibleLogicalIndexes(
      walletsEnabled: walletsEnabled,
      budgetsEnabled: budgetsEnabled,
    ).indexOf(logicalIndex);
    return index < 0 ? 0 : index;
  }

  /// Maps a visual NavigationBar index to the logical tab index.
  int _logicalIndex(
    int visualIndex,
    bool walletsEnabled,
    bool budgetsEnabled,
  ) {
    final indexes = _visibleLogicalIndexes(
      walletsEnabled: walletsEnabled,
      budgetsEnabled: budgetsEnabled,
    );
    final safeVisualIndex =
        visualIndex.clamp(0, indexes.length - 1).toInt();
    return indexes[safeVisualIndex];
  }

  List<Widget> _buildDestinations(
    bool walletsEnabled,
    bool budgetsEnabled,
    bool animationsEnabled,
  ) {
    Widget navigationIcon({
      required int logicalIndex,
      required String semanticsIdentifier,
      required IconData iconData,
      required IconData selectedIconData,
      required _NavigationIconMotion motion,
    }) {
      final isSelected = _currentIndex == logicalIndex;
      return Semantics(
        identifier: isSelected
            ? '$semanticsIdentifier-selected'
            : semanticsIdentifier,
        child: _AnimatedNavigationIcon(
          key: ValueKey<String>(semanticsIdentifier),
          isSelected: isSelected,
          icon: iconData,
          selectedIcon: selectedIconData,
          motion: motion,
          animationsEnabled: animationsEnabled,
        ),
      );
    }

    final destinations = <Widget>[
      NavigationDestination(
        label: "Home".i18n,
        icon: navigationIcon(
          logicalIndex: 0,
          semanticsIdentifier: 'home-tab',
          iconData: Icons.home_outlined,
          selectedIconData: Icons.home,
          motion: _NavigationIconMotion.bounce,
        ),
      ),
    ];
    if (walletsEnabled) {
      destinations.add(
        NavigationDestination(
          label: "Wallets".i18n,
          icon: navigationIcon(
            logicalIndex: 1,
            semanticsIdentifier: 'wallets-tab',
            iconData: Icons.account_balance_wallet_outlined,
            selectedIconData: Icons.account_balance_wallet,
            motion: _NavigationIconMotion.mirror,
          ),
        ),
      );
    }
    destinations.addAll([
      NavigationDestination(
        label: "Categories".i18n,
        icon: navigationIcon(
          logicalIndex: 2,
          semanticsIdentifier: 'categories-tab',
          iconData: Icons.category_outlined,
          selectedIconData: Icons.category,
          motion: _NavigationIconMotion.rotateAndStay,
        ),
      ),
      if (budgetsEnabled)
        NavigationDestination(
          label: "Budgets".i18n,
          icon: navigationIcon(
            logicalIndex: 3,
            semanticsIdentifier: 'budgets-tab',
            iconData: Icons.savings_outlined,
            selectedIconData: Icons.savings,
            motion: _NavigationIconMotion.mirror,
          ),
        ),
      NavigationDestination(
        label: "Settings".i18n,
        icon: navigationIcon(
          logicalIndex: 4,
          semanticsIdentifier: 'settings-tab',
          iconData: Icons.settings_outlined,
          selectedIconData: Icons.settings,
          motion: _NavigationIconMotion.rotate,
        ),
      ),
    ]);
    return destinations;
  }

  @override
  Widget build(BuildContext context) {
    print("Shell build called");
    return FutureBuilder<bool>(
      future: authFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading spinner while authenticating
          return Scaffold(body: Center(child: CircularProgressIndicator()));
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
          _scheduleAnnouncementDialog();
          return _buildMainUI(context);
        }
      },
    );
  }

  Widget _buildMainUI(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MaterialThemeInstance.currentTheme = themeData;

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
            currentNavigator = _walletsNavigatorKey.currentState;
            break;
          case 2:
            currentNavigator = _categoriesNavigatorKey.currentState;
            break;
          case 3:
            currentNavigator = _budgetsNavigatorKey.currentState;
            break;
          case 4:
            currentNavigator = _settingsNavigatorKey.currentState;
            break;
        }

        // Check if the current tab's navigator can pop.
        // Use maybePop so inner PopScopes (e.g., in-app keyboard) can intercept first.
        if (currentNavigator != null && currentNavigator.canPop()) {
          await currentNavigator.maybePop();
          return;
        }

        // At the root of the current tab's navigator.
        // Use maybePop to respect inner PopScopes (e.g., select mode in records).
        if (currentNavigator != null) {
          final bool handled = await currentNavigator.maybePop();
          if (handled) return;
        }

        if (_currentIndex != 0) {
          // If we're at the root of a non-Home tab, navigate to Home
          setState(() {
            _currentIndex = 0;
          });
        } else {
          // We're at the root of Home tab - exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          // In landscape the system navigation bar (3-button mode) sits on the
          // side of the screen. Pad horizontally so body content never extends
          // behind it. The top inset is handled by each page's app bar and the
          // bottom inset by the NavigationBar below.
          top: false,
          bottom: false,
          child: Stack(
            children: <Widget>[
              Offstage(
                offstage: _currentIndex != 0,
                child: TickerMode(
                  enabled: _currentIndex == 0,
                  child: Navigator(
                    key: _homeNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => TabRecords(key: _tabRecordsKey),
                      );
                    },
                  ),
                ),
              ),
              Offstage(
                offstage: _currentIndex != 1,
                child: TickerMode(
                  enabled: _currentIndex == 1,
                  child: Navigator(
                    key: _walletsNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => WalletsTabPage(key: _tabWalletsKey),
                      );
                    },
                  ),
                ),
              ),
              Offstage(
                offstage: _currentIndex != 2,
                child: TickerMode(
                  enabled: _currentIndex == 2,
                  child: Navigator(
                    key: _categoriesNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => TabCategories(key: _tabCategoriesKey),
                      );
                    },
                  ),
                ),
              ),
              Offstage(
                offstage: _currentIndex != 3,
                child: TickerMode(
                  enabled: _currentIndex == 3,
                  child: Navigator(
                    key: _budgetsNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => BudgetsPage(key: _tabBudgetsKey),
                      );
                    },
                  ),
                ),
              ),
              Offstage(
                offstage: _currentIndex != 4,
                child: TickerMode(
                  enabled: _currentIndex == 4,
                  child: Navigator(
                    key: _settingsNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(builder: (_) => TabSettings());
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: ServiceConfig.budgetsEnabledNotifier,
              builder: (context, budgetsEnabled, _) {
                // Defensively reset to the Home tab if the currently selected
                // tab no longer exists after a feature is disabled.
                if ((!walletsEnabled && _currentIndex == 1) ||
                    (!budgetsEnabled && _currentIndex == 3)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _currentIndex = 0);
                  });
                }
                return ValueListenableBuilder<bool>(
                  valueListenable:
                      ServiceConfig.navigationBarAnimationsEnabledNotifier,
                  builder: (context, animationsEnabled, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: inAppKeyboardOpen,
                  builder: (context, isOpen, child) => AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    // Collapse the nav bar but keep a spacer equal to the system
                    // navigation bar inset so the Scaffold body never extends behind it.
                    child: isOpen
                        ? SizedBox(
                            height: MediaQuery.paddingOf(context).bottom)
                        : child!,
                  ),
                      child: NavigationBar(
                    animationDuration: animationsEnabled
                        ? const Duration(milliseconds: 220)
                        : null,
                    selectedIndex: _visualIndex(
                        _currentIndex, walletsEnabled, budgetsEnabled),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    // One point smaller than labelSmall (11sp) for extra
                    // margin so longer localized labels don't wrap.
                    labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                    onDestinationSelected: (int visualIndex) async {
                      setState(() {
                        _currentIndex = _logicalIndex(
                            visualIndex, walletsEnabled, budgetsEnabled);
                      });
                      // refresh data whenever changing the tab
                      if (_currentIndex == 0) {
                        await _tabRecordsKey.currentState?.onTabChange();
                      }
                      if (_currentIndex == 1) {
                        await _tabWalletsKey.currentState?.onTabChange();
                      }
                      if (_currentIndex == 2) {
                        await _tabCategoriesKey.currentState?.onTabChange();
                      }
                      if (_currentIndex == 3) {
                        await _tabBudgetsKey.currentState?.onTabChange();
                      }
                    },
                    destinations: _buildDestinations(
                      walletsEnabled,
                      budgetsEnabled,
                      animationsEnabled,
                    ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Defines the selection motion for a navigation icon.
enum _NavigationIconMotion { bounce, rotate, mirror, rotateAndStay }

/// Animates an outlined-to-filled icon with a per-destination transition.
class _AnimatedNavigationIcon extends StatefulWidget {
  const _AnimatedNavigationIcon({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.selectedIcon,
    required this.motion,
    required this.animationsEnabled,
  });

  final bool isSelected;
  final IconData icon;
  final IconData selectedIcon;
  final _NavigationIconMotion motion;
  final bool animationsEnabled;

  @override
  State<_AnimatedNavigationIcon> createState() =>
      _AnimatedNavigationIconState();
}

class _AnimatedNavigationIconState extends State<_AnimatedNavigationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 170),
      value: widget.isSelected ? 1.0 : 0.0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedNavigationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected == widget.isSelected) return;

    if (widget.isSelected) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _rotationTurns(double progress) {
    switch (widget.motion) {
      case _NavigationIconMotion.bounce:
        return 0.0;
      case _NavigationIconMotion.rotate:
        // Settings/Home rotate briefly and settle back to their original angle.
        return 0.09 * math.sin(progress * math.pi);
      case _NavigationIconMotion.mirror:
        return 0.0;
      case _NavigationIconMotion.rotateAndStay:
        // Categories remain at a quarter turn while selected.
        return 0.25 * progress;
    }
  }

  double _horizontalScale(double progress) {
    if (widget.motion == _NavigationIconMotion.mirror) {
      // A scaleX transition through zero creates a left-to-right mirror flip.
      return 1.0 - (2.0 * progress);
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animationsEnabled) {
      return Icon(widget.isSelected ? widget.selectedIcon : widget.icon);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final selectionOpacity = Curves.easeIn.transform(progress);
        final selectedScale =
            0.88 + 0.12 * Curves.easeOutBack.transform(progress);
        final rotation = _rotationTurns(progress) * 2 * math.pi;
        final horizontalScale = _horizontalScale(progress);
        final keepsRotation =
            widget.motion == _NavigationIconMotion.rotateAndStay;
        final unselectedRotation = keepsRotation ? rotation : -rotation;

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1.0 - selectionOpacity,
              child: Transform.rotate(
                angle: unselectedRotation,
                child: Transform.scale(
                  scaleX: horizontalScale,
                  scaleY: 1.0 - 0.06 * progress,
                  child: Icon(widget.icon),
                ),
              ),
            ),
            Opacity(
              opacity: selectionOpacity,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scaleX: horizontalScale,
                  scaleY: selectedScale,
                  child: Icon(widget.selectedIcon),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
