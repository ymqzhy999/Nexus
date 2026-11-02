import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../core/utils.dart';
import 'table_data.dart';

class ParsedTables {
  final String kind;
  final List<TableData> tables;
  final String? error;

  const ParsedTables({required this.kind, required this.tables, this.error});
}

class TableParser {
  static ParsedTables parseBytes({
    required Uint8List bytes,
    required String url,
    required String sourceName,
    String contentType = '',
  }) {
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      try {
        return ParsedTables(kind: 'xlsx', tables: parseXlsx(bytes, url: url, sourceName: sourceName));
      } catch (e) {
        return ParsedTables(kind: 'xlsx', tables: const [], error: 'Excel 解析失败：$e');
      }
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    return parseText(text: text, url: url, sourceName: sourceName, contentType: contentType);
  }

  static ParsedTables parseText({
    required String text,
    required String url,
    required String sourceName,
    String contentType = '',
  }) {
    final trimmed = text.replaceFirst('\ufeff', '').trimLeft();
    final ct = contentType.toLowerCase();
    if (trimmed.startsWith('{') || trimmed.startsWith('[') || ct.contains('json')) {
      try {
        return ParsedTables(kind: 'json', tables: parseJson(trimmed, url: url, sourceName: sourceName));
      } catch (e) {
        return ParsedTables(kind: 'json', tables: const [], error: 'JSON 解析失败：$e');
      }
    }
    if (trimmed.toLowerCase().contains('<table') || ct.contains('html') || trimmed.startsWith('<')) {
      final tables = parseHtmlTables(trimmed, url: url, sourceName: sourceName);
      return ParsedTables(
        kind: 'html',
        tables: tables,
        error: tables.isEmpty ? '页面里没有找到可用的表格' : null,
      );
    }
    try {
      return ParsedTables(kind: 'csv', tables: [parseCsv(trimmed, url: url, sourceName: sourceName)]);
    } catch (e) {
      return ParsedTables(kind: 'csv', tables: const [], error: 'CSV 解析失败：$e');
    }
  }

  static TableData parseCsv(String text, {required String url, required String sourceName}) {
    final raw = CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
    final rows = raw
        .map((r) => r.map((e) => e.toString().replaceAll('\r', '').trim()).toList())
        .where((r) => r.any((c) => c.isNotEmpty))
        .toList();
    if (rows.isEmpty) throw const FormatException('CSV 为空');
    var headerIndex = 0;
    if (rows.length > 1 && rows[0].where((e) => e.isNotEmpty).length <= 1 && rows[1].length > rows[0].length) {
      headerIndex = 1;
    }
    final headers = _dedupeHeaders(rows[headerIndex]);
    final data = rows.skip(headerIndex + 1).map((r) => _normalizeRow(r, headers.length)).toList();
    return TableData(
      title: _titleFromUrl(url),
      sourceUrl: url,
      sourceName: sourceName,
      headers: headers,
      rows: data,
      meta: {'kind': 'csv'},
    );
  }

  static List<TableData> parseJson(String text, {required String url, required String sourceName}) {
    final data = jsonDecode(text);
    // World Bank v2: [metadata, [ {date, value, indicator, country}, ... ]]
    if (data is List &&
        data.length >= 2 &&
        data[1] is List &&
        (data[1] as List).isNotEmpty &&
        (data[1] as List).first is Map &&
        ((data[1] as List).first as Map).containsKey('date') &&
        ((data[1] as List).first as Map).containsKey('value')) {
      final meta = data[0] is Map ? Map<String, dynamic>.from(data[0] as Map) : <String, dynamic>{};
      final rows = <List<String>>[];
      for (final e in (data[1] as List).whereType<Map>()) {
        final m = Map<String, dynamic>.from(e);
        final year = (m['date'] ?? '').toString();
        final value = m['value'];
        final country = m['country'] is Map ? (m['country']['value'] ?? '') : '';
        final indicator = m['indicator'] is Map ? (m['indicator']['value'] ?? '') : '';
        if (year.isEmpty) continue;
        rows.add([year, country.toString(), indicator.toString(), value == null ? '' : value.toString()]);
      }
      if (rows.isNotEmpty) {
        rows.sort((a, b) => (int.tryParse(a[0]) ?? 0).compareTo(int.tryParse(b[0]) ?? 0));
        return [
          TableData(
            title: (meta['indicator'] is Map ? meta['indicator']['value'] : null)?.toString() ??
                'World Bank 数据',
            sourceUrl: url,
            sourceName: sourceName,
            headers: const ['年份', '国家', '指标', '数值'],
            rows: rows,
            meta: {'kind': 'worldbank', 'raw': meta},
          ),
        ];
      }
    }

    final list = _findList(data);
    if (list == null || list.isEmpty) throw const FormatException('JSON 中没有找到表格数据');
    final maps = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (maps.isEmpty) throw const FormatException('JSON 列表不是对象数组');
    final headers = <String>[];
    for (final m in maps) {
      for (final k in m.keys) {
        if (!headers.contains(k)) headers.add(k);
      }
    }
    final rows = maps
        .map((m) => headers.map((h) => _stringify(m[h])).toList())
        .toList();
    return [
      TableData(
        title: _titleFromUrl(url),
        sourceUrl: url,
        sourceName: sourceName,
        headers: _dedupeHeaders(headers),
        rows: rows,
        meta: {'kind': 'json'},
      ),
    ];
  }

  static List<TableData> parseHtmlTables(String html, {required String url, required String sourceName}) {
    final doc = html_parser.parse(html);
    final pageTitle = doc.querySelector('title')?.text.trim() ?? '';
    final out = <TableData>[];
    final tables = doc.querySelectorAll('table');
    var index = 0;
    for (final table in tables) {
      if (out.length >= 20) break;
      final rawRows = <List<String>>[];
      final trs = table.querySelectorAll('tr');
      for (final tr in trs) {
        final cells = <String>[];
        for (final cell in tr.querySelectorAll('th,td')) {
          final span = (int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1).clamp(1, 20);
          final text = cell.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          for (var k = 0; k < span; k++) {
            cells.add(k == 0 ? text : '');
          }
        }
        if (cells.isNotEmpty) rawRows.add(cells);
      }
      if (rawRows.length < 2) continue;
      final maxCols = rawRows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      if (maxCols < 2) continue;
      final normalized = rawRows.map((r) => _normalizeRow(r, maxCols)).toList();
      final first = normalized.first;
      final numericFirst = first.where((c) => parseNumeric(c) != null).length;
      final headers = numericFirst > first.length / 2
          ? List.generate(maxCols, (i) => '列${i + 1}')
          : _dedupeHeaders(first);
      final data = numericFirst > first.length / 2 ? normalized : normalized.skip(1).toList();
      final caption = table.querySelector('caption')?.text.trim();
      final title = (caption != null && caption.isNotEmpty)
          ? caption
          : '${pageTitle.isEmpty ? sourceName : pageTitle} · 表${index + 1}';
      out.add(TableData(
        title: truncate(title, 80),
        sourceUrl: url,
        sourceName: sourceName,
        headers: headers,
        rows: data.where((r) => r.any((c) => c.isNotEmpty)).toList(),
        meta: {'kind': 'html_table', 'table_index': index},
      ));
      index++;
    }
    return out;
  }

  static List<TableData> parseXlsx(Uint8List bytes, {required String url, required String sourceName}) {
    final excel = Excel.decodeBytes(bytes);
    final out = <TableData>[];
    var sheetIndex = 0;
    for (final name in excel.tables.keys) {
      if (out.length >= 6) break;
      final sheet = excel.tables[name];
      if (sheet == null) continue;
      final rows = <List<String>>[];
      for (final row in sheet.rows) {
        final cells = row.map(_cellText).toList();
        if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
      }
      if (rows.length < 2) continue;
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      if (maxCols < 2) continue;
      final normalized = rows.map((r) => _normalizeRow(r, maxCols)).toList();
      var headerIndex = 0;
      for (var i = 0; i < normalized.length - 1 && i < 5; i++) {
        final nonEmpty = normalized[i].where((c) => c.isNotEmpty).length;
        if (nonEmpty >= 2) {
          headerIndex = i;
          break;
        }
      }
      final headers = _dedupeHeaders(normalized[headerIndex]);
      final data = normalized.skip(headerIndex + 1).toList();
      out.add(TableData(
        title: '$name · ${sheetIndex + 1}',
        sourceUrl: url,
        sourceName: sourceName,
        headers: headers,
        rows: data,
        meta: {'kind': 'xlsx', 'sheet': name},
      ));
      sheetIndex++;
    }
    if (out.isEmpty) throw const FormatException('Excel 中没有可用表格');
    return out;
  }

  static String _cellText(Data? d) {
    final v = d?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    return v.toString();
  }

  static List<dynamic>? _findList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['data', 'items', 'rows', 'results', 'records', 'list', 'hits']) {
        final v = data[key];
        if (v is List) return v;
        if (v is Map) {
          final nested = _findList(v);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  static String _stringify(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      final x = v['value'] ?? v['name'] ?? v['label'];
      return x?.toString() ?? jsonEncode(v);
    }
    if (v is List) return v.map(_stringify).join('; ');
    return v.toString();
  }

  static String _titleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segs = uri?.pathSegments.where((e) => e.isNotEmpty).toList() ?? [];
    final last = segs.isEmpty ? uri?.host ?? '数据集' : segs.last;
    return last.length > 60 ? last.substring(0, 60) : last;
  }

  static List<String> _dedupeHeaders(List<String> raw) {
    final seen = <String, int>{};
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      var h = raw[i].trim();
      if (h.isEmpty) h = '列${i + 1}';
      final n = seen[h] ?? 0;
      seen[h] = n + 1;
      out.add(n == 0 ? h : '$h ($n)');
    }
    return out;
  }

  static List<String> _normalizeRow(List<String> row, int cols) {
    final out = List<String>.filled(cols, '');
    for (var i = 0; i < cols && i < row.length; i++) {
      out[i] = row[i];
    }
    return out;
  }
}
