import 'dart:math' as math;

import '../data/table_data.dart';

enum MetricGroup { descriptive, trend, relation, digital }

extension MetricGroupX on MetricGroup {
  String get label => switch (this) {
        MetricGroup.descriptive => '描述统计',
        MetricGroup.trend => '时间趋势',
        MetricGroup.relation => '变量关系',
        MetricGroup.digital => '数字经济理论',
      };
}

class MetricSpec {
  final String key;
  final String name;
  final MetricGroup group;
  final String formula;
  final String description;
  final String assumption;
  final String unit;

  const MetricSpec({
    required this.key,
    required this.name,
    required this.group,
    required this.formula,
    required this.description,
    required this.assumption,
    this.unit = '',
  });
}

const List<MetricSpec> metricSpecs = [
  MetricSpec(key: 'count', name: '样本量 n', group: MetricGroup.descriptive, formula: 'n = 观测值个数', description: '参与计算的有效观测数；缺失值不纳入。', assumption: '仅统计可解析为数值的单元格。', unit: '个'),
  MetricSpec(key: 'mean', name: '均值', group: MetricGroup.descriptive, formula: 'x̄ = (Σxᵢ) / n', description: '样本算术平均值，反映集中趋势。', assumption: '连续型数值；对极端值敏感。'),
  MetricSpec(key: 'median', name: '中位数', group: MetricGroup.descriptive, formula: '排序后第 (n+1)/2 个值', description: '对极端值稳健的集中趋势度量。', assumption: '至少 1 个有效值。'),
  MetricSpec(key: 'variance', name: '样本方差', group: MetricGroup.descriptive, formula: 's² = Σ(xᵢ - x̄)² / (n - 1)', description: '样本离散程度；使用 n-1 的无偏估计。', assumption: 'n ≥ 2；连续型数值。'),
  MetricSpec(key: 'std', name: '样本标准差', group: MetricGroup.descriptive, formula: 's = √[Σ(xᵢ - x̄)² / (n - 1)]', description: '与原始数据同单位的离散程度。', assumption: 'n ≥ 2。'),
  MetricSpec(key: 'cv', name: '变异系数', group: MetricGroup.descriptive, formula: 'CV = s / x̄', description: '标准差相对均值的大小，便于跨量纲比较。', assumption: 'x̄ ≠ 0；均值接近 0 时不稳定。'),
  MetricSpec(key: 'min', name: '最小值', group: MetricGroup.descriptive, formula: 'min(xᵢ)', description: '样本下界。', assumption: '至少 1 个有效值。'),
  MetricSpec(key: 'max', name: '最大值', group: MetricGroup.descriptive, formula: 'max(xᵢ)', description: '样本上界。', assumption: '至少 1 个有效值。'),
  MetricSpec(key: 'range', name: '极差', group: MetricGroup.descriptive, formula: 'R = max(xᵢ) - min(xᵢ)', description: '全距，受极端值影响大。', assumption: '至少 1 个有效值。'),
  MetricSpec(key: 'sum', name: '合计', group: MetricGroup.descriptive, formula: 'Σxᵢ', description: '样本总和。', assumption: '至少 1 个有效值。'),
  MetricSpec(key: 'q1', name: '第一四分位数', group: MetricGroup.descriptive, formula: 'Q1：排序后 25% 分位（线性插值）', description: '低于该值的观测约占 25%。', assumption: 'n ≥ 2。'),
  MetricSpec(key: 'q3', name: '第三四分位数', group: MetricGroup.descriptive, formula: 'Q3：排序后 75% 分位（线性插值）', description: '高于该值的观测约占 25%。', assumption: 'n ≥ 2。'),
  MetricSpec(key: 'skewness', name: '偏度', group: MetricGroup.descriptive, formula: 'g₁ = n/[(n-1)(n-2)] · Σ[(xᵢ-x̄)/s]³', description: '分布不对称程度；0 附近近似对称。', assumption: 'n ≥ 3；s > 0。'),
  MetricSpec(key: 'kurtosis', name: '超额峰度', group: MetricGroup.descriptive, formula: 'g₂ = n(n+1)/[(n-1)(n-2)(n-3)] · Σ[(xᵢ-x̄)/s]⁴ - 3(n-1)²/[(n-2)(n-3)]', description: '尾部厚度；正态分布约为 0。', assumption: 'n ≥ 4；s > 0。'),
  MetricSpec(key: 'growth', name: '累计变化率', group: MetricGroup.trend, formula: '(V_t - V_0) / V_0', description: '首末两期之间的总变化。', assumption: 'V_0 ≠ 0；按年份列排序。'),
  MetricSpec(key: 'cagr', name: '年均复合增长率', group: MetricGroup.trend, formula: 'CAGR = (V_t / V_0)^(1/(t-0)) - 1', description: '按实际年份间隔计算的平均年增长率，不是简单平均。', assumption: 'V_0 > 0、V_t > 0；年份间隔 > 0。'),
  MetricSpec(key: 'yoy', name: '最近一期同比', group: MetricGroup.trend, formula: '(V_t - V_{t-1}) / V_{t-1}', description: '相邻年份的增长率。', assumption: '存在相邻年份且 V_{t-1} ≠ 0。'),
  MetricSpec(key: 'slope', name: '线性趋势斜率', group: MetricGroup.trend, formula: 'OLS：y = a + b·year，b 为斜率', description: '每年平均变化量，单位与 y 相同。', assumption: 'n ≥ 3；线性关系假设。'),
  MetricSpec(key: 'trend_r2', name: '趋势拟合 R²', group: MetricGroup.trend, formula: 'R² = 1 - SSE/SST', description: '线性趋势解释的变异比例，0-1。', assumption: 'n ≥ 3；仅描述拟合优度，不代表因果。'),
  MetricSpec(key: 'doubling', name: '倍增时间', group: MetricGroup.trend, formula: 'T_d = ln(2) / b，其中 ln(y) = a + b·year', description: '指数增长下数值翻倍所需年数，可用于摩尔定律式检验。', assumption: 'y > 0；增长近似指数；b > 0。', unit: '年'),
  MetricSpec(key: 'pearson', name: 'Pearson 相关系数', group: MetricGroup.relation, formula: 'r = Σ(xᵢ-x̄)(yᵢ-ȳ) / √[Σ(xᵢ-x̄)²·Σ(yᵢ-ȳ)²]', description: '线性相关强度，-1 到 1；不代表因果。', assumption: 'n ≥ 3；两变量近似连续、方差 > 0。'),
  MetricSpec(key: 'covariance', name: '样本协方差', group: MetricGroup.relation, formula: 'Cov(x,y) = Σ(xᵢ-x̄)(yᵢ-ȳ) / (n - 1)', description: '两变量共同变动方向与程度。', assumption: 'n ≥ 2；受量纲影响。'),
  MetricSpec(key: 'ols', name: 'OLS 线性回归', group: MetricGroup.relation, formula: 'β = (XᵀX)⁻¹Xᵀy；R² = 1 - SSE/SST', description: '最小二乘估计；输出系数、标准误、t 值与 R²。', assumption: '线性设定、误差同方差/独立等经典假设；相关不等于因果。'),
  MetricSpec(key: 'elasticity', name: '弹性（log-log）', group: MetricGroup.relation, formula: 'ln(y) = a + b·ln(x)，b 为弹性', description: 'x 变动 1% 时 y 近似变动 b%。', assumption: 'x > 0、y > 0；弹性近似常数。'),
  MetricSpec(key: 'digital_share', name: '数字经济占比', group: MetricGroup.digital, formula: '占比 = 数字经济增加值 / GDP × 100%', description: '衡量数字部门相对经济总量的大小。', assumption: '两列同一口径、同一时期；分子分母均为正。'),
  MetricSpec(key: 'moore', name: '摩尔定律检验', group: MetricGroup.digital, formula: 'ln(V_t) = a + b·t；倍增时间 = ln2 / b', description: '检验算力/性能是否呈指数增长，并给出倍增时间。', assumption: '数值为正、年份连续；指数增长是近似。'),
  MetricSpec(key: 'metcalfe', name: '梅特卡夫定律检验', group: MetricGroup.digital, formula: 'V = a + b·n²；报告 b 与 R²', description: '检验网络价值是否随节点数平方增长。', assumption: 'n 为网络规模、V 为价值/收入；线性拟合仅近似。'),
  MetricSpec(key: 'solow_tfp', name: '索洛增长核算（TFP）', group: MetricGroup.digital, formula: 'g_TFP = g_Y - α·g_K - (1-α)·g_L', description: '扣除资本与劳动贡献后的全要素生产率增长，α 默认 0.3。', assumption: '规模报酬不变、竞争市场；增长率口径一致。'),
  MetricSpec(key: 'cobb_douglas', name: 'Cobb-Douglas 生产函数', group: MetricGroup.digital, formula: 'ln Y = ln A + α·ln K + β·ln L；规模报酬 = α+β', description: '估计资本与劳动产出弹性；用于判断规模报酬。', assumption: 'Y、K、L 为正；对数线性设定；技术项近似不变。'),
  MetricSpec(key: 'hhi', name: 'HHI 市场集中度', group: MetricGroup.digital, formula: 'HHI = Σ sᵢ²，sᵢ 为份额（0-1）', description: '市场集中度；通常乘以 10000 报点。', assumption: '份额非负且合计约为 1；不含未观测主体。'),
  MetricSpec(key: 'gini', name: '基尼系数', group: MetricGroup.digital, formula: 'G = (2Σ i·xᵢ)/(n·Σxᵢ) - (n+1)/n', description: '0 完全平等、1 完全不平等；用于数字鸿沟/收入差距。', assumption: 'x 为非负分组值（收入/用户数等），按升序。'),
];

