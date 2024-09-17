import 'package:flutter/material.dart';
import 'package:piggybank/settings/style.dart';

import '../services/service-config.dart';

class TextInputCustomizationItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final String dialogTitle;
  final String dialogSubtitle;
  final String sharedConfigKey;
  final Function(String)? onChanged;

  TextInputCustomizationItem({
    required this.title,
    required this.subtitle,
    required this.dialogTitle,
    required this.dialogSubtitle,
    required this.sharedConfigKey,
    this.onChanged,
  });

  @override
  _TextInputCustomizationItemState createState() =>
      _TextInputCustomizationItemState();
}

class _TextInputCustomizationItemState
    extends State<TextInputCustomizationItem> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  void showInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.dialogSubtitle, style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: 20),
              TextField(
                controller: _textController,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your password here',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Call the onChanged callback with the new value
                if (widget.onChanged != null) {
                  widget.onChanged!(_textController.text);
                }
                // Save the value to shared preferences or handle as needed
                setSharedConfig(_textController.text);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void setSharedConfig(String value) {
    // Assuming you have a ServiceConfig similar to the original code
    // that handles saving values to shared preferences.
    // Replace this with your actual implementation.
    ServiceConfig.sharedPreferences!.setString(widget.sharedConfigKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        showInputDialog(context);
      },
      title: Text(widget.title, style: titleTextStyle),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
            fontSize: subTitleFontSize),
      ),
      contentPadding: EdgeInsets.fromLTRB(16, 0, 10, 10),
    );
  }
}
