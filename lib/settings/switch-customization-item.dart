import 'package:flutter/material.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/settings/style.dart';

import '../services/service-config.dart';

class SwitchCustomizationItem<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool switchValue;
  final String sharedConfigKey;
  final Function(bool)? onChanged;
  final bool enabled;
  final bool proLabel;

  SwitchCustomizationItem(
      {required this.title,
      required this.subtitle,
      required this.switchValue,
      required this.sharedConfigKey,
      this.enabled = true,
      this.proLabel = false,
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

  createTitle() {
    if (widget.proLabel) {
      return Row(
        children: [
          getProLabel(),
          Container(
            margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
            child: Text(widget.title, style: titleTextStyle),
          )
        ],
      );
    }
    return Text(widget.title, style: titleTextStyle);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      trailing: Switch(
        value: switchValue,
        onChanged: (widget.enabled)
            ? (bool value) {
                setState(() {
                  ServiceConfig.sharedPreferences!
                      .setBool(widget.sharedConfigKey, value);
                  switchValue = value;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(value);
                }
              }
            : null,
      ),
      enabled: widget.enabled,
      title: createTitle(),
      subtitle: Text(widget.subtitle, style: subtitleTextStyle),
      contentPadding: EdgeInsets.fromLTRB(16, 0, 10, 10),
    );
  }
}
