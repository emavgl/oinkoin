import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/profiles/edit-profile-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({Key? key}) : super(key: key);

  @override
  ProfilesPageState createState() => ProfilesPageState();
}

class ProfilesPageState extends State<ProfilesPage> {
  List<Profile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ServiceConfig.database.getAllProfiles();
    setState(() => _profiles = profiles);
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
    return Scaffold(
      appBar: AppBar(title: Text("Profiles".i18n)),
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
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
      body: ListView.builder(
        itemCount: _profiles.length,
        itemBuilder: (ctx, i) {
          final p = _profiles[i];
          final isActive = ProfileService.instance.activeProfileId == p.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: isActive
                  ? Icon(Icons.check,
                      size: 20, color: Theme.of(context).colorScheme.primary)
                  : const SizedBox(width: 20),
              title: Text(p.name),
              subtitle: p.isDefault ? Text("Predefined".i18n) : null,
              trailing: PopupMenuButton<int>(
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
                    child:
                        Text("Edit".i18n, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              onTap: () => _switchProfile(p),
              onLongPress: () => _showDefaultSheet(p),
            ),
          );
        },
      ),
    );
  }
}
