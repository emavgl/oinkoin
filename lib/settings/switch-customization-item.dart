import 'dart:developer';

import 'package:flutter/material.dart';

import '../services/service-config.dart';

class SwitchCustomizationItem<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool switchValue;
  final String sharedConfigKey;
  final Function()? onChanged;

  SwitchCustomizationItem(
      {required this.title,
      required this.subtitle,
      required this.switchValue,
      required this.sharedConfigKey,
      this.onChanged});

  @override
  SwitchCustomizationItemState<T> createState() =>
      SwitchCustomizationItemState(switchValue);
}

class UnsupportedTypeException implements Exception {
  final String message;

  UnsupportedTypeException(this.message);

  @override
  String toString() {
    return message;
  }
}

class SwitchCustomizationItemState<T> extends State<SwitchCustomizationItem> {
  late bool switchValue;

  SwitchCustomizationItemState(this.switchValue);

  @override
  void initState() {
    super.initState();
    switchValue = widget.switchValue;
  }

  Widget buildHeader() {
    return Column(
      children: [
        ListTile(
          title: Text(widget.title),
          subtitle: Text(widget.subtitle),
        ),
        Divider()
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      trailing: Switch(
        value: switchValue,
        onChanged: (bool value) {
          setState(() {
            ServiceConfig.sharedPreferences!
                .setBool(widget.sharedConfigKey, value);
            switchValue = value;
          });
        },
      ),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
    );
  }
}
