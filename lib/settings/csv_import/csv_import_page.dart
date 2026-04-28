import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/settings/csv_import/csv_mapping_screen.dart';

/// First screen of the CSV import flow.
///
/// Allows the user to provide CSV content by selecting a file from disk or
/// pasting from the clipboard. Shows a preview of the first few rows before
/// proceeding to column mapping.
class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  List<String>? _headers;
  List<Map<String, String>>? _rows;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Clear temp cache on supported platforms
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}

      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'tsv', 'txt'],
        );
      } catch (_) {
        // Fallback: no extension filter
        result = await FilePicker.platform.pickFiles();
      }

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        _processContent(content);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not read file: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data == null || data.text == null || data.text!.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Clipboard is empty or does not contain valid CSV'.i18n;
        });
        return;
      }
      _processContent(data.text!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not read clipboard: $e';
      });
    }
  }

  void _processContent(String content) {
    try {
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      if (headers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not parse CSV'.i18n;
        });
        return;
      }

      if (rows.isEmpty) {
        setState(() {
          _isLoading = false;
          _headers = headers;
          _rows = rows;
          _errorMessage = 'CSV file has headers but no data rows.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _headers = headers;
        _rows = rows;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not parse CSV: $e';
      });
    }
  }

  void _continueToMapping() {
    if (_headers == null || _rows == null) return;

    final mapping = CsvImportService.autoMap(_headers!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CsvMappingScreen(
          headers: _headers!,
          rows: _rows!,
          initialMapping: mapping,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Import from CSV'.i18n),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File picker button
                  _buildActionCard(
                    icon: Icons.file_upload,
                    label: 'Select CSV File'.i18n,
                    subtitle: 'Choose a CSV file from your device',
                    onTap: _pickFile,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 12),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Clipboard button
                  _buildActionCard(
                    icon: Icons.paste,
                    label: 'Paste from Clipboard'.i18n,
                    subtitle: 'Use CSV content currently in your clipboard',
                    onTap: _pasteFromClipboard,
                    color: Colors.teal.shade600,
                  ),
                  const SizedBox(height: 24),

                  // Preview area
                  if (_headers != null && _rows != null) ...[
                    _buildPreview(theme),
                    const SizedBox(height: 24),
                    if (_rows!.isNotEmpty)
                      FilledButton.icon(
                        onPressed: _continueToMapping,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text('Continue to Mapping'.i18n),
                      ),
                  ],

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 24,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final displayRows = _rows!.take(5).toList();
    final displayHeaders = _headers!.take(6).toList();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'CSV Preview'.i18n,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_rows!.length} rows, ${_headers!.length} columns',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                headingRowHeight: 36,
                columns: displayHeaders
                    .map((h) => DataColumn(
                          label: Text(
                            h,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ))
                    .toList(),
                rows: displayRows
                    .map((row) => DataRow(
                          cells: displayHeaders
                              .map((h) => DataCell(
                                    Text(
                                      row[h] ?? '',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
            if (_rows!.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${_rows!.length - 5} more rows',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