MetricSpec? specOf(String key) {
  for (final s in metricSpecs) {
    if (s.key == key) return s;
  }
  return null;
}

class MetricResult {
  final String key;
  final String name;
  final MetricGroup group;
  final String value;
  final String unit;
  final String formula;
  final String description;
  final String assumption;
  final Map<String, dynamic> raw;

  const MetricResult({
    required this.key,
    required this.name,
    required this.group,
    required this.value,
    required this.unit,
    required this.formula,
    required this.description,
    required this.assumption,
    this.raw = const {},
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'group': group.name,
        'value': value,
        'unit': unit,
        'formula': formula,
        'description': description,
        'assumption': assumption,
        'raw': raw,
      };

  factory MetricResult.fromJson(Map<String, dynamic> j) => MetricResult(
        key: (j['key'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        group: MetricGroup.values.firstWhere((g) => g.name == j['group'], orElse: () => MetricGroup.descriptive),
        value: (j['value'] ?? '').toString(),
        unit: (j['unit'] ?? '').toString(),
        formula: (j['formula'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        assumption: (j['assumption'] ?? '').toString(),
        raw: j['raw'] is Map ? Map<String, dynamic>.from(j['raw'] as Map) : const {},
      );
}

class OlsResult {
  final List<String> labels;
  final List<double> coefficients;
  final List<double> standardErrors;
  final List<double> tValues;
  final double r2;
  final double adjustedR2;
  final int n;

  const OlsResult({
    required this.labels,
    required this.coefficients,
    required this.standardErrors,
    required this.tValues,
    required this.r2,
    required this.adjustedR2,
    required this.n,
  });
}

class StatsEngine {
  static MetricResult _result(String key, String value, {Map<String, dynamic> raw = const {}, String unit = ''}) {
    final spec = specOf(key)!;
    return MetricResult(
      key: key,
      name: spec.name,
      group: spec.group,
      value: value,
      unit: unit.isEmpty ? spec.unit : unit,
      formula: spec.formula,
      description: spec.description,
      assumption: spec.assumption,
      raw: raw,
    );
  }

  static List<MetricResult> descriptive(List<double> input, {String label = ''}) {
    final v = input.where((e) => !e.isNaN && !e.isInfinite).toList()..sort();
    final n = v.length;
    if (n == 0) return const [];
    final mean = v.reduce((a, b) => a + b) / n;
    final sum = v.reduce((a, b) => a + b);
    final out = <MetricResult>[
      _result('count', '$n'),
      _result('sum', formatNumber(sum)),
      _result('mean', formatNumber(mean)),
      _result('median', formatNumber(_quantile(v, 0.5))),
    ];
    if (n >= 2) {
      final varSample = v.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / (n - 1);
      final sd = math.sqrt(varSample);
      out.addAll([
        _result('variance', formatNumber(varSample)),
        _result('std', formatNumber(sd)),
        _result('cv', mean == 0 ? '—' : formatPercent(sd / mean.abs())),
        _result('min', formatNumber(v.first)),
        _result('max', formatNumber(v.last)),
        _result('range', formatNumber(v.last - v.first)),
        _result('q1', formatNumber(_quantile(v, 0.25))),
        _result('q3', formatNumber(_quantile(v, 0.75))),
      ]);
      if (n >= 3 && sd > 0) {
        final skew = v.map((x) => math.pow((x - mean) / sd, 3)).reduce((a, b) => a + b) * n / ((n - 1) * (n - 2));
        out.add(_result('skewness', formatNumber(skew.toDouble())));
      }
      if (n >= 4 && sd > 0) {
        final m4 = v.map((x) => math.pow((x - mean) / sd, 4)).reduce((a, b) => a + b);
        final kurt = m4 * n * (n + 1) / ((n - 1) * (n - 2) * (n - 3)) - 3 * math.pow(n - 1, 2) / ((n - 2) * (n - 3));
        out.add(_result('kurtosis', formatNumber(kurt.toDouble())));
      }
    }
    return out;
  }

  static List<MetricResult> trend(List<({int year, double value})> points, {String label = ''}) {
    final v = points.where((p) => !p.value.isNaN && !p.value.isInfinite).toList()
      ..sort((a, b) => a.year.compareTo(b.year));
    if (v.length < 2) return const [];
    final first = v.first;
    final last = v.last;
    final out = <MetricResult>[];
    if (first.value != 0) {
      out.add(_result('growth', formatPercent((last.value - first.value) / first.value.abs())));
    }
    final span = last.year - first.year;
    if (first.value > 0 && last.value > 0 && span > 0) {
      final cagr = math.pow(last.value / first.value, 1 / span) - 1;
      out.add(_result('cagr', formatPercent(cagr.toDouble())));
    }
    final prev = v.length >= 2 ? v[v.length - 2] : null;
    if (prev != null && prev.year == last.year - 1 && prev.value != 0) {
      out.add(_result('yoy', formatPercent((last.value - prev.value) / prev.value.abs())));
    }
    if (v.length >= 3) {
      final ols = simpleOls(v.map((p) => p.year.toDouble()).toList(), v.map((p) => p.value).toList());
      if (ols != null) {
        out.add(_result('slope', formatNumber(ols.slope), raw: {'slope': ols.slope, 'intercept': ols.intercept}));
        out.add(_result('trend_r2', ols.r2.toStringAsFixed(3), raw: {'r2': ols.r2}));
      }
    }
    if (v.length >= 3 && v.every((p) => p.value > 0)) {
      final logs = v.map((p) => math.log(p.value)).toList();
      final ols = simpleOls(v.map((p) => p.year.toDouble()).toList(), logs);
      if (ols != null && ols.slope > 0) {
        out.add(_result('doubling', (math.log(2) / ols.slope).toStringAsFixed(1), unit: '年'));
      }
    }
    return out;
  }

  static List<MetricResult> relation(List<double> xs, List<double> ys) {
    final n = math.min(xs.length, ys.length);
    if (n < 3) return const [];
    final x = xs.take(n).toList();
    final y = ys.take(n).toList();
    final r = pearson(x, y);
    final cov = covariance(x, y);
    final out = <MetricResult>[];
    if (r != null) out.add(_result('pearson', r.toStringAsFixed(3), raw: {'r': r}));
    if (cov != null) out.add(_result('covariance', formatNumber(cov)));
    final full = multipleOls(y, x.map((e) => [e]).toList());
    if (full != null) {
      final a = full.coefficients[0];
      final b = full.coefficients[1];
      out.add(_result(
        'ols',
        'y = ${formatNumber(a)} + ${formatNumber(b)}x · R²=${full.r2.toStringAsFixed(3)}',
        raw: {
          'intercept': a,
          'slope': b,
          'se_intercept': full.standardErrors[0],
          'se_slope': full.standardErrors[1],
          't_slope': full.tValues[1],
          'r2': full.r2,
          'adj_r2': full.adjustedR2,
          'n': full.n,
        },
      ));
    }
    if (x.every((e) => e > 0) && y.every((e) => e > 0)) {
      final logOls = simpleOls(x.map((e) => math.log(e)).toList(), y.map((e) => math.log(e)).toList());
      if (logOls != null) {
        out.add(_result('elasticity', logOls.slope.toStringAsFixed(3), raw: {'elasticity': logOls.slope, 'r2': logOls.r2}));
      }
    }
    return out;
  }

  static List<MetricResult> digitalShare(List<double> digital, List<double> gdp) {
    final n = math.min(digital.length, gdp.length);
    final ratios = <double>[];
    for (var i = 0; i < n; i++) {
      if (gdp[i] != 0 && digital[i] >= 0) ratios.add(digital[i] / gdp[i]);
    }
    if (ratios.isEmpty) return const [];
    final latest = ratios.last;
    final avg = ratios.reduce((a, b) => a + b) / ratios.length;
    return [
      _result('digital_share', formatPercent(latest), raw: {'latest': latest, 'avg': avg, 'n': ratios.length}),
    ];
  }

  static List<MetricResult> moore(List<({int year, double value})> points) {
    final v = points.where((p) => p.value > 0).toList()..sort((a, b) => a.year.compareTo(b.year));
    if (v.length < 3) return const [];
    final ols = simpleOls(v.map((p) => p.year.toDouble()).toList(), v.map((p) => math.log(p.value)).toList());
    if (ols == null || ols.slope <= 0) return const [];
    final doubling = math.log(2) / ols.slope;
    return [
      _result('moore', '倍增 ${doubling.toStringAsFixed(1)} 年 · R²=${ols.r2.toStringAsFixed(3)}',
          raw: {'slope': ols.slope, 'doubling': doubling, 'r2': ols.r2}),
    ];
  }

  static List<MetricResult> metcalfe(List<double> nodes, List<double> value) {
    final n = math.min(nodes.length, value.length);
    if (n < 3) return const [];
    final x2 = List<double>.generate(n, (i) => nodes[i] * nodes[i]);
    final ols = simpleOls(x2, value.take(n).toList());
    if (ols == null) return const [];
    return [
      _result('metcalfe', 'b=${formatNumber(ols.slope)} · R²=${ols.r2.toStringAsFixed(3)}',
          raw: {'slope': ols.slope, 'intercept': ols.intercept, 'r2': ols.r2, 'n': n}),
    ];
  }

  static List<MetricResult> solowTfp({
    required List<double> output,
    required List<double> capital,
    required List<double> labor,
    double alpha = 0.3,
  }) {
    final n = [output.length, capital.length, labor.length].reduce((a, b) => a < b ? a : b);
    if (n < 3) return const [];
    final gY = _avgGrowth(output, n);
    final gK = _avgGrowth(capital, n);
    final gL = _avgGrowth(labor, n);
    if (gY == null || gK == null || gL == null) return const [];
    final tfp = gY - alpha * gK - (1 - alpha) * gL;
    return [
      _result('solow_tfp', formatPercent(tfp), raw: {'gY': gY, 'gK': gK, 'gL': gL, 'alpha': alpha, 'tfp': tfp, 'n': n})
    ];
  }

  static List<MetricResult> cobbDouglas({
    required List<double> output,
    required List<double> capital,
    required List<double> labor,
  }) {
    final n = [output.length, capital.length, labor.length].reduce((a, b) => a < b ? a : b);
    if (n < 5) return const [];
    final rows = <List<double>>[];
    for (var i = 0; i < n; i++) {
      if (output[i] <= 0 || capital[i] <= 0 || labor[i] <= 0) continue;
      rows.add([math.log(capital[i]), math.log(labor[i]), math.log(output[i])]);
    }
    if (rows.length < 5) return const [];
    final ols = multipleOls(rows.map((e) => e[2]).toList(), rows.map((e) => [e[0], e[1]]).toList());
    if (ols == null) return const [];
    final a = ols.coefficients[1];
    final b = ols.coefficients[2];
    final rts = a + b;
    return [
      _result('cobb_douglas', 'α=${a.toStringAsFixed(3)} · β=${b.toStringAsFixed(3)} · α+β=${rts.toStringAsFixed(3)} · R²=${ols.r2.toStringAsFixed(3)}',
          raw: {'alpha': a, 'beta': b, 'rts': rts, 'r2': ols.r2, 'n': rows.length}),
    ];
  }

  static List<MetricResult> hhi(List<double> shares) {
    final v = shares.where((e) => e >= 0).toList();
    if (v.isEmpty) return const [];
    final sum = v.reduce((a, b) => a + b);
    if (sum <= 0) return const [];
    final norm = v.map((e) => e / sum).toList();
    final hhi = norm.map((e) => e * e).reduce((a, b) => a + b) * 10000;
    return [
      _result('hhi', hhi.toStringAsFixed(1), raw: {'hhi': hhi, 'n': v.length})
    ];
  }

  static List<MetricResult> gini(List<double> values) {
    final v = values.where((e) => e >= 0).toList()..sort();
    final n = v.length;
    final sum = v.reduce((a, b) => a + b);
    if (n < 2 || sum <= 0) return const [];
    var weighted = 0.0;
    for (var i = 0; i < n; i++) {
      weighted += (i + 1) * v[i];
    }
    final g = (2 * weighted) / (n * sum) - (n + 1) / n;
    return [
      _result('gini', g.toStringAsFixed(3), raw: {'gini': g, 'n': n})
    ];
  }

  static double? pearson(List<double> x, List<double> y) {
    final n = math.min(x.length, y.length);
    if (n < 3) return null;
    final mx = x.take(n).reduce((a, b) => a + b) / n;
    final my = y.take(n).reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = x[i] - mx;
      final dy = y[i] - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx <= 0 || syy <= 0) return null;
    return sxy / math.sqrt(sxx * syy);
  }

  static double? covariance(List<double> x, List<double> y) {
    final n = math.min(x.length, y.length);
    if (n < 2) return null;
    final mx = x.take(n).reduce((a, b) => a + b) / n;
    final my = y.take(n).reduce((a, b) => a + b) / n;
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += (x[i] - mx) * (y[i] - my);
    }
    return s / (n - 1);
  }

  static ({double slope, double intercept, double r2})? simpleOls(List<double> x, List<double> y) {
    final n = math.min(x.length, y.length);
    if (n < 3) return null;
    final mx = x.take(n).reduce((a, b) => a + b) / n;
    final my = y.take(n).reduce((a, b) => a + b) / n;
    var sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (x[i] - mx) * (x[i] - mx);
      sxy += (x[i] - mx) * (y[i] - my);
    }
    if (sxx <= 0) return null;
    final slope = sxy / sxx;
    final intercept = my - slope * mx;
    var sst = 0.0, sse = 0.0;
    for (var i = 0; i < n; i++) {
      final fit = intercept + slope * x[i];
      sst += (y[i] - my) * (y[i] - my);
      sse += (y[i] - fit) * (y[i] - fit);
    }
    final r2 = sst <= 0 ? 0.0 : 1 - sse / sst;
    return (slope: slope, intercept: intercept, r2: r2);
  }

  static OlsResult? multipleOls(List<double> y, List<List<double>> xs) {
    final n = y.length;
    if (n < 3 || xs.any((r) => r.length != xs.first.length)) return null;
    final p = xs.first.length + 1;
    if (n <= p) return null;
    final X = List<List<double>>.generate(n, (i) => [1.0, ...xs[i]]);
    final XtX = List<List<double>>.generate(p, (i) => List<double>.filled(p, 0));
    final Xty = List<double>.filled(p, 0);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < p; j++) {
        Xty[j] += X[i][j] * y[i];
        for (var k = 0; k < p; k++) {
          XtX[j][k] += X[i][j] * X[i][k];
        }
      }
    }
    final inv = _invert(XtX);
    if (inv == null) return null;
    final beta = List<double>.generate(p, (i) => List<double>.generate(p, (j) => inv[i][j] * Xty[j]).reduce((a, b) => a + b));
    var sse = 0.0;
    final my = y.reduce((a, b) => a + b) / n;
    var sst = 0.0;
    for (var i = 0; i < n; i++) {
      final fit = List<double>.generate(p, (j) => beta[j] * X[i][j]).reduce((a, b) => a + b);
      sse += math.pow(y[i] - fit, 2).toDouble();
      sst += math.pow(y[i] - my, 2).toDouble();
    }
    final r2 = sst <= 0 ? 0.0 : 1 - sse / sst;
    final adj = 1 - (1 - r2) * (n - 1) / (n - p);
    final mse = sse / (n - p);
    final se = List<double>.generate(p, (j) => math.sqrt(math.max(0, mse * inv[j][j])));
    final t = List<double>.generate(p, (j) => se[j] == 0 ? 0 : beta[j] / se[j]);
    return OlsResult(
      labels: ['常数项', ...List.generate(p - 1, (i) => 'x${i + 1}')],
      coefficients: beta,
      standardErrors: se,
      tValues: t,
      r2: r2,
      adjustedR2: adj,
      n: n,
    );
  }

  static List<List<double>>? _invert(List<List<double>> a) {
    final n = a.length;
    final m = List<List<double>>.generate(n, (i) => [...a[i], ...List<double>.generate(n, (j) => i == j ? 1 : 0)]);
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-12) return null;
      if (pivot != col) {
        final tmp = m[pivot];
        m[pivot] = m[col];
        m[col] = tmp;
      }
      final pv = m[col][col];
      for (var j = 0; j < 2 * n; j++) {
        m[col][j] /= pv;
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = m[r][col];
        if (f == 0) continue;
        for (var j = 0; j < 2 * n; j++) {
          m[r][j] -= f * m[col][j];
        }
      }
    }
    return List<List<double>>.generate(n, (i) => m[i].sublist(n));
  }

  static double _quantile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final pos = (sorted.length - 1) * p;
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  static double? _avgGrowth(List<double> values, int n) {
    if (n < 2) return null;
    var sum = 0.0;
    var count = 0;
    for (var i = 1; i < n; i++) {
      if (values[i - 1] == 0) continue;
      sum += (values[i] - values[i - 1]) / values[i - 1].abs();
      count++;
    }
    return count == 0 ? null : sum / count;
  }
}
