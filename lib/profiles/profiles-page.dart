import 'package:flutter/material.dart';
import 'package:piggybank/helpers/list-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/profiles/edit-profile-page.dart';
import 'package:piggybank/profiles/profile-sort-option.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({Key? key}) : super(key: key);

  @override
  ProfilesPageState createState() => ProfilesPageState();
}

class ProfilesPageState extends State<ProfilesPage> {
  List<Profile> _profiles = [];

  ProfileSortOption _selectedSortOption = ProfileSortOption.original;
  ProfileSortOption _storedDefaultOption = ProfileSortOption.original;
  bool _isDefaultOrder = false;

  // When true the user is in drag-to-reorder mode; drag handles and OK button are visible.
  bool _inCustomOrderMode = false;
  // Holds the pending reordered list while the user drags (before pressing OK).
  List<Profile>? _pendingOrderProfiles;

  @override
  void initState() {
    super.initState();
    _loadProfiles().then((_) => _initializeSortPreference());
  }

  Future<void> _initializeSortPreference() async {
    final key = PreferencesKeys.profileListSortOption;
    if (ServiceConfig.sharedPreferences!.containsKey(key)) {
      final savedIndex = ServiceConfig.sharedPreferences?.getInt(key);
      if (savedIndex != null && savedIndex < ProfileSortOption.values.length) {
        setState(() {
          _storedDefaultOption = ProfileSortOption.values[savedIndex];
          _selectedSortOption = ProfileSortOption.values[savedIndex];
        });
      }
    }
  }

  Future<void> _storeOnUserPreferences() async {
    if (_isDefaultOrder) {
      await ServiceConfig.sharedPreferences?.setInt(
          PreferencesKeys.profileListSortOption, _selectedSortOption.index);
      setState(() {
        _storedDefaultOption = _selectedSortOption;
      });
    }
    _isDefaultOrder = false;
  }

  Future<void> _loadProfiles() async {
    final profiles = await ServiceConfig.database.getAllProfiles();
    setState(() {
      _profiles = profiles;
      // Exit custom order mode on reload
      _inCustomOrderMode = false;
      _pendingOrderProfiles = null;
    });
  }

  /// Profiles sorted by the selected sort option.
  List<Profile> get _sortedProfiles {
    var sorted = List<Profile>.from(_profiles);
    switch (_selectedSortOption) {
      case ProfileSortOption.byName:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ProfileSortOption.original:
        // already ordered by sort_order from the DB query
        break;
    }
    return sorted;
  }

  /// Confirm the pending drag order and persist it to the database.
  Future<void> _confirmCustomOrder() async {
    final ordered = _pendingOrderProfiles ?? _sortedProfiles;
    await ServiceConfig.database.resetProfileOrderIndexes(ordered);
    setState(() {
      _inCustomOrderMode = false;
      _pendingOrderProfiles = null;
    });
    await _loadProfiles();
  }

  void _onReorder(int oldIndex, int newIndex) {
    final current = _pendingOrderProfiles ?? _sortedProfiles;
    setState(() {
      _pendingOrderProfiles = moveListItem(current, oldIndex, newIndex);
    });
  }

  void _showSortOptions() {
    ProfileSortOption pendingOption = _selectedSortOption;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, top: 16, right: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order by".i18n,
                        style: const TextStyle(fontSize: 22),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _isDefaultOrder ||
                                pendingOption == _storedDefaultOption,
                            onChanged: (value) {
                              setModalState(() {
                                _isDefaultOrder = value ?? false;
                              });
                            },
                          ),
                          Text("Make it default".i18n),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reorder),
                  title: Text(
                    "Custom order".i18n,
                    style: TextStyle(
                      color: pendingOption == ProfileSortOption.original
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == ProfileSortOption.original
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = ProfileSortOption.original;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.abc),
                  title: Text(
                    "Name (Alphabetically)".i18n,
                    style: TextStyle(
                      color: pendingOption == ProfileSortOption.byName
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: pendingOption == ProfileSortOption.byName
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      pendingOption = ProfileSortOption.byName;
                    });
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedSortOption = pendingOption;
                          _inCustomOrderMode =
                              pendingOption == ProfileSortOption.original;
                          _pendingOrderProfiles = null;
                        });
                        _storeOnUserPreferences();
                        Navigator.pop(context);
                      },
                      child: Text("Apply".i18n),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _switchProfile(Profile profile) async {
    await ProfileService.instance.switchProfile(profile.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setAsDefault(Profile profile) async {
    await ServiceConfig.database.setDefaultProfile(profile.id!);
    await _loadProfiles();
  }

  void _showDefaultSheet(Profile profile) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Icon(
                  profile.isDefault
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 28,
                ),
                title: Text(
                  profile.isDefault
                      ? "Already predefined for app start".i18n
                      : "Set as predefined for app start".i18n,
                  style: const TextStyle(fontSize: 17),
                ),
                subtitle: Text(
                  "This profile will be loaded on every app start".i18n,
                  style: const TextStyle(fontSize: 13),
                ),
                enabled: !profile.isDefault,
                onTap: profile.isDefault
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _setAsDefault(profile);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(Profile? profile) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(profile: profile),
      ),
    );
    if (changed == true) await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final displayedProfiles = _pendingOrderProfiles ?? _sortedProfiles;
    return Scaffold(
      appBar: AppBar(
        title: Text("Profiles".i18n),
        leading: _inCustomOrderMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _inCustomOrderMode = false;
                  _pendingOrderProfiles = null;
                }),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (_inCustomOrderMode)
            TextButton(
              onPressed: _confirmCustomOrder,
              child: Text(
                "OK".i18n,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortOptions,
            ),
        ],
      ),
      floatingActionButton: _inCustomOrderMode
          ? null
          : Stack(
              children: [
                FloatingActionButton(
                  heroTag: null,
                  onPressed: ServiceConfig.isPremium
                      ? () => _openEdit(null)
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PremiumSplashScreen()),
                          );
                        },
                  tooltip: "New Profile".i18n,
                  child: const Icon(Icons.add),
                ),
                if (!ServiceConfig.isPremium)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PremiumSplashScreen()),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.fromLTRB(8, 8, 0, 0),
                        child: getProLabel(labelFontSize: 10.0),
                      ),
                    ),
                  ),
              ],
            ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: displayedProfiles.length,
        onReorderItem: _onReorder,
        itemBuilder: (ctx, i) {
          final p = displayedProfiles[i];
          final isActive = ProfileService.instance.activeProfileId == p.id;
          return Padding(
            key: ValueKey(p.id),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _inCustomOrderMode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(
                            Icons.drag_handle,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        isActive
                            ? Icon(Icons.check,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary)
                            : const SizedBox(width: 20),
                      ],
                    )
                  : (isActive
                      ? Icon(Icons.check,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary)
                      : const SizedBox(width: 20)),
              title: Text(p.name),
              subtitle: p.isDefault ? Text("Predefined".i18n) : null,
              trailing: _inCustomOrderMode
                  ? null
                  : PopupMenuButton<int>(
                      icon: const Icon(Icons.more_vert),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0))),
                      onSelected: (value) {
                        if (value == 1) _openEdit(p);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem<int>(
                          padding: const EdgeInsets.all(20),
                          value: 1,
                          child: Text("Edit".i18n,
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
              onTap: _inCustomOrderMode ? null : () => _switchProfile(p),
              onLongPress:
                  _inCustomOrderMode ? null : () => _showDefaultSheet(p),
            ),
          );
        },
      ),
    );
  }
}
