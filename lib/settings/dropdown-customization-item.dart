import 'package:deep_collection/deep_collection.dart';
import 'package:flutter/material.dart';

import '../services/service-config.dart';

class DropdownCustomizationItem<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, T> dropdownValues;
  String selectedDropdownKey;
  final String sharedConfigKey;

  DropdownCustomizationItem({
    required this.title,
    required this.subtitle,
    required this.dropdownValues,
    required this.selectedDropdownKey,
    required this.sharedConfigKey,
  });

  @override
  DropdownCustomizationItemState<T> createState() =>
      DropdownCustomizationItemState(selectedDropdownKey);
}

class UnsupportedTypeException implements Exception {
  final String message;

  UnsupportedTypeException(this.message);

  @override
  String toString() {
    return message;
  }
}

class DropdownCustomizationItemState<T> extends State<DropdownCustomizationItem> {

  String selectedDropdownKey;

  DropdownCustomizationItemState(this.selectedDropdownKey);

  @override
  void initState() {
    super.initState();
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

  void setSharedConfig(T dropdownValue) {
    var sharedConfigKey = widget.sharedConfigKey;
    if (dropdownValue == null) {
      ServiceConfig.sharedPreferences!.remove(sharedConfigKey);
    }
    if (T == String) {
      ServiceConfig.sharedPreferences!.setString(sharedConfigKey, dropdownValue as String);
    } else if (T == int) {
      ServiceConfig.sharedPreferences!.setInt(sharedConfigKey, dropdownValue as int);
    } else if (T == bool) {
      ServiceConfig.sharedPreferences!.setBool(sharedConfigKey, dropdownValue as bool);
    } else {
      throw UnsupportedTypeException("Unsupported type: ${T.toString()}");
    }
  }

  Widget buildDropdownMenu() {
    return Container(
        alignment: AlignmentDirectional.topStart,
        margin: EdgeInsets.only(left: 20),
        child: DropdownButton<String>(
            menuMaxHeight: 300,
            dropdownColor: Theme.of(context).colorScheme.surfaceVariant,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            isExpanded: true,
            padding: EdgeInsets.all(0),
            value: selectedDropdownKey,
            underline: SizedBox(),
            onChanged: (String? value) {
              setState(() {
                selectedDropdownKey = value!;
                setSharedConfig(widget.dropdownValues[value]);
              });
            },
            items: widget.dropdownValues.keys
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value)
              );
            }).toList(),
          )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          buildHeader(),
          buildDropdownMenu()
        ],
      )
    );
  }
}

