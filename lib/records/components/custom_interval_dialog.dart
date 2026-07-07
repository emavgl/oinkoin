import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/recurrent-period.dart';

/// The value confirmed by [CustomIntervalDialog]'s Save button.
class CustomIntervalSelection {
  final int value;
  final CustomIntervalUnit unit;

  const CustomIntervalSelection(this.value, this.unit);
}

/// Dialog for entering a custom recurrence interval (e.g. "every 6 months").
///
/// Returns a [CustomIntervalSelection] via `Navigator.pop` when the user taps
/// Save with a valid value. Returns `null` if the user taps Cancel, taps
/// outside the dialog, or presses back — callers must treat a null result as
/// "no change" so an incomplete/invalid entry never reaches the caller state.
class CustomIntervalDialog extends StatefulWidget {
  final int? initialValue;
  final CustomIntervalUnit? initialUnit;

  const CustomIntervalDialog({
    Key? key,
    this.initialValue,
    this.initialUnit,
  }) : super(key: key);

  @override
  State<CustomIntervalDialog> createState() => _CustomIntervalDialogState();
}

class _CustomIntervalDialogState extends State<CustomIntervalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late CustomIntervalUnit _unit;

  @override
  void initState() {
    super.initState();
    _valueController =
        TextEditingController(text: (widget.initialValue ?? 1).toString());
    _unit = widget.initialUnit ?? CustomIntervalUnit.month;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
          CustomIntervalSelection(int.parse(_valueController.text), _unit));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Custom".i18n),
      content: Form(
        key: _formKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Semantics(
                identifier: 'custom-interval-value-field',
                child: TextFormField(
                  controller: _valueController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return "Enter a valid number".i18n;
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                identifier: 'custom-interval-unit-field',
                child: DropdownButtonFormField<CustomIntervalUnit>(
                  initialValue: _unit,
                  isExpanded: true,
                  items: CustomIntervalUnit.values
                      .map((unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(customIntervalUnitString(unit)),
                          ))
                      .toList(),
                  onChanged: (unit) {
                    if (unit != null) {
                      setState(() => _unit = unit);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Semantics(
              identifier: 'custom-interval-dialog-cancel',
              child: Text("Cancel".i18n)),
        ),
        TextButton(
          onPressed: _save,
          child: Semantics(
              identifier: 'custom-interval-dialog-save',
              child: Text("Save".i18n)),
        ),
      ],
    );
  }
}
