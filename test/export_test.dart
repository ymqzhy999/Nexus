import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/analysis/metrics.dart';
import 'package:nexus/data/table_data.dart';
import 'package:nexus/export/exporters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final table = TableData(
    title: '测试数据集',
    sourceName: 'Nexus Test',
    sourceUrl: 'https://example.com',
    headers: const ['年份', 'GDP', '人口'],
    rows: const [
      ['2020', '100', '10'],
      ['2021', '110', '11'],
      ['2022', '121', '12'],
    ],
  );
  final metrics = StatsEngine.descriptive([100, 110, 121]);

  test('excel bytes are generated', () {
    final bytes = DatasetExporter.excelBytes(table, metrics, '测试解读');
    expect(bytes.length, greaterThan(1000));
  });

  test('csv includes header and rows', () {
    final csv = DatasetExporter.csvString(table);
    expect(csv, contains('年份'));
    expect(csv, contains('2022'));
  });

  test('pdf bytes are generated with Chinese font', () async {
    final bytes = await DatasetExporter.pdfBytes(table, metrics, '测试解读');
    expect(bytes.length, greaterThan(5000));
  });
}
