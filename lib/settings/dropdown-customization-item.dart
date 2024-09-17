import 'package:flutter/material.dart';
import 'package:piggybank/settings/style.dart';

import '../services/service-config.dart';

class DropdownCustomizationItem<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, T> dropdownValues;
  final String selectedDropdownKey;
  final String sharedConfigKey;
  final Function()? onChanged;

  DropdownCustomizationItem(
      {required this.title,
      required this.subtitle,
      required this.dropdownValues,
      required this.selectedDropdownKey,
      required this.sharedConfigKey,
      this.onChanged});

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

class DropdownCustomizationItemState<T>
    extends State<DropdownCustomizationItem> {
  late String selectedDropdownKey;

  DropdownCustomizationItemState(this.selectedDropdownKey);

  @override
  void initState() {
    super.initState();
    selectedDropdownKey = widget.selectedDropdownKey;
  }

  void setSharedConfig(T dropdownValue) {
    var sharedConfigKey = widget.sharedConfigKey;
    if (dropdownValue == null) {
      ServiceConfig.sharedPreferences!.remove(sharedConfigKey);
    }
    if (T == String) {
      ServiceConfig.sharedPreferences!
          .setString(sharedConfigKey, dropdownValue as String);
    } else if (T == int) {
      ServiceConfig.sharedPreferences!
          .setInt(sharedConfigKey, dropdownValue as int);
    } else if (T == bool) {
      ServiceConfig.sharedPreferences!
          .setBool(sharedConfigKey, dropdownValue as bool);
    } else {
      throw UnsupportedTypeException("Unsupported type: ${T.toString()}");
    }
  }

  void showSelectionDialog(BuildContext context) {
    final double maxHeight =
        MediaQuery.of(context).size.height * 0.8; // Maximum height
    final double itemHeight = 56.0; // Assuming the height of each RadioListTile
    final double suggestedHeight =
        widget.dropdownValues.keys.length * itemHeight +
            MediaQuery.of(context)
                .textScaler
                .scale(170); // used for the space in the header

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            height: suggestedHeight > maxHeight ? maxHeight : suggestedHeight,
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (BuildContext context, StateSetter setNewState) {
                        return Column(
                          children: [
                            ...widget.dropdownValues.keys
                                .map<Widget>((String value) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                                child: RadioListTile<String>(
                                  title: Text(
                                    value,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  value: value,
                                  groupValue: selectedDropdownKey,
                                  onChanged: (String? value) {
                                    setNewState(() {
                                      selectedDropdownKey = value!;
                                      setSharedConfig(
                                          widget.dropdownValues[value]!);
                                    });
                                    setState(() {
                                      selectedDropdownKey = value!;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: () {
                        widget.onChanged?.call();
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: Text('OK'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        showSelectionDialog(context);
      },
      title: Text(widget.title, style: titleTextStyle),
      subtitle: Text(
        selectedDropdownKey,
        style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: subTitleFontSize),
      ),
      contentPadding: EdgeInsets.fromLTRB(16, 0, 10, 10),
    );
  }
}
