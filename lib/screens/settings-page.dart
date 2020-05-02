import 'package:flutter/material.dart';
import '../i18n/settings-page.i18n.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child:
        Scaffold(
          appBar: AppBar(title: Text('Settings'.i18n),),
        )
    );
  }
}
