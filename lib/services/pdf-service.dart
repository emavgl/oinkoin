import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Brightness, Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:i18n_extension/i18n_extension.dart' show I18n;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
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
      final fonts = await _loadFonts();
      final theme = pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.base,
        fontFallback: [fonts.fallback],
      );

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

  /// Loads the base and fallback fonts for the PDF.
  ///
  /// The base font is the locale-matched bundled Noto CJK font (Chinese uses
  /// the SC variant, all other locales the JP variant) so Latin, symbols and
  /// CJK of the active locale render correctly. Noto Sans Regular is embedded
  /// as a per-glyph fallback because the CJK variants do not include the
  /// Currency Symbols block (€, ₹, ₺, ₩, ₽, ₿, ...), which would otherwise
  /// render as blank placeholders in the report.
  static Future<({pw.Font base, pw.Font fallback})> _loadFonts() async {
    final code = I18n.locale.languageCode;
    final base = pw.Font.ttf(
      await rootBundle.load(code == 'zh'
          ? 'assets/fonts/NotoSansSC-Regular.ttf'
          : 'assets/fonts/NotoSansJP-Regular.ttf'),
    );
    final fallback = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    return (base: base, fallback: fallback);
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
            ? StatisticsCalculator.calculateDailyAverage(records, from, to,
                walletCurrencyMap: walletCurrencyMap)
            : StatisticsCalculator.calculateAverage(
                records, aggregationMethod, from, to,
                walletCurrencyMap: walletCurrencyMap));

    final median = isBalance
        ? (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyMedian(records, from, to,
                isBalance: true)
            : StatisticsCalculator.calculateMedian(
                records, aggregationMethod, from, to,
                isBalance: true))
        : (aggregationMethod == AggregationMethod.WEEK
            ? StatisticsCalculator.calculateDailyMedian(records, from, to,
                walletCurrencyMap: walletCurrencyMap)
            : StatisticsCalculator.calculateMedian(
                records, aggregationMethod, from, to,
                walletCurrencyMap: walletCurrencyMap));

    // When colorize is enabled, expenses render in red, income in green and
    // balance values are colored by sign, matching the in-app statistics page.
    final colorize = _colorizeEnabled();
    final PdfColor? Function(double) colorFor = isBalance
        ? _amountColor
        : (value) => colorize ? chartColor : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderRow(
          title: title,
          totalText: formatRecordsTotalResult(totalResult),
          medianText: _formatStatValue(median, currency),
          averageText: _formatStatValue(average, currency),
          totalColor: colorFor(totalResult.total),
          medianColor: colorFor(median),
          averageColor: colorFor(average),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: _buildChart(
                records: records,
                from: from,
                to: to,
                aggregationMethod: aggregationMethod,
                signed: isBalance,
                color: chartColor,
                walletCurrencyMap: walletCurrencyMap,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 3,
              child: _buildCategoryPieChart(records, walletCurrencyMap),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
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

  /// Builds the section header line: title followed by Total, Median and
  /// Average separated by vertical dividers.
  static pw.Widget _buildSectionHeaderRow({
    required String title,
    required String totalText,
    required String medianText,
    required String averageText,
    required PdfColor? totalColor,
    required PdfColor? medianColor,
    required PdfColor? averageColor,
  }) {
    pw.TextStyle statStyle(PdfColor? color) => pw.TextStyle(
          fontSize: 10,
          color: color ?? PdfColors.blueGrey900,
        );
    return pw.Row(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(width: 0.8, height: 14, color: PdfColors.grey400),
        pw.SizedBox(width: 10),
        pw.Text('${'Total'.i18n}: $totalText', style: statStyle(totalColor)),
        pw.SizedBox(width: 8),
        pw.Container(width: 0.8, height: 14, color: PdfColors.grey400),
        pw.SizedBox(width: 8),
        pw.Text('${'Median'.i18n}: $medianText', style: statStyle(medianColor)),
        pw.SizedBox(width: 8),
        pw.Container(width: 0.8, height: 14, color: PdfColors.grey400),
        pw.SizedBox(width: 8),
        pw.Text(
            '${'Average'.i18n}: $averageText', style: statStyle(averageColor)),
      ],
    );
  }

  /// Builds a category pie chart with a legend, mirroring the in-app
  /// statistics page: top categories by absolute value plus an "Others"
  /// bucket, each with a colored slice and its percentage.
  ///
  /// Slices below [_minSlicePercentage] are merged into "Others" so that the
  /// built-in leader-line labels of tiny adjacent slices never overlap.
  static pw.Widget _buildCategoryPieChart(
      List<Record> records, Map<int, String?> walletCurrencyMap) {
    final slices = _computePieSlices(records, walletCurrencyMap);
    if (slices.isEmpty) return pw.SizedBox.shrink();

    final legendStyle = pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey800);
    return pw.Center(
      child: pw.SizedBox(
        width: 280,
        height: 180,
        child: pw.Chart(
          grid: _FixedRadiusPieGrid(fixedRadius: 44),
          datasets: [
            for (final s in slices)
              pw.PieDataSet(
                value: s.percentage,
                color: s.color,
                legend: '${s.label} ${s.percentage.toStringAsFixed(2)} %',
                legendPosition: pw.PieLegendPosition.outside,
                legendStyle: legendStyle,
                legendLineColor: s.color,
                legendLineWidth: 0.6,
                legendOffset: 12,
                borderColor: PdfColors.white,
                borderWidth: 1,
              ),
          ],
        ),
      ),
    );
  }

  /// Minimum slice size (in percentage points) for a category to keep its own
  /// slice. Smaller categories are merged into the "Others" bucket so the
  /// pie legend labels don't overlap for very small adjacent slices.
  static const _minSlicePercentage = 10.0;

  /// Aggregates [records] by category (magnitudes converted to the main
  /// currency for multi-currency records), keeping the top
  /// categories configured by the user plus an "Others" bucket.
  static List<_PieSlice> _computePieSlices(
      List<Record> records, Map<int, String?> walletCurrencyMap) {
    final aggregates = <Category, double>{};
    for (final r in records) {
      if (r.category == null) continue;
      // Pie slices are magnitudes, so abs() is applied here at the
      // representation boundary while the conversion works on real values.
      final value = getRecordValueInDefaultCurrency(r, walletCurrencyMap).abs();
      aggregates.update(r.category!, (v) => v + value, ifAbsent: () => value);
    }
    if (aggregates.isEmpty) return const [];

    final total = aggregates.values.fold(0.0, (a, b) => a + b);
    final sorted = aggregates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final prefs = ServiceConfig.sharedPreferences;
    final maxCategories = prefs == null
        ? 4
        : (PreferencesUtils.getOrDefault<int>(prefs,
                PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay) ??
            4);
    final useCategoryColors = prefs == null
        ? false
        : (PreferencesUtils.getOrDefault<bool>(prefs,
                PreferencesKeys.statisticsPieChartUseCategoryColors) ??
            false);

    final slices = <_PieSlice>[];
    var othersSum = 0.0;
    var kept = 0;
    for (final entry in sorted) {
      final percentage = entry.value / total * 100;
      if (kept >= maxCategories || percentage < _minSlicePercentage) {
        othersSum += entry.value;
        continue;
      }
      final color = useCategoryColors
          ? _pdfColor(entry.key.color)
          : _defaultPiePalette[kept % _defaultPiePalette.length];
      slices.add(_PieSlice(
        entry.key.name ?? '',
        percentage,
        color,
      ));
      kept++;
    }
    if (othersSum > 0) {
      slices.add(_PieSlice(
        'Others'.i18n,
        othersSum / total * 100,
        PdfColors.blueGrey,
      ));
    }
    return slices;
  }

  /// Converts a Flutter [Color] to a [PdfColor], ignoring the alpha channel.
  static PdfColor _pdfColor(Color? color) =>
      PdfColor.fromInt((color ?? const Color(0xFF9E9E9E)).toARGB32() &
          0xFFFFFF);

  static const _defaultPiePalette = <PdfColor>[
    PdfColor.fromInt(0xFF1E88E5),
    PdfColor.fromInt(0xFF43A047),
    PdfColor.fromInt(0xFFFB8C00),
    PdfColor.fromInt(0xFFE53935),
    PdfColor.fromInt(0xFF8E24AA),
    PdfColor.fromInt(0xFF00ACC1),
    PdfColor.fromInt(0xFF6D4C41),
  ];

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
    required Map<int, String?> walletCurrencyMap,
  }) {
    final points = _buildChartPoints(records, from, to, aggregationMethod,
        signed: signed, walletCurrencyMap: walletCurrencyMap);
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

    final barValueLabel = n <= 8
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
            marginStart: barWidth,
            marginEnd: barWidth,
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
    required Map<int, String?> walletCurrencyMap,
  }) {
    final config = ChartDateRangeConfig.create(method, from, to);
    final byKey = <String, double>{};
    for (final r in records) {
      final key = config.getKey(truncateDateTime(r.dateTime, method));
      // Convert multi-currency records to the main currency so the chart sums
      // real values instead of raw numeric values (issue #411). abs() is only
      // applied to the magnitude for the non-signed (expense/income) view.
      final converted = getRecordValueInDefaultCurrency(r, walletCurrencyMap);
      final value = signed ? converted : converted.abs();
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
    for (var v = start; v <= max + step * 1.5; v += step) {
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

    final defaultCurrency = getDefaultCurrency();
    final rows = groups.entries.map((e) {
      final currency = walletCurrencyMap[e.key];
      final original = e.value.fold<double>(
          0.0, (sum, r) => sum + (isAbsValue ? r.value!.abs() : r.value!));
      final converted = computeConvertedTotal(e.value, walletCurrencyMap,
              isAbsValue: isAbsValue)
          .total;
      final needsConversion = currency != null &&
          currency.isNotEmpty &&
          defaultCurrency != null &&
          defaultCurrency.isNotEmpty &&
          currency != defaultCurrency;
      return _WalletRow(
        walletNames[e.key] ?? '—',
        currency,
        original,
        converted,
        needsConversion,
      );
    }).toList()
      ..sort((a, b) => b.converted.abs().compareTo(a.converted.abs()));

    if (rows.isEmpty) return pw.SizedBox.shrink();
    return _buildWalletTable('Wallet'.i18n, rows, colorFor: colorFor);
  }

  /// Builds the wallet split table: wallet name, currency and amount. When a
  /// wallet currency differs from the user's default currency, the converted
  /// amount (in the default currency) is shown above the original amount (in
  /// the wallet currency), mirroring the in-app statistics breakdown.
  static pw.Widget _buildWalletTable(
    String title,
    List<_WalletRow> rows, {
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
            'Currency'.i18n,
            'Amount'.i18n,
          ],
          data: rows
              .map((r) => [
                    r.name,
                    r.currency ?? '—',
                    _walletAmountCell(r, colorFor(r.converted)),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellAlignments: {2: pw.Alignment.centerRight},
          columnWidths: {
            0: pw.FractionColumnWidth(0.42),
            1: pw.FractionColumnWidth(0.13),
            2: pw.FractionColumnWidth(0.45),
          },
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.4,
          ),
        ),
      ],
    );
  }

  /// Builds the amount cell for a wallet row. When a conversion is needed the
  /// converted amount (default currency) is shown on top of the original
  /// amount (wallet currency), matching the in-app statistics page.
  static pw.Widget _walletAmountCell(_WalletRow row, PdfColor? color) {
    final String primary;
    final String? secondary;
    if (row.needsConversion) {
      primary = formatCurrencyAmount(row.converted, getDefaultCurrency()!);
      secondary = formatCurrencyAmount(row.original, row.currency!);
    } else if (row.currency != null && row.currency!.isNotEmpty) {
      primary = formatCurrencyAmount(row.original, row.currency!);
      secondary = null;
    } else {
      primary = getCurrencyValueString(row.original);
      secondary = null;
    }
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            primary,
            style: color == null
                ? pw.TextStyle(fontSize: 10)
                : pw.TextStyle(fontSize: 10, color: color),
          ),
          if (secondary != null)
            pw.Text(
              secondary,
              style: pw.TextStyle(
                fontSize: 8,
                color: _amountColor(row.original) ?? PdfColors.blueGrey,
              ),
            ),
        ],
      ),
    );
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
        _buildRecordAmountCell(r, walletCurrencyMap),
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

  /// Builds the amount cell for a record row. When the record's wallet currency
  /// differs from the default, the converted amount (default currency) is shown
  /// on top of the original amount (wallet currency), mirroring the wallet
  /// split table so long amounts don't overflow the column.
  static pw.Widget _buildRecordAmountCell(
    Record record,
    Map<int, String?> walletCurrencyMap,
  ) {
    final currency = (record.walletId != null ? walletCurrencyMap[record.walletId] : null) ??
        '';
    final value = record.value ?? 0;
    final parts = splitAmountConversion(value, currency);
    if (parts == null) {
      final text = currency.isNotEmpty
          ? formatCurrencyAmount(value, currency)
          : getCurrencyValueString(value);
      return _coloredAmountText(text, _amountColor(value), fontSize: 9);
    }
    final primaryColor = _amountColor(parts.convertedValue);
    final secondaryColor = _amountColor(value);
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            parts.converted,
            style: primaryColor == null
                ? const pw.TextStyle(fontSize: 9)
                : pw.TextStyle(fontSize: 9, color: primaryColor),
          ),
          pw.Text(
            parts.original,
            style: pw.TextStyle(
              fontSize: 8,
              color: secondaryColor ?? PdfColors.blueGrey,
            ),
          ),
        ],
      ),
    );
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

