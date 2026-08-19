import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/pdf-service.dart';

/// Dialog for choosing which sections to include in an exported PDF report.
///
/// All sections are selected by default. Returns the chosen
/// [PdfSection] set via `Navigator.pop`, or `null` when the user dismisses
/// the dialog without confirming.
class PdfExportSectionsDialog extends StatefulWidget {
  const PdfExportSectionsDialog({super.key});

  @override
  State<PdfExportSectionsDialog> createState() =>
      _PdfExportSectionsDialogState();
}

class _PdfExportSectionsDialogState extends State<PdfExportSectionsDialog> {
  final Set<PdfSection> _selected = {...PdfSection.values};

  String _sectionLabel(PdfSection section) => switch (section) {
        PdfSection.expenses => 'Expenses'.i18n,
        PdfSection.income => 'Income'.i18n,
        PdfSection.balance => 'Balance'.i18n,
        PdfSection.records => 'Records'.i18n,
      };

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == PdfSection.values.length;
    return AlertDialog(
      title: Text('Export PDF'.i18n),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select the sections to include in the PDF'.i18n),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: allSelected,
              title: Text('Select all'.i18n),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selected.addAll(PdfSection.values);
                } else {
                  _selected.clear();
                }
              }),
            ),
            const Divider(height: 8),
            for (final section in PdfSection.values)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(section),
                title: Text(_sectionLabel(section)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selected.add(section);
                  } else {
                    _selected.remove(section);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Semantics(
            identifier: 'pdf-export-dialog-cancel',
            child: Text("Cancel".i18n),
          ),
        ),
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context)
                  .pop(Set<PdfSection>.of(_selected)),
          child: Semantics(
            identifier: 'pdf-export-dialog-confirm',
            child: Text("Export".i18n),
          ),
        ),
      ],
    );
  }
}