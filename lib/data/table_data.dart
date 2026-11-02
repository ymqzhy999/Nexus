import 'dart:convert';

import 'database.dart';

class TableData {
  final String title;
  final String sourceUrl;
  final String sourceName;
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, dynamic> meta;

  const TableData({
    required this.title,
    required this.headers,
    required this.rows,
    this.sourceUrl = '',
    this.sourceName = '',
    this.meta = const {},
  });

  int get rowCount => rows.length;
  int get columnCount => headers.length;

  factory TableData.fromRecord(Dataset d) {
    List<String> headers = [];
    List<List<String>> rows = [];
    Map<String, dynamic> meta = {};
    try {
      final h = jsonDecode(d.columnsJson);
      if (h is List) headers = h.map((e) => e.toString()).toList();
    } catch (_) {}
    try {
      final r = jsonDecode(d.rowsJson);
      if (r is List) {
        rows = r
            .whereType<List>()
            .map((row) => row.map((e) => e?.toString() ?? '').toList())
            .toList();
      }
    } catch (_) {}
    try {
      final m = jsonDecode(d.metaJson);
      if (m is Map) meta = Map<String, dynamic>.from(m);
    } catch (_) {}
    return TableData(
      title: d.name,
      sourceUrl: d.sourceUrl,
      sourceName: d.sourceName,
      headers: headers,
      rows: rows,
      meta: meta,
    );
  }

  TableData copyWith({String? title, List<List<String>>? rows}) => TableData(
        title: title ?? this.title,
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        headers: headers,
        rows: rows ?? this.rows,
        meta: meta,
      );

  int? yearColumn() {
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      if (h.contains('年份') || h.contains('年度') || h.contains('year') || h == '年' || h.contains('date') || h.contains('时间')) {
        return i;
      }
    }
    for (var i = 0; i < headers.length; i++) {
      var hits = 0;
      var total = 0;
      for (final r in rows) {
        if (i >= r.length) continue;
        total++;
        if (yearOf(r[i]) != null) hits++;
      }
      if (total > 0 && hits / total > 0.6) return i;
    }
    return null;
  }

  bool isYearLikeColumn(int i) {
    if (i < 0 || i >= headers.length) return false;
    final h = headers[i].toLowerCase().trim();
    if (h.contains('年份') || h.contains('年度') || h.contains('year') || h == '年' || h.contains('date') || h.contains('时间')) {
      return true;
    }
    var hits = 0;
    var total = 0;
    for (final r in rows) {
      if (i >= r.length) continue;
      final text = r[i].trim();
      if (text.isEmpty) continue;
      total++;
      if (yearOf(text) != null) hits++;
    }
    return total >= 2 && hits / total >= 0.7;
  }

  List<int> numericColumns() {
    final out = <int>[];
    for (var i = 0; i < headers.length; i++) {
      if (isYearLikeColumn(i)) continue;
      var hits = 0;
      var total = 0;
      for (final r in rows) {
        if (i >= r.length) continue;
        final text = r[i].trim();
        if (text.isEmpty) continue;
        total++;
        if (parseNumeric(text) != null) hits++;
      }
      if (total >= 2 && hits / total >= 0.6) out.add(i);
    }
    return out;
  }

  int get measureColumnCount => numericColumns().length;

  bool get looksLikeIndex => rows.length < 3 || measureColumnCount == 0;

  List<double?> numericSeries(int column, {int? yearColumnIndex, int? startYear, int? endYear}) {
    final years = yearColumnIndex ?? yearColumn();
    final out = <double?>[];
    for (final r in rows) {
      if (column >= r.length) {
        out.add(null);
        continue;
      }
      if (years != null && startYear != null && endYear != null) {
        final y = years < r.length ? yearOf(r[years]) : null;
        if (y == null || y < startYear || y > endYear) continue;
      }
      out.add(parseNumeric(r[column]));
    }
    return out;
  }

  List<({int year, double value})> yearValuePairs(int valueColumn, int yearCol) {
    final out = <({int year, double value})>[];
    for (final r in rows) {
      if (valueColumn >= r.length || yearCol >= r.length) continue;
      final y = yearOf(r[yearCol]);
      final v = parseNumeric(r[valueColumn]);
      if (y != null && v != null) out.add((year: y, value: v));
    }
    out.sort((a, b) => a.year.compareTo(b.year));
    return out;
  }

  List<int> years() {
    final yc = yearColumn();
    if (yc == null) return const [];
    final set = <int>{};
    for (final r in rows) {
      if (yc < r.length) {
        final y = yearOf(r[yc]);
        if (y != null) set.add(y);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}

int? yearOf(String raw) {
  final m = RegExp(r'(?:19|20)\d{2}').firstMatch(raw);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

double? parseNumeric(String raw) {
  var s = raw
      .trim()
      .replaceAll('−', '-')
      .replaceAll('－', '-')
      .replaceAll('，', '')
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('\u00a0', '');
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (['-', '—', '–', 'na', 'n/a', 'null', '...', '…', '不适用'].contains(lower)) return null;
  final negative = s.startsWith('(') && s.endsWith(')');
  s = s.replaceAll(RegExp(r'[^0-9eE+\-\.]'), '');
  if (s.isEmpty || s == '-' || s == '+' || s == '.') return null;
  final v = double.tryParse(s);
  if (v == null) return null;
  return negative ? -v : v;
}

String formatNumber(double v, {int digits = 2}) {
  if (v.isNaN || v.isInfinite) return '—';
  final abs = v.abs();
  if (abs >= 100000000) return '${(v / 100000000).toStringAsFixed(digits)} 亿';
  if (abs >= 10000) return '${(v / 10000).toStringAsFixed(digits)} 万';
  if (abs > 0 && abs < 0.01) return v.toStringAsExponential(2);
  return v.toStringAsFixed(digits);
}

String formatPercent(double v, {int digits = 2}) {
  if (v.isNaN || v.isInfinite) return '—';
  return '${(v * 100).toStringAsFixed(digits)}%';
}
