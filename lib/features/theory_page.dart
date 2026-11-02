import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analysis/metrics.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class TheoryPage extends StatelessWidget {
  const TheoryPage({super.key});

  static const _keys = ['moore', 'metcalfe', 'digital_share', 'solow_tfp', 'cobb_douglas', 'hhi', 'gini'];
  static const _intro = {
    'moore': '算力/性能按指数增长的经验规律；用 log-linear 回归估计增长速度与倍增时间。它不是物理定律，而是产业观察。',
    'metcalfe': '网络价值与用户数平方成正比的经验假说；用 V = a + b·n² 拟合，R² 只说明拟合程度，不等于因果。',
    'digital_share': '数字产业化与产业数字化的规模占 GDP 比重；口径必须一致，否则跨年不可比。',
    'solow_tfp': '增长核算把产出增长拆成资本、劳动与全要素生产率；TFP 是残差，包含技术、制度、配置效率等，不能简单等同于“技术进步”。',
    'cobb_douglas': '经典的资本-劳动生产函数；α、β 是产出弹性，α+β 判断规模报酬。对数线性设定是强假设。',
    'hhi': '市场集中度指标；份额越集中 HHI 越高。份额口径要覆盖同一市场边界。',
    'gini': '不平等程度指标；0 完全平等、1 完全不平等。分组数据与微观数据算出的基尼可能不同。',
  };

  @override
  Widget build(BuildContext context) {
    final specs = _keys.map(specOf).whereType<MetricSpec>().toList();
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('数字经济理论', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: NexusBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: [
              const MonoLabel('DIGITAL ECONOMY / THEORY', color: NColors.violet),
              const SizedBox(height: 8),
              Text('理论不是装饰', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '下面每个指标都由本地代码计算；公式、假设和口径固定写死。AI 只能建议“这组数据适合看哪些理论”，不能改公式或编数字。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 18),
              for (final s in specs) _TheoryCard(spec: s, intro: _intro[s.key] ?? ''),
              const SizedBox(height: 10),
              Text(
                '注意：这些是经验规律/恒等式/回归模型，不是因果识别。写论文时需说明样本、口径、识别策略与稳健性检验。',
                style: kMono.copyWith(fontSize: 8.5, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TheoryCard extends StatelessWidget {
  final MetricSpec spec;
  final String intro;

  const _TheoryCard({required this.spec, required this.intro});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      accent: NColors.violet,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(spec.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(spec.unit.isEmpty ? '无量纲' : spec.unit, style: kMono.copyWith(fontSize: 8)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: NColors.violet.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: NColors.violet.withValues(alpha: 0.15)),
            ),
            child: Text(spec.formula, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, height: 1.6, color: NColors.violet)),
          ),
          const SizedBox(height: 9),
          if (intro.isNotEmpty) ...[
            Text(intro, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7)),
            const SizedBox(height: 7),
          ],
          Text('假设：${spec.assumption}', style: kMono.copyWith(fontSize: 8.5, height: 1.6)),
        ],
      ),
    );
  }
}
