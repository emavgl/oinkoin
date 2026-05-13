import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/settings/csv_import/csv_preview_screen.dart';

/// First screen of the CSV import flow.
///
/// Allows the user to provide CSV content by selecting a file from disk or
/// pasting from the clipboard. On success, navigates to [CsvPreviewScreen].
/// On error, shows a Snackbar.
class CsvImportPage extends StatefulWidget {
  const CsvImportPage({super.key});

  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  bool _isLoading = false;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);

    try {
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
      setState(() => _isLoading = false);
      _showError('Could not read file: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    setState(() => _isLoading = true);

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data == null || data.text == null || data.text!.trim().isEmpty) {
        setState(() => _isLoading = false);
        _showError('Clipboard is empty or does not contain valid CSV'.i18n);
        return;
      }
      _processContent(data.text!);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Could not read clipboard: $e');
    }
  }

  void _processContent(String content) {
    try {
      final parsed = CsvImportService.parseCsv(content);
      final headers = parsed.headers;
      final rows = parsed.rows;

      if (headers.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Could not parse CSV'.i18n);
        return;
      }

      if (rows.isEmpty) {
        setState(() => _isLoading = false);
        _showError('CSV file has headers but no data rows.');
        return;
      }

      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CsvPreviewScreen(
            headers: headers,
            rows: rows,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Could not parse CSV: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
                  _buildActionCard(
                    icon: Icons.file_upload,
                    label: 'Select CSV File'.i18n,
                    subtitle: 'Choose a CSV file from your device',
                    onTap: _pickFile,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.paste,
                    label: 'Paste from Clipboard'.i18n,
                    subtitle: 'Use CSV content currently in your clipboard',
                    onTap: _pasteFromClipboard,
                    color: Colors.teal.shade600,
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
