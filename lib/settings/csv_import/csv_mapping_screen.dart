import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/csv_import_mapping.dart';
import 'package:piggybank/models/record.dart' as models;
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/service-config.dart';
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
  CsvImportPreview? _preview;
  int _sampleIndex = 0;
  late List<int> _parsableRowIndices;

  /// Cache of pre-parsed money values: columnHeader → parsed result per row.
  Map<String, List<double?>> _moneyCache = {};

  /// Cache of pre-parsed date values: columnHeader → parsed result per row.
  Map<String, List<int?>> _dateCache = {};
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _mapping = widget.initialMapping;
    // Parse in small batches, yielding to the event loop between each
    // batch so the spinner animates smoothly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-allocate cache lists once.
      _moneyCache = {
        for (final h in widget.headers)
          h: List.filled(widget.rows.length, null),
      };
      _dateCache = {
        for (final h in widget.headers)
          h: List.filled(widget.rows.length, null),
      };
      _parseBatches(0);
    });
  }

  void _parseBatches(int rowStart) {
    const batchSize = 80;
    final headers = widget.headers;
    final rows = widget.rows;
    final end = (rowStart + batchSize).clamp(0, rows.length);

    for (int i = rowStart; i < end; i++) {
      final row = rows[i];
      for (final h in headers) {
        _moneyCache[h]![i] = CsvImportService.parseMoney(row[h]);
        _dateCache[h]![i] = CsvImportService.parseToMs(row[h]);
      }
    }

    if (end < rows.length) {
      setState(() => _progress = end / rows.length);
      Future.delayed(Duration.zero, () => _parseBatches(end));
    } else {
      _parsableRowIndices = _computeParsableRowIndices();
      setState(() => _progress = 1);
    }
  }

  List<int> _computeParsableRowIndices() {
    final moneyCol = _mapping.valueColumn;
    final dateCol = _mapping.datetimeColumn;
    if (moneyCol == null || dateCol == null) return [];
    final moneyValues = _moneyCache[moneyCol];
    final dateValues = _dateCache[dateCol];
    if (moneyValues == null || dateValues == null) return [];
    final indices = <int>[];
    for (int i = 0; i < widget.rows.length; i++) {
      if (moneyValues[i] != null && dateValues[i] != null) {
        indices.add(i);
      }
    }
    return indices;
  }

  Map<String, String>? _sampleCsvRowForIndex(int index) {
    if (_parsableRowIndices.isEmpty) return null;
    final rowIdx =
        _parsableRowIndices[index.clamp(0, _parsableRowIndices.length - 1)];
    return Map.from(widget.rows[rowIdx]);
  }

  models.Record? _sampleRecordForIndex(int index) {
    if (_parsableRowIndices.isEmpty) return null;
    final rowIdx =
        _parsableRowIndices[index.clamp(0, _parsableRowIndices.length - 1)];
    return CsvImportService.rowToRecord(widget.rows[rowIdx], _mapping);
  }

  void _nextSample() {
    if (_parsableRowIndices.length <= 1) return;
    setState(() {
      _sampleIndex = (_sampleIndex + 1) % _parsableRowIndices.length;
    });
  }

  void _onMappingChanged(String field, String? column) {
    setState(() {
      _mapping.setColumn(field, column);
      _parsableRowIndices = _computeParsableRowIndices();
      _sampleIndex = 0;
      _preview = null; // invalidate — will be recomputed on Continue
    });
  }

  /// Builds a preview from the cached pre-parsed values (no re-parsing).
  CsvImportPreview _buildPreviewFromCache() {
    final moneyCol = _mapping.valueColumn;
    final dateCol = _mapping.datetimeColumn;
    final catCol = _mapping.categoryColumn;
    final tagCol = _mapping.tagsColumn;
    final walletCol = _mapping.walletColumn;

    int parsable = 0;
    int unparseable = 0;
    final categories = <String>{};
    final tags = <String>{};
    final wallets = <String>{};
    int? earliestMs;
    int? latestMs;

    for (int i = 0; i < widget.rows.length; i++) {
      final row = widget.rows[i];
      final moneyValues = moneyCol != null ? _moneyCache[moneyCol] : null;
      final dateValues = dateCol != null ? _dateCache[dateCol] : null;
      final value = moneyValues != null ? moneyValues[i] : null;
      final dateMs = dateValues != null ? dateValues[i] : null;

      if (value != null && dateMs != null) {
        parsable++;

        final cat =
            catCol != null ? (row[catCol] ?? 'Uncategorized') : 'Uncategorized';
        categories.add(cat);

        if (earliestMs == null || dateMs < earliestMs) earliestMs = dateMs;
        if (latestMs == null || dateMs > latestMs) latestMs = dateMs;

        if (tagCol != null) {
          final raw = row[tagCol];
          if (raw != null && raw.isNotEmpty) {
            for (final t in raw.split(RegExp(r'[;,]'))) {
              final trimmed = t.trim();
              if (trimmed.isNotEmpty) tags.add(trimmed);
            }
          }
        }

        if (walletCol != null) {
          final w = row[walletCol];
          if (w != null && w.trim().isNotEmpty) {
            wallets.add(w.trim());
          }
        }
      } else {
        unparseable++;
      }
    }

    final warnings = <String>[];
    if (!_mapping.hasMinimumMapping) {
      warnings.add(
          'Amount and Date/Time columns must be mapped for records to be imported.');
    }
    if (unparseable > 0) {
      warnings
          .add('$unparseable row(s) could not be parsed and will be skipped.');
    }
    if (parsable == 0) {
      warnings.add('No records can be imported with the current mapping.');
    }

    return CsvImportPreview(
      totalParsableRows: parsable,
      unparseableRows: unparseable,
      uniqueCategories: categories.toList()..sort(),
      uniqueTags: tags.toList()..sort(),
      uniqueWallets: wallets.toList()..sort(),
      earliestDate: earliestMs != null
          ? DateTime.fromMillisecondsSinceEpoch(earliestMs, isUtc: true)
          : null,
      latestDate: latestMs != null
          ? DateTime.fromMillisecondsSinceEpoch(latestMs, isUtc: true)
          : null,
      warnings: warnings,
    );
  }

  // -------------------------------------------------------------------------
  // Saved mappings (SharedPreferences)
  // -------------------------------------------------------------------------

  static const _savedMappingsKey = 'csv_import_saved_mappings';

  Future<Map<String, String>> _loadSavedMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedMappingsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveMapping(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final mappings = await _loadSavedMappings();
    mappings[name] = jsonEncode(_mapping.toJson());
    await prefs.setString(_savedMappingsKey, jsonEncode(mappings));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mapping "$name" saved.'.i18n),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMapping(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final mappings = await _loadSavedMappings();
    mappings.remove(name);
    await prefs.setString(_savedMappingsKey, jsonEncode(mappings));
  }

  Future<void> _showSaveMappingDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save Mapping'.i18n),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Mapping name'.i18n,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.i18n),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save'.i18n),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _saveMapping(name);
    }
  }

  Future<void> _showLoadMappingSheet() async {
    final mappings = await _loadSavedMappings();
    if (mappings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No saved mappings found.'.i18n),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final entries = mappings.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Load Saved Mapping'.i18n,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    return ListTile(
                      title: Text(entry.key),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.redAccent),
                        onPressed: () async {
                          await _deleteMapping(entry.key);
                          Navigator.pop(ctx, '__deleted__');
                        },
                      ),
                      onTap: () => Navigator.pop(ctx, entry.key),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result == '__deleted__') {
      if (result == '__deleted__' && mounted) {
        // Refresh the sheet
        _showLoadMappingSheet();
      }
      return;
    }

    // Load the selected mapping
    final jsonStr = mappings[result]!;
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final loaded = CsvImportMapping.fromJson(decoded);
      setState(() {
        _mapping = loaded;
        _parsableRowIndices = _computeParsableRowIndices();
        _sampleIndex = 0;
        _preview = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load mapping: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _continueToSummary() {
    if (!_mapping.hasMinimumMapping) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please map the Amount, Category, and Date/Time columns to continue.'
                .i18n,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Compute preview from cache (fast — no re-parsing).
    _preview = _buildPreviewFromCache();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CsvImportSummaryScreen(
          rows: widget.rows,
          mapping: _mapping,
          preview: _preview!,
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
        actions: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Save Mapping'.i18n,
            icon: const Icon(Icons.save_outlined),
            onPressed: _showSaveMappingDialog,
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Load Mapping'.i18n,
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _showLoadMappingSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _progress < 1
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 16),
                    Text(
                      'Parsing CSV data'.i18n,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          : Column(
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
                        if (!_mapping.hasMinimumMapping)
                          _buildMinimumWarning(theme),

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
              'Map each Oinkoin field to the corresponding column in your CSV file. Columns were auto-detected where possible.'
                  .i18n,
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
    final isWallet = field == 'wallet';
    final isWalletLocked = isWallet && !ServiceConfig.isPremium;

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
        child: isWalletLocked
            ? InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PremiumSplashScreen()),
                ),
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

                      // Arrow (always shown)
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),

                      // PRO label instead of dropdown
                      getProLabel(labelFontSize: 10.0),
                    ],
                  ),
                ),
              )
            : Padding(
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

                    // Arrow (always shown)
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
              'Amount, Category, and Date/Time columns are required. No records will be imported without them.'
                  .i18n,
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
    final row = _sampleCsvRowForIndex(_sampleIndex);
    final record = _sampleRecordForIndex(_sampleIndex);

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
          _buildPreviewTable(_recordToMap(record, csvRow: row), theme,
              isOinkoin: true),
        ],
        if (_preview != null && _preview!.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._preview!.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 14, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontSize:
                            (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
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

  Map<String, String> _recordToMap(dynamic record,
      {Map<String, String>? csvRow}) {
    String formatDate(int? ms) {
      if (ms == null) return '—';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    }

    String formatMoney(double? v) {
      if (v == null) return '—';
      return v.toStringAsFixed(2);
    }

    // Show '—' when a column is not mapped at all; show actual value
    // (even if empty) when the column is mapped.
    String _mapped(String field, String? value) =>
        _mapping.columnFor(field) != null ? (value ?? '') : '—';

    // For wallet, prefer the original CSV value when available (preview mode
    // has no DB, so walletId is null). Fall back to the resolved ID otherwise.
    String _walletValue() {
      final col = _mapping.columnFor('wallet');
      if (col == null) return '—';
      if (csvRow != null && csvRow.containsKey(col)) {
        return csvRow[col]!.isEmpty ? '' : csvRow[col]!;
      }
      return record.walletId?.toString() ?? '';
    }

    return {
      CsvImportMapping.fieldLabels['title']!: _mapped('title', record.title),
      CsvImportMapping.fieldLabels['value']!: formatMoney(record.value),
      CsvImportMapping.fieldLabels['datetime']!: formatDate(record.utcDateTime?.millisecondsSinceEpoch),
      CsvImportMapping.fieldLabels['category_name']!: _mapping.columnFor('category_name') != null
          ? (record.category?.name ?? '')
          : '—',
      CsvImportMapping.fieldLabels['description']!: _mapped('description', record.description),
      CsvImportMapping.fieldLabels['tags']!: _mapped(
          'tags',
          (record.tags != null && record.tags!.isNotEmpty)
              ? record.tags!.join(', ')
              : ''),
      CsvImportMapping.fieldLabels['wallet']!: _walletValue(),
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
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _parsableRowIndices.length > 1 ? _nextSample : null,
              icon: const Icon(Icons.shuffle, size: 18),
              label: Text('Next Sample'.i18n),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _mapping.hasMinimumMapping ? _continueToSummary : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text('Continue'.i18n),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
