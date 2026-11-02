import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../analysis/metrics.dart';
import '../data/table_data.dart';

class DatasetExporter {
  static String _safe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  static Future<File> _file(String name, String ext) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/${_safe(name)}_${DateTime.now().millisecondsSinceEpoch}.$ext');
  }

  static Future<File> excel(TableData table, List<MetricResult> metrics, String aiText) async {
    final excel = Excel.createExcel();
    final data = excel['数据'];
    data.appendRow([TextCellValue('数据集'), TextCellValue(table.title)]);
    data.appendRow([TextCellValue('来源'), TextCellValue(table.sourceName)]);
    data.appendRow([TextCellValue('URL'), TextCellValue(table.sourceUrl)]);
    data.appendRow([TextCellValue('行数'), TextCellValue('${table.rows.length}')]);
    data.appendRow([TextCellValue('')]);
    data.appendRow(table.headers.map((h) => TextCellValue(h)).toList());
    for (final row in table.rows) {
      data.appendRow(row.map((c) => TextCellValue(c)).toList());
    }
    final m = excel['指标'];
    m.appendRow([TextCellValue('指标'), TextCellValue('数值'), TextCellValue('公式'), TextCellValue('说明')]);
    for (final r in metrics) {
      m.appendRow([TextCellValue(r.name), TextCellValue(r.value), TextCellValue(r.formula), TextCellValue(r.description)]);
    }
    if (aiText.trim().isNotEmpty) {
      final ai = excel['AI解读'];
      ai.appendRow([TextCellValue('AI 解读（仅基于本地计算结果）')]);
      ai.appendRow([TextCellValue(aiText)]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel 生成失败');
    final f = await _file(table.title, 'xlsx');
    await f.writeAsBytes(bytes);
    return f;
  }

  static Future<File> csv(TableData table) async {
    final buf = StringBuffer('\ufeff');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    buf.writeln(table.headers.map(q).join(','));
    for (final row in table.rows) {
      buf.writeln(row.map(q).join(','));
    }
    final f = await _file(table.title, 'csv');
    await f.writeAsString(buf.toString(), encoding: utf8);
    return f;
  }

  static Future<File> pdf(TableData table, List<MetricResult> metrics, String aiText) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: font);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text(table.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('来源：${table.sourceName}  ${table.sourceUrl}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text('行数：${table.rows.length}  列数：${table.headers.length}  生成时间：${DateTime.now()}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (metrics.isNotEmpty) ...[
          pw.Text('分析指标', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['指标', '数值', '公式'],
            data: metrics.map((e) => [e.name, e.value, e.formula]).toList(),
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(4),
            },
          ),
          pw.SizedBox(height: 10),
        ],
        if (aiText.trim().isNotEmpty) ...[
          pw.Text('AI 解读（仅基于本地计算结果）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(aiText, style: const pw.TextStyle(fontSize: 9, lineSpacing: 3)),
          pw.SizedBox(height: 10),
        ],
        pw.Text('数据预览（前 40 行）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: table.headers,
          data: table.rows.take(40).map((r) => r.take(12).toList()).toList(),
          headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 6),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
      ],
    ));
    final bytes = await doc.save();
    final f = await _file(table.title, 'pdf');
    await f.writeAsBytes(bytes);
    return f;
  }

  static Future<void> share(File file, {String text = ''}) async {
    await Share.shareXFiles([XFile(file.path, mimeType: _mime(file.path))], text: text);
  }

  static String _mime(String path) {
    if (path.endsWith('.pdf')) return 'application/pdf';
    if (path.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (path.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }
}