class _WalletRow {
  final String name;
  final String? currency;
  final double original;
  final double converted;
  final bool needsConversion;
  _WalletRow(this.name, this.currency, this.original, this.converted,
      this.needsConversion);
}

class _PieSlice {
  final String label;
  final double percentage;
  final PdfColor color;
  _PieSlice(this.label, this.percentage, this.color);
}

/// A [pw.PieGrid] that always draws slices with the same fixed radius,
/// regardless of how many slices/labels a chart has, so all pie charts in the
/// report render at the same size. The base [pw.PieGrid] shrinks its radius to
/// fit every outside legend label, which makes multi-category pies smaller.
class _FixedRadiusPieGrid extends pw.PieGrid {
  _FixedRadiusPieGrid({required this.fixedRadius});

  final double fixedRadius;

  @override
  double get radius => fixedRadius;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
    final size = box!.size;

    final datasets = pw.Chart.of(context).datasets;
    var total = 0.0;
    for (final dataset in datasets) {
      if (dataset is pw.PieDataSet) {
        total += dataset.value;
      }
    }
    if (total <= 0) return;

    final unit = math.pi * 2 / total;
    var angle = startAngle;
    for (final dataset in datasets) {
      if (dataset is pw.PieDataSet) {
        dataset.angleStart = angle;
        angle += dataset.value * unit;
        dataset.angleEnd = angle;
        dataset.layout(context, pw.BoxConstraints.tight(size));
      }
    }
  }
}