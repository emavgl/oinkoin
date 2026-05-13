import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/csv_import_service.dart';
import 'package:piggybank/settings/csv_import/csv_mapping_screen.dart';

/// Screen shown after a CSV file has been successfully loaded.
///
/// Displays a preview of the parsed data (headers and first rows) and
/// a button to proceed to column mapping.
class CsvPreviewScreen extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, String>> rows;

  const CsvPreviewScreen({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('CSV Preview'.i18n),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_chart,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'CSV Preview'.i18n,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${rows.length} rows, ${headers.length} columns',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPreviewTable(theme),
                  if (rows.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${rows.length - 5} more rows',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _buildBottomBar(context, theme),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(ThemeData theme) {
    final displayRows = rows.take(5).toList();
    final scrollController = ScrollController();

    return Scrollbar(
      controller: scrollController,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        child: DataTable(
          columnSpacing: 16,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          headingRowHeight: 36,
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ))
              .toList(),
          rows: displayRows
              .map((row) => DataRow(
                    cells: headers
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
    );
  }

  Widget _buildBottomBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: () {
            final mapping = CsvImportService.autoMap(headers);
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 120),
                reverseTransitionDuration: const Duration(milliseconds: 120),
                pageBuilder: (_, __, ___) => CsvMappingScreen(
                  headers: headers,
                  rows: rows,
                  initialMapping: mapping,
                ),
              ),
            );
          },
          icon: const Icon(Icons.arrow_forward),
          label: Text('Continue to Mapping'.i18n),
        ),
      ),
    );
  }
}
