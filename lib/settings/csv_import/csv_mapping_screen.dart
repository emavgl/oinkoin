import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/settings/csv_import/csv_import_summary_screen.dart';

/// Second screen of the CSV import flow.
///
/// Displays each Oinkoin field with a dropdown to select the corresponding
/// CSV column. A live preview shows how the first row will be interpreted
/// with the current mapping.
class CsvMappingScreen extends StatefulWidget {
  final List<String> headers;
  final List<Map<String, String>> rows;
  final CsvImportMapping initialMapping;

  const CsvMappingScreen({
    super.key,
    required this.headers,
    required this.rows,
    required this.initialMapping,
  });

  @override
  State<CsvMappingScreen> createState() => _CsvMappingScreenState();
}

class _CsvMappingScreenState extends State<CsvMappingScreen> {
  late CsvImportMapping _mapping;
  late CsvImportPreview _preview;

  @override
  void initState() {
    super.initState();
    _mapping = widget.initialMapping;
    _preview = CsvImportService.buildPreview(widget.rows, _mapping);
  }

  void _onMappingChanged(String field, String? column) {
    setState(() {
      _mapping.setColumn(field, column);
      _preview = CsvImportService.buildPreview(widget.rows, _mapping);
    });
  }

  void _continueToSummary() {
    if (!_mapping.hasMinimumMapping) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please map at least Amount and Date/Time columns to continue.'
                .i18n,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CsvImportSummaryScreen(
          rows: widget.rows,
          mapping: _mapping,
          preview: _preview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Map Columns'.i18n),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info banner
                  _buildInfoBanner(theme),
                  const SizedBox(height: 16),

                  // Mapping dropdowns
                  ...CsvImportMapping.fieldOrder.map(
                    (field) => _buildMappingRow(field, theme),
                  ),

                  const SizedBox(height: 16),

                  // Minimum mapping warning
                  if (!_mapping.hasMinimumMapping) _buildMinimumWarning(theme),

                  const Divider(height: 32),

                  // Live preview section
                  _buildLivePreview(theme),
                ],
              ),
            ),
          ),

          // Bottom bar
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map each Oinkoin field to the corresponding column in your CSV file. Columns were auto-detected where possible.'.i18n,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingRow(String field, ThemeData theme) {
    final column = _mapping.columnFor(field);
    final label = CsvImportMapping.fieldLabels[field] ?? field;
    final isRequired = field == 'value' || field == 'datetime';

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('None'),
      ),
      ...widget.headers.map(
        (h) => DropdownMenuItem<String?>(
          value: h,
          child: Text(h),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Field label
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isRequired)
                      Text(
                        '*',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 8),

              // Dropdown
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: column,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: dropdownItems,
                  onChanged: (value) => _onMappingChanged(field, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimumWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Amount and Date/Time columns are required. No records will be imported without them.'.i18n,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(ThemeData theme) {
    final row = _preview.sampleCsvRow;
    final record = _preview.sampleRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Preview'.i18n,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: (theme.textTheme.titleSmall?.fontSize ?? 14) + 2,
          ),
        ),
        const SizedBox(height: 8),

        if (row != null) ...[
          // Original CSV row
          Text(
            'Original CSV Row'.i18n,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12) + 2,
            ),
          ),
          const SizedBox(height: 4),
          _buildPreviewTable(row, theme, isOinkoin: false),
          const SizedBox(height: 12),
        ],

        if (record != null) ...[
          // Interpreted Oinkoin record
          Text(
            'Imported Record'.i18n,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12) + 2,
            ),
          ),
          const SizedBox(height: 4),
          _buildPreviewTable(_recordToMap(record), theme, isOinkoin: true),
        ],

        if (_preview.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._preview.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewTable(
    Map<String, String> data,
    ThemeData theme, {
    required bool isOinkoin,
  }) {
    final entries = data.entries.toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: isOinkoin
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(6),
        color: isOinkoin
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : null,
      ),
      padding: const EdgeInsets.all(8),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: entries.map((e) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  e.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  e.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Map<String, String> _recordToMap(dynamic record) {
    String formatDate(int? ms) {
      if (ms == null) return '—';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    }

    String formatMoney(double? v) {
      if (v == null) return '—';
      return v.toStringAsFixed(2);
    }

    return {
      'Title': record.title ?? '',
      'Value': formatMoney(record.value),
      'Date': formatDate(record.utcDateTime?.millisecondsSinceEpoch),
      'Category': record.category?.name ?? 'Uncategorized',
      'Description': record.description ?? '—',
      'Tags': record.tags?.join(', ') ?? '—',
      'Wallet': 'ID ${record.walletId ?? "—"}',
    };
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: _mapping.hasMinimumMapping
              ? _continueToSummary
              : null,
          icon: const Icon(Icons.arrow_forward),
          label: Text('Continue'.i18n),
        ),
      ),
    );
  }
}
