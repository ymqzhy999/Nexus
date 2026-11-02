import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/analysis/metrics.dart';

void main() {
  group('descriptive', () {
    test('mean / sample variance / std', () {
      final m = StatsEngine.descriptive([1, 2, 3, 4]);
      final map = {for (final e in m) e.key: e};
      expect(map['mean']!.raw, isEmpty);
      expect(map['mean']!.value, '2.50');
      expect(map['variance']!.value, '1.67');
      expect(map['std']!.value, '1.29');
    });
  });

  group('trend', () {
    test('cagr uses year span', () {
      final m = StatsEngine.trend([
        (year: 2000, value: 100.0),
        (year: 2001, value: 110.0),
        (year: 2002, value: 121.0),
      ]);
      final map = {for (final e in m) e.key: e};
      expect(map['cagr']!.value, '10.00%');
    });
  });

  group('relation', () {
    test('pearson perfect positive', () {
      final r = StatsEngine.pearson([1, 2, 3, 4], [2, 4, 6, 8]);
      expect(r, closeTo(1.0, 1e-9));
    });

    test('simple ols slope', () {
      final ols = StatsEngine.simpleOls([1, 2, 3, 4], [5, 7, 9, 11]);
      expect(ols, isNotNull);
      expect(ols!.slope, closeTo(2.0, 1e-9));
      expect(ols.intercept, closeTo(3.0, 1e-9));
      expect(ols.r2, closeTo(1.0, 1e-9));
    });
  });

  group('digital economy', () {
    test('hhi 50/50', () {
      final m = StatsEngine.hhi([50, 50]);
      expect(m.first.value, '5000.0');
    });

    test('gini equal values is zero', () {
      final m = StatsEngine.gini([1, 1, 1, 1]);
      expect(double.parse(m.first.value), closeTo(0, 1e-9));
    });

    test('solow tfp with zero growth', () {
      final m = StatsEngine.solowTfp(
        output: [100.0, 100.0, 100.0, 100.0],
        capital: [50.0, 50.0, 50.0, 50.0],
        labor: [50.0, 50.0, 50.0, 50.0],
      );
      expect(m.first.value, '0.00%');
    });
  });
}
