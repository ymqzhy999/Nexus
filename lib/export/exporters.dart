import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../analysis/metrics.dart';
import '../data/table_data.dart';

class DatasetExporter {
  static String _safe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

  static Uint8List excelBytes(TableData table, List<MetricResult> metrics, String aiText) {
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
    if (bytes == null) throw Exception('Excel 生成失败（encode 返回空）');
    return Uint8List.fromList(bytes);
  }

  static String csvString(TableData table) {
    final buf = StringBuffer('\ufeff');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    buf.writeln(table.headers.map(q).join(','));
    for (final row in table.rows) {
      buf.writeln(row.map(q).join(','));
    }
    return buf.toString();
  }

  static Uint8List csvBytes(TableData table) => Uint8List.fromList(utf8.encode(csvString(table)));

  static Future<Uint8List> pdfBytes(TableData table, List<MetricResult> metrics, String aiText) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: font);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(26),
      build: (context) => [
        pw.Text(table.title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('来源：${table.sourceName}  ${table.sourceUrl}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text('行数：${table.rows.length}  列数：${table.headers.length}  生成时间：${DateTime.now()}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        if (metrics.isNotEmpty) ...[
          pw.Text('分析指标', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: const ['指标', '数值', '公式'],
            data: metrics.map((e) => [e.name, e.value, e.formula]).toList(),
            headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(4.2),
            },
          ),
          pw.SizedBox(height: 9),
        ],
        if (aiText.trim().isNotEmpty) ...[
          pw.Text('AI 解读（仅基于本地计算结果）', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(aiText, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 3)),
          pw.SizedBox(height: 9),
        ],
        pw.Text('数据预览（前 40 行）', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: table.headers,
          data: table.rows.take(40).map((r) => r.take(12).toList()).toList(),
          headerStyle: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 5.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
      ],
    ));
    return doc.save();
  }

  static Future<String> saveExcel(TableData table, List<MetricResult> metrics, String aiText) async {
    final bytes = excelBytes(table, metrics, aiText);
    return FileSaver.instance.saveFile(
      name: 'Nexus_${_safe(table.title)}_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<String> saveCsv(TableData table) async {
    final bytes = csvBytes(table);
    return FileSaver.instance.saveFile(
      name: 'Nexus_${_safe(table.title)}_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static Future<String> savePdf(TableData table, List<MetricResult> metrics, String aiText) async {
    final bytes = await pdfBytes(table, metrics, aiText);
    return FileSaver.instance.saveFile(
      name: 'Nexus_${_safe(table.title)}_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
