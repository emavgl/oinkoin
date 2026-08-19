import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:flutter/services.dart' show rootBundle;
import 'package:i18n_extension/i18n_extension.dart' show I18n;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-calculator.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import 'logger.dart';

/// Builds a human-readable PDF report from a list of records.
///
/// The report mirrors the statistics page: totals, averages and medians for
/// Expenses, Income and Balance, a native vector bar chart per section, and a
/// per-category breakdown. The records table uses resolved, human-readable
/// fields (wallet names, category names, formatted dates and amounts) instead
/// of raw database values.
/// The sections that can be included in an exported PDF report.
enum PdfSection { expenses, income, balance, records }

class PDFExporter {
  static final _logger = Logger.withClass(PDFExporter);

  static const double _contentWidth = 523;

  /// Generates the PDF bytes for [records].
  ///
  /// [walletNames] maps wallet IDs to display names, [walletCurrencyMap] maps
  /// wallet IDs to currency codes so amounts can be formatted with symbols.
  /// [sections] selects which sections to render; all are included by default.
  static Future<Uint8List> createPdfFromRecordList(
    List<Record?> records, {
    required DateTime from,
    required DateTime to,
    Map<int, String>? walletNames,
    Map<int, String?> walletCurrencyMap = const {},
    Set<PdfSection> sections = const {
      PdfSection.expenses,
      PdfSection.income,
      PdfSection.balance,
      PdfSection.records,
    },
  }) async {
    try {
      final nonTransferRecords = records
          .where((r) => r != null && !r.isTransfer)
          .cast<Record>()
          .toList();
      final baseFont = await _loadBaseFont();
      final theme = pw.ThemeData.withFont(base: baseFont, bold: baseFont);

      final document = pw.Document(
        theme: theme,
        title: 'Oinkoin ${"Report".i18n}',
        author: 'Oinkoin',
        subject: getDateRangeStr(from, to),
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
          maxPages: 2000,
          theme: theme,
          header: (context) =>
              _buildHeader(from, to),
          build: (context) => _buildSections(
            nonTransferRecords,
            from: from,
            to: to,
            walletNames: walletNames ?? const {},
            walletCurrencyMap: walletCurrencyMap,
            sections: sections,
          ),
        ),
      );

      _logger.info(
        'PDF created for ${nonTransferRecords.length} records',
      );
      return await document.save();
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to create PDF');
      rethrow;
    }
  }

  /// Selects a base font that can render the active locale. The bundled Noto
  /// fonts (covering Latin, symbols and CJK) are embedded so currency symbols
  /// and non-Latin scripts render correctly. Chinese uses the SC variant, all
  /// other locales use the JP variant.
  static Future<pw.Font> _loadBaseFont() async {
    final code = I18n.locale.languageCode;
    if (code == 'zh') {
      return pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'),
      );
    }
    return pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'),
    );
  }

  static pw.Widget _buildHeader(DateTime from, DateTime to) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Oinkoin',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.Text(
            getDateRangeStr(from, to),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildSections(
    List<Record> records, {
    required DateTime from,
    required DateTime to,
    required Map<int, String> walletNames,
    required Map<int, String?> walletCurrencyMap,
    required Set<PdfSection> sections,
  }) {
    // Each selected section starts on a fresh page. Groups are joined with
    // pw.NewPage(), so no page break precedes the very first section.
    final groups = <List<pw.Widget>>[];

    final hasSelectedStats = sections.contains(PdfSection.expenses) ||
        sections.contains(PdfSection.income) ||
        sections.contains(PdfSection.balance);

    if (hasSelectedStats && records.isNotEmpty) {
      final expenseRecords = records
          .where((r) => r.category?.categoryType == CategoryType.expense)
          .toList();
      final incomeRecords = records
          .where((r) => r.category?.categoryType == CategoryType.income)
          .toList();

      if (sections.contains(PdfSection.expenses) && expenseRecords.isNotEmpty) {
        groups.add([
          _buildStatisticsSection(
            title: 'Expenses'.i18n,
            records: expenseRecords,
            from: from,
            to: to,
            walletNames: walletNames,
            walletCurrencyMap: walletCurrencyMap,
            isBalance: false,
            chartColor: PdfColors.red,
          ),
        ]);
      }
      if (sections.contains(PdfSection.income) && incomeRecords.isNotEmpty) {
        groups.add([
          _buildStatisticsSection(
            title: 'Income'.i18n,
            records: incomeRecords,
            from: from,
            to: to,
            walletNames: walletNames,
            walletCurrencyMap: walletCurrencyMap,
            isBalance: false,
            chartColor: PdfColors.green,
          ),
        ]);
      }
      if (sections.contains(PdfSection.balance) && records.isNotEmpty) {
        groups.add([
          _buildStatisticsSection(
            title: 'Balance'.i18n,
            records: records,
            from: from,
            to: to,
            walletNames: walletNames,
            walletCurrencyMap: walletCurrencyMap,
            isBalance: true,
            chartColor: PdfColors.blue,
          ),
        ]);
      }
    }

    if (sections.contains(PdfSection.records)) {
      groups.add(_buildRecordsSection(records, walletNames, walletCurrencyMap));
    }

    final widgets = <pw.Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) {
        widgets.add(pw.NewPage());
      }
      widgets.addAll(groups[i]);
    }
    return widgets;
  }

  static pw.Widget _buildStatisticsSection({
    required String title,
    required List<Record> records,
    required DateTime from,
    required DateTime to,
    required Map<int, String> walletNames,
    required Map<int, String?> walletCurrencyMap,
    required bool isBalance,
    required PdfColor chartColor,
  }) {
    final aggregationMethod =
        getAggregationMethodGivenTheTimeRange(from, to);
    final totalResult =
        computeConvertedTotal(records, walletCurrencyMap,
            isAbsValue: !isBalance);
    final currency = totalResult.currency;

    final average = isBalance
        ? (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyAverage(records, from, to,
                isBalance: true)
            : StatisticsCalculator.calculateAverage(
                records, aggregationMethod, from, to,
                isBalance: true))
        : (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyAverage(records, from, to)
            : StatisticsCalculator.calculateAverage(
                records, aggregationMethod, from, to));

    final median = isBalance
        ? (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyMedian(records, from, to,
                isBalance: true)
            : StatisticsCalculator.calculateMedian(
                records, aggregationMethod, from, to,
                isBalance: true))
        : (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyMedian(records, from, to)
            : StatisticsCalculator.calculateMedian(
                records, aggregationMethod, from, to));

    // When colorize is enabled, expenses render in red, income in green and
    // balance values are colored by sign, matching the in-app statistics page.
    final colorize = _colorizeEnabled();
    final PdfColor? Function(double) colorFor = isBalance
        ? _amountColor
        : (value) => colorize ? chartColor : null;

    final statStyle =
        pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey900);
    pw.TextStyle styled(pw.TextStyle style, PdfColor? color) => color == null
        ? style
        : style.copyWith(color: color);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('${'Total'.i18n}: ${formatRecordsTotalResult(totalResult)}',
            style: styled(statStyle, colorFor(totalResult.total))),
        pw.SizedBox(height: 2),
        pw.Text(
            '${'Average'.i18n}: ${_formatStatValue(average, currency)}',
            style: styled(statStyle, colorFor(average))),
        pw.SizedBox(height: 2),
        pw.Text('${'Median'.i18n}: ${_formatStatValue(median, currency)}',
            style: styled(statStyle, colorFor(median))),
        pw.SizedBox(height: 10),
        _buildChart(
          records: records,
          from: from,
          to: to,
          aggregationMethod: aggregationMethod,
          signed: isBalance,
          color: chartColor,
        ),
        pw.SizedBox(height: 10),
        _buildCategoryBreakdown(records, walletCurrencyMap,
            isAbsValue: !isBalance, colorFor: colorFor),
        pw.SizedBox(height: 10),
        _buildWalletBreakdown(records, walletNames, walletCurrencyMap,
            isAbsValue: !isBalance, colorFor: colorFor),
        pw.SizedBox(height: 10),
        _buildTagBreakdown(records, walletCurrencyMap,
            isAbsValue: !isBalance, colorFor: colorFor),
        pw.SizedBox(height: 24),
      ],
    );
  }

  static String _formatStatValue(double value, String? currency) {
    if (currency != null && currency.isNotEmpty) {
      return formatAmountWithCurrency(value, currency);
    }
    return getCurrencyValueString(value);
  }

  /// Whether the "Colorize income and expenses" setting is enabled.
  static bool _colorizeEnabled() => getAmountColor(1, Brightness.light) != null;

  /// Returns the PDF color for [amount] based on its sign (green for
  /// positive/zero, red for negative) when colorization is enabled, else null.
  static PdfColor? _amountColor(double amount) {
    final color = getAmountColor(amount, Brightness.light);
    if (color == null) return null;
    return PdfColor.fromInt(color.toARGB32() & 0xFFFFFF);
  }

  /// Builds a native vector bar chart for the aggregated records of a section.
  static pw.Widget _buildChart({
    required List<Record> records,
    required DateTime from,
    required DateTime to,
    required AggregationMethod aggregationMethod,
    required bool signed,
    required PdfColor color,
  }) {
    final points =
        _buildChartPoints(records, from, to, aggregationMethod, signed: signed);
    final maxAbs =
        points.fold<double>(0.0, (m, p) => math.max(m, p.value.abs()));
    if (points.isEmpty || maxAbs <= 0) {
      return pw.SizedBox.shrink();
    }

    final labels = points.map((p) => p.label).toList();
    final n = labels.length;
    final yTicks = _niceTicks(0, maxAbs);
    final xTicks = _buildXTicks(labels);
    final barWidth = math.min(16.0, _contentWidth / n * 0.55);

    // Dynamically size the chart so bars group toward the center instead of
    // spreading across the full page width when there are few data points.
    final chartWidth =
        math.min(_contentWidth, math.max(220.0, n * 26.0 + 40.0));

    final datasets = <_BarDataSet>[];
    if (signed) {
      final positive = <pw.PointChartValue>[];
      final negative = <pw.PointChartValue>[];
      for (var i = 0; i < n; i++) {
        if (points[i].value >= 0) {
          positive
              .add(pw.PointChartValue(i.toDouble(), points[i].value.abs()));
        } else {
          negative.add(pw.PointChartValue(i.toDouble(), points[i].value.abs()));
        }
      }
      if (positive.isNotEmpty) {
        datasets.add(_BarDataSet(positive, PdfColors.green));
      }
      if (negative.isNotEmpty) {
        datasets.add(_BarDataSet(negative, PdfColors.red));
      }
    } else {
      datasets.add(_BarDataSet(
        List.generate(
            n, (i) => pw.PointChartValue(i.toDouble(), points[i].value)),
        color,
      ));
    }

    final axisLabelStyle =
        pw.TextStyle(fontSize: 8, color: PdfColors.grey700);

    final barValueLabel = n <= 12
        ? (pw.Context context, pw.PointChartValue v) => pw.Text(
              _formatAxisValue(points[v.x.toInt()].value),
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.blueGrey800,
              ),
            )
        : null;

    return pw.Center(
      child: pw.SizedBox(
        width: chartWidth,
        height: 150,
        child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis<int>(
            xTicks,
            ticks: false,
            buildLabel: (v) =>
                pw.Text(labels[v.toInt()], style: axisLabelStyle),
          ),
          yAxis: pw.FixedAxis<double>(
            yTicks,
            format: (v) => _formatAxisValue(v.toDouble()),
            ticks: true,
            divisions: true,
            divisionsColor: PdfColors.grey300,
            divisionsWidth: 0.4,
            textStyle: axisLabelStyle,
          ),
        ),
        datasets: [
          for (final d in datasets)
            pw.BarDataSet<pw.PointChartValue>(
              data: d.data,
              color: d.color,
              width: barWidth,
              drawPoints: false,
              buildValue: barValueLabel,
            ),
        ],
      ),
    ),
    );
  }

  static List<_ChartPoint> _buildChartPoints(
    List<Record> records,
    DateTime from,
    DateTime to,
    AggregationMethod method, {
    required bool signed,
  }) {
    final config = ChartDateRangeConfig.create(method, from, to);
    final byKey = <String, double>{};
    for (final r in records) {
      final key = config.getKey(truncateDateTime(r.dateTime, method));
      final value = signed ? (r.value ?? 0) : (r.value ?? 0).abs();
      byKey[key] = (byKey[key] ?? 0) + value;
    }

    final points = <_ChartPoint>[];
    var current = config.start;
    while (!current.isAfter(config.end)) {
      final key = config.getKey(truncateDateTime(current, method));
      points.add(_ChartPoint(key, byKey[key] ?? 0));
      current = config.advance(current);
    }
    return points;
  }

  static List<int> _buildXTicks(List<String> labels) {
    final n = labels.length;
    if (n <= 1) return n == 1 ? [0] : const [];
    final target = math.min(8, n);
    final ticks = <int>[];
    for (var i = 0; i < target; i++) {
      ticks.add((i * (n - 1) / (target - 1)).round());
    }
    return ticks;
  }

  static List<double> _niceTicks(double min, double max, {int target = 5}) {
    if (min == max) return [min];
    final range = max - min;
    final rawStep = range / target;
    final magnitude =
        math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;
    final double step;
    if (residual < 1.5) {
      step = magnitude;
    } else if (residual < 3) {
      step = 2 * magnitude;
    } else if (residual < 7) {
      step = 5 * magnitude;
    } else {
      step = 10 * magnitude;
    }
    final start = (min / step).floor() * step;
    final ticks = <double>[];
    for (var v = start; v <= max + step * 0.5; v += step) {
      ticks.add(v);
    }
    return ticks;
  }

  static String _formatAxisValue(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  static pw.Widget _buildCategoryBreakdown(
    List<Record> records,
    Map<int, String?> walletCurrencyMap, {
    required bool isAbsValue,
    required PdfColor? Function(double) colorFor,
  }) {
    final groups = <String, List<Record>>{};
    for (final r in records) {
      final name = r.category?.name ?? '—';
      groups.putIfAbsent(name, () => []).add(r);
    }

    final rows = groups.entries.map((e) {
      final total =
          computeConvertedTotal(e.value, walletCurrencyMap,
              isAbsValue: isAbsValue);
      return _SplitRow(e.key, formatRecordsTotalResult(total), total.total);
    }).toList()
      ..sort((a, b) => b.total.abs().compareTo(a.total.abs()));

    if (rows.isEmpty) return pw.SizedBox.shrink();
    return _buildSplitTable('Category'.i18n, rows,
        colorFor: colorFor);
  }

  static pw.Widget _buildWalletBreakdown(
    List<Record> records,
    Map<int, String> walletNames,
    Map<int, String?> walletCurrencyMap, {
    required bool isAbsValue,
    required PdfColor? Function(double) colorFor,
  }) {
    final groups = <int, List<Record>>{};
    for (final r in records) {
      if (r.walletId == null) continue;
      groups.putIfAbsent(r.walletId!, () => []).add(r);
    }

    final rows = groups.entries.map((e) {
      final total =
          computeConvertedTotal(e.value, walletCurrencyMap,
              isAbsValue: isAbsValue);
      final name = walletNames[e.key] ?? '—';
      return _SplitRow(name, formatRecordsTotalResult(total), total.total);
    }).toList()
      ..sort((a, b) => b.total.abs().compareTo(a.total.abs()));

    if (rows.isEmpty) return pw.SizedBox.shrink();
    return _buildSplitTable('Wallet'.i18n, rows, colorFor: colorFor);
  }

  static pw.Widget _buildTagBreakdown(
    List<Record> records,
    Map<int, String?> walletCurrencyMap, {
    required bool isAbsValue,
    required PdfColor? Function(double) colorFor,
  }) {
    final groups = <String, List<Record>>{};
    for (final r in records) {
      for (final tag in r.tags) {
        groups.putIfAbsent(tag, () => []).add(r);
      }
    }

    final rows = groups.entries.map((e) {
      final total =
          computeConvertedTotal(e.value, walletCurrencyMap,
              isAbsValue: isAbsValue);
      return _SplitRow(e.key, formatRecordsTotalResult(total), total.total);
    }).toList()
      ..sort((a, b) => b.total.abs().compareTo(a.total.abs()));

    if (rows.isEmpty) return pw.SizedBox.shrink();
    return _buildSplitTable('Tags'.i18n, rows, colorFor: colorFor);
  }

  /// Builds a two-column split table (label / amount) for a statistics section.
  static pw.Widget _buildSplitTable(
    String title,
    List<_SplitRow> rows, {
    required PdfColor? Function(double) colorFor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$title:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [
            title,
            'Amount'.i18n,
          ],
          data: rows
              .map((r) => [r.name, _coloredAmountText(r.amount, colorFor(r.total))])
              .toList(),
          headerStyle: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellAlignments: {1: pw.Alignment.centerRight},
          columnWidths: {
            0: pw.FractionColumnWidth(0.7),
            1: pw.FractionColumnWidth(0.3),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.4,
          ),
        ),
      ],
    );
  }

  /// Wraps [text] in a right-aligned, optionally colored cell.
  static pw.Widget _coloredAmountText(String text, PdfColor? color,
      {double fontSize = 10}) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        text,
        style: color == null
            ? pw.TextStyle(fontSize: fontSize)
            : pw.TextStyle(fontSize: fontSize, color: color),
      ),
    );
  }

  static List<pw.Widget> _buildRecordsSection(
    List<Record> records,
    Map<int, String> walletNames,
    Map<int, String?> walletCurrencyMap,
  ) {
    if (records.isEmpty) {
      return [
        pw.Text(
          'No records to export'.i18n,
          style: pw.TextStyle(
            fontSize: 12,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600,
          ),
        ),
      ];
    }

    final rows = records.map((r) {
      return <dynamic>[
        getDateStr(r.dateTime),
        r.title ?? '',
        r.category?.name ?? '—',
        r.category?.categoryType == CategoryType.income
            ? 'Income'.i18n
            : 'Expense'.i18n,
        _coloredAmountText(
          _formatRecordAmount(r, walletCurrencyMap),
          _amountColor(r.value ?? 0),
          fontSize: 9,
        ),
        r.walletId != null ? (walletNames[r.walletId] ?? '') : '',
        r.tags.join(', '),
      ];
    }).toList();

    // NOTE: the table must be a direct child of MultiPage, not wrapped in a
    // Column/Flex. pdf 3.12.0's Flex does not delegate page-breaking to a
    // spanning Table child, which would loop forever and throw
    // TooManyPagesException for tables larger than one page.
    return [
      pw.Text(
        'Records'.i18n,
        style: pw.TextStyle(
          fontSize: 17,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: [
          'Date'.i18n,
          'Title'.i18n,
          'Category'.i18n,
          'Type'.i18n,
          'Amount'.i18n,
          'Wallet'.i18n,
          'Tags'.i18n,
        ],
        data: rows,
        headerStyle: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey700),
        cellStyle: pw.TextStyle(fontSize: 9),
        cellAlignments: {4: pw.Alignment.centerRight},
        columnWidths: {
          0: pw.FixedColumnWidth(64),
          1: pw.FixedColumnWidth(105),
          2: pw.FixedColumnWidth(88),
          3: pw.FixedColumnWidth(48),
          4: pw.FixedColumnWidth(95),
          5: pw.FixedColumnWidth(58),
          6: pw.FixedColumnWidth(50),
        },
        border: pw.TableBorder.all(
          color: PdfColors.grey300,
          width: 0.4,
        ),
      ),
    ];
  }

  static String _formatRecordAmount(
    Record record,
    Map<int, String?> walletCurrencyMap,
  ) {
    final currency =
        (record.walletId != null ? walletCurrencyMap[record.walletId] : null) ??
            '';
    return formatAmountWithCurrency(record.value ?? 0, currency);
  }
}

class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint(this.label, this.value);
}

class _BarDataSet {
  final List<pw.PointChartValue> data;
  final PdfColor color;
  _BarDataSet(this.data, this.color);
}

class _SplitRow {
  final String name;
  final String amount;
  final double total;
  _SplitRow(this.name, this.amount, this.total);
}