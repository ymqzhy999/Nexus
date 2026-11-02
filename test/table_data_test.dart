import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/table_data.dart';

void main() {
  test('wide year table becomes long format', () {
    final t = TableData(
      title: 'wide',
      headers: const ['指标', '2020', '2021', '2022'],
      rows: const [
        ['GDP', '100', '110', '121'],
        ['人口', '10', '11', '12'],
      ],
    );
    expect(t.isWideYearTable, isTrue);
    final long = t.toLongFormat();
    expect(long.headers, ['指标', '年份', '数值']);
    expect(long.rows.length, 6);
    expect(long.rows.first, ['GDP', '2020', '100']);
  });

  test('year index table is not mistaken for data', () {
    final t = TableData(
      title: 'index',
      headers: const ['列1', '列2'],
      rows: const [
        ['2025年', '2024年'],
        ['2023年', '2022年'],
        ['2021年', '2020年'],
      ],
    );
    expect(t.looksLikeIndex, isTrue);
    expect(t.measureColumnCount, 0);
  });

  test('normal long table detects year and measure', () {
    final t = TableData(
      title: 'long',
      headers: const ['年份', 'GDP'],
      rows: const [
        ['2020', '100'],
        ['2021', '110'],
        ['2022', '121'],
      ],
    );
    expect(t.yearColumn(), 0);
    expect(t.numericColumns(), [1]);
    expect(t.looksLikeIndex, isFalse);
  });
}
