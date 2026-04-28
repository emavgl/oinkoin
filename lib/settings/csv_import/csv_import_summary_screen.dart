import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/services/logger.dart';

/// Third and final screen of the CSV import flow.
///
/// Displays a summary of what will be imported (record count, categories,
/// date range, tags) and any warnings about unparseable rows. The user
/// confirms to execute the import.
class CsvImportSummaryScreen extends StatefulWidget {
  final List<Map<String, String>> rows;
  final CsvImportMapping mapping;
  final CsvImportPreview preview;

  const CsvImportSummaryScreen({
    super.key,
    required this.rows,
    required this.mapping,
    required this.preview,
  });

  @override
  State<CsvImportSummaryScreen> createState() => _CsvImportSummaryScreenState();
}

class _CsvImportSummaryScreenState extends State<CsvImportSummaryScreen> {
  static final _logger = Logger.withClass(_CsvImportSummaryScreenState);

  bool _isImporting = false;
  CsvImportResult? _result;
  String? _error;

  Future<void> _doImport() async {
    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final result = await CsvImportService.importRecords(
        widget.rows,
        widget.mapping,
      );
      setState(() {
        _isImporting = false;
        _result = result;
      });
      _logger.info('CSV import complete: ${result.imported} imported');
    } catch (e, st) {
      _logger.handle(e, st, 'CSV import failed');
      setState(() {
        _isImporting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show result screen after import
    if (_result != null) {
      return _buildResultScreen(theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Import Summary'.i18n),
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary header
                  _buildSummaryCard(theme),
                  const SizedBox(height: 16),

                  // Warnings
                  if (widget.preview.warnings.isNotEmpty) ...[
                    _buildWarningsCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // Duplicate notice
                  _buildDuplicateNotice(theme),
                  const SizedBox(height: 16),

                  // Error
                  if (_error != null) _buildErrorContainer(theme),
                ],
              ),
            ),
      bottomNavigationBar: _isImporting
          ? null
          : _buildBottomBar(theme),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final p = widget.preview;

    String dateRangeStr = '—';
    if (p.earliestDate != null && p.latestDate != null) {
      final fmt = DateFormat('yyyy-MM-dd');
      dateRangeStr = '${fmt.format(p.earliestDate!.toLocal())}  →  ${fmt.format(p.latestDate!.toLocal())}';
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Summary'.i18n,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _summaryRow(
              icon: Icons.receipt_long,
              label: 'Records to import'.i18n,
              value: '${p.totalParsableRows}',
              theme: theme,
            ),
            if (p.unparseableRows > 0)
              _summaryRow(
                icon: Icons.warning_amber,
                label: 'Unparseable rows'.i18n,
                value: '${p.unparseableRows}',
                valueColor: theme.colorScheme.error,
                theme: theme,
              ),
            _summaryRow(
              icon: Icons.category,
              label: 'Unique categories'.i18n,
              value: '${p.uniqueCategories.length}',
              theme: theme,
            ),
            _summaryRow(
              icon: Icons.tag,
              label: 'Unique tags'.i18n,
              value: '${p.uniqueTags.length}',
              theme: theme,
            ),
            _summaryRow(
              icon: Icons.account_balance_wallet,
              label: 'Unique wallets'.i18n,
              value: '${p.uniqueWallets.length}',
              theme: theme,
            ),
            _summaryRow(
              icon: Icons.date_range,
              label: 'Date range'.i18n,
              value: dateRangeStr,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Warnings'.i18n,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...widget.preview.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(top: 2, left: 26),
              child: Text(
                '• $w',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Duplicate records (same datetime, value, title, category, and wallet) will be skipped automatically.'.i18n,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContainer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Back'.i18n),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.preview.totalParsableRows > 0
                    ? _doImport
                    : null,
                icon: const Icon(Icons.upload),
                label: Text('Import'.i18n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result screen ────────────────────────────────────────────────────────

  Widget _buildResultScreen(ThemeData theme) {
    final r = _result!;
    final isSuccess = r.isSuccess;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSuccess ? 'Import Complete'.i18n : 'Import Failed'.i18n),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                size: 64,
                color: isSuccess
                    ? Colors.green.shade600
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess ? 'Import Complete'.i18n : 'Import Failed'.i18n,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _resultRow('Records imported'.i18n, '${r.imported}', theme),
              _resultRow('Skipped (duplicates)'.i18n, '${r.skippedDuplicates}', theme),
              _resultRow('Skipped (errors)'.i18n, '${r.skippedErrors}', theme),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                ),
                child: Text('Done'.i18n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
