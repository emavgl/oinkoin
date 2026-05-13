import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/style.dart';

class EditProfilePage extends StatefulWidget {
  /// Pass [profile] to edit an existing profile; leave null to create a new one.
  final Profile? profile;

  const EditProfilePage({Key? key, this.profile}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final DatabaseInterface _db = ServiceConfig.database;
  final _formKey = GlobalKey<FormState>();

  late String _name;

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    _name = widget.profile?.name ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isNew) {
      await _db.addProfile(Profile(_name.trim()));
    } else {
      final updated = Profile(
        _name.trim(),
        id: widget.profile!.id,
        isDefault: widget.profile!.isDefault,
      );
      await _db.updateProfile(updated);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final profile = widget.profile!;
    final confirmed = await _showDeleteConfirmDialog(profile.name);
    if (!confirmed || !mounted) return;

    if (ProfileService.instance.activeProfileId == profile.id) {
      final defaultProfile = await _db.getDefaultProfile();
      if (defaultProfile != null) {
        await ProfileService.instance.switchProfile(defaultProfile.id!);
      }
    }
    await _db.deleteProfileAndRecords(profile.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<bool> _showDeleteConfirmDialog(String profileName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Profile".i18n),
        content: Text(
          "Delete \"%s\" and all its records, wallets and recurrent patterns?"
              .i18n
              .fill([profileName]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel".i18n),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Delete".i18n,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 0, 5),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: FontNameDefault,
            fontWeight: FontWeight.w300,
            fontSize: 26.0,
            color: MaterialThemeInstance.currentTheme?.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final actions = <Widget>[];
    if (!_isNew && !widget.profile!.isDefault) {
      actions.add(
        PopupMenuButton<int>(
          icon: const Icon(Icons.more_vert),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10.0))),
          onSelected: (value) {
            if (value == 1) _delete();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem<int>(
              padding: const EdgeInsets.all(20),
              value: 1,
              child: Text("Delete".i18n, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
    return AppBar(
      title: Text(_isNew ? "New Profile".i18n : "Edit Profile".i18n),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel("Name".i18n),
              const Divider(thickness: 0.5),
              Container(
                margin: const EdgeInsets.all(10),
                child: TextFormField(
                  autofocus: _isNew,
                  initialValue: _name,
                  onChanged: (v) => setState(() => _name = v),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Please enter a profile name".i18n
                      : null,
                  style: TextStyle(
                    fontSize: 22.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: "Profile name".i18n,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        tooltip: "Save".i18n,
        child: const Icon(Icons.save),
      ),
    );
  }
}
