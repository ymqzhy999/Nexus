import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analysis/metrics.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../data/table_data.dart';
import '../export/exporters.dart';
import '../state/providers.dart';

class DatasetPage extends ConsumerStatefulWidget {
  final int datasetId;

  const DatasetPage({super.key, required this.datasetId});

  @override
  ConsumerState<DatasetPage> createState() => _DatasetPageState();
}

class _DatasetPageState extends ConsumerState<DatasetPage> {
  Dataset? _record;
  TableData? _table;
  bool _loading = true;
  String? _error;
  int? _yearCol;
  int? _valueCol;
  int? _compareCol;
  int _startYear = 0;
  int _endYear = 0;
  List<MetricResult> _metrics = const [];
  Map<String, dynamic>? _aiPlan;
  String _aiText = '';
  bool _aiBusy = false;
  bool _exportBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await ref.read(datasetsRepositoryProvider).getDataset(widget.datasetId);
    if (!mounted) return;
    if (record == null) {
      setState(() {
        _loading = false;
        _error = '数据集不存在';
      });
      return;
    }
    final table = TableData.fromRecord(record);
    final years = table.years();
    final yc = table.yearColumn();
    final nums = table.numericColumns();
    setState(() {
      _record = record;
      _table = table;
      _yearCol = yc;
      _valueCol = nums.isNotEmpty ? nums.first : null;
      _compareCol = nums.length > 1 ? nums[1] : null;
      _startYear = years.isNotEmpty ? years.first : 0;
      _endYear = years.isNotEmpty ? years.last : 0;
      _loading = false;
    });
    _recompute();
    final analysis = await ref.read(datasetsRepositoryProvider).latestAnalysis(widget.datasetId);
    if (analysis != null && mounted) {
      try {
        final ai = jsonDecode(analysis.aiJson);
        if (ai is Map && ai['text'] != null) {
          setState(() => _aiText = ai['text'].toString());
        }
      } catch (_) {}
    }
  }

  TableData get _filtered {
    final t = _table;
    if (t == null || _yearCol == null || _startYear == 0) return t ?? const TableData(title: '', headers: [], rows: []);
    final rows = t.rows.where((r) {
      if (_yearCol! >= r.length) return false;
      final y = yearOf(r[_yearCol!]);
      return y != null && y >= _startYear && y <= _endYear;
    }).toList();
    return t.copyWith(rows: rows);
  }

  void _recompute() {
    final t = _filtered;
    final vc = _valueCol;
    if (vc == null) {
      setState(() => _metrics = const []);
      return;
    }
    final values = t.numericSeries(vc).whereType<double>().toList();
    final metrics = <MetricResult>[...StatsEngine.descriptive(values, label: t.headers[vc])];
    if (_yearCol != null) {
      final points = t.yearValuePairs(vc, _yearCol!);
      metrics.addAll(StatsEngine.trend(points));
    }
    if (_compareCol != null && _compareCol != vc) {
      final xs = <double>[];
      final ys = <double>[];
      for (final r in t.rows) {
        if (vc >= r.length || _compareCol! >= r.length) continue;
        final y = parseNumeric(r[vc]);
        final x = parseNumeric(r[_compareCol!]);
        if (x != null && y != null) {
          xs.add(x);
          ys.add(y);
        }
      }
      metrics.addAll(StatsEngine.relation(xs, ys));
    }
    _addDigitalMetrics(t, metrics);
    final seen = <String>{};
    final deduped = <MetricResult>[];
    for (final m in metrics) {
      if (seen.add(m.key)) deduped.add(m);
    }
    setState(() => _metrics = deduped);
  }

  void _addDigitalMetrics(TableData t, List<MetricResult> out) {
    int? col(List<String> needles) {
      for (var i = 0; i < t.headers.length; i++) {
        final h = t.headers[i].toLowerCase();
        if (needles.any((n) => h.contains(n.toLowerCase()))) return i;
      }
      return null;
    }

    int? exact(List<String> names) {
      for (var i = 0; i < t.headers.length; i++) {
        final h = t.headers[i].trim().toLowerCase();
        if (names.contains(h)) return i;
      }
      return null;
    }

    List<List<double>> aligned(List<int> cols) {
      final result = <List<double>>[];
      for (final r in t.rows) {
        final vals = <double>[];
        var ok = true;
        for (final c in cols) {
          if (c >= r.length) {
            ok = false;
            break;
          }
          final v = parseNumeric(r[c]);
          if (v == null) {
            ok = false;
            break;
          }
          vals.add(v);
        }
        if (ok) result.add(vals);
      }
      return result;
    }

    List<double> one(int c) => aligned([c]).map((e) => e.first).toList();

    final digital = col(['数字经济', '数字产业', 'digital']);
    final gdp = col(['gdp', '国内生产总值']);
    if (digital != null && gdp != null && digital != gdp) {
      final pairs = aligned([digital, gdp]);
      out.addAll(StatsEngine.digitalShare(
        pairs.map((e) => e[0]).toList(),
        pairs.map((e) => e[1]).toList(),
      ));
    }
    final nodes = col(['节点', '用户数', 'nodes']);
    final value = col(['价值', '收入', '营收', 'value']);
    if (nodes != null && value != null && nodes != value) {
      final pairs = aligned([nodes, value]);
      out.addAll(StatsEngine.metcalfe(
        pairs.map((e) => e[0]).toList(),
        pairs.map((e) => e[1]).toList(),
      ));
    }
    if (_yearCol != null && _valueCol != null) {
      final points = t.yearValuePairs(_valueCol!, _yearCol!);
      if (points.length >= 3 && points.every((p) => p.value > 0)) {
        out.addAll(StatsEngine.moore(points));
      }
    }
    final y = col(['产出', '总产出', 'output']) ?? exact(['y']);
    final k = col(['资本', 'capital']) ?? exact(['k']);
    final l = col(['劳动', '就业', 'labor', 'labour']) ?? exact(['l']);
    if (y != null && k != null && l != null) {
      final rows = aligned([y, k, l]);
      final ys = rows.map((e) => e[0]).toList();
      final ks = rows.map((e) => e[1]).toList();
      final ls = rows.map((e) => e[2]).toList();
      out.addAll(StatsEngine.solowTfp(output: ys, capital: ks, labor: ls));
      out.addAll(StatsEngine.cobbDouglas(output: ys, capital: ks, labor: ls));
    }
    final share = col(['份额', 'share']);
    if (share != null) out.addAll(StatsEngine.hhi(one(share)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: NColors.bg,
        body: Center(child: CircularProgressIndicator(color: NColors.cyan)),
      );
    }
    if (_error != null || _record == null || _table == null) {
      return Scaffold(
        backgroundColor: NColors.bg,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(child: Text(_error ?? '加载失败', style: const TextStyle(color: NColors.muted))),
      );
    }
    final t = _table!;
    final years = t.years();
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop()),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, size: 19), onPressed: _confirmDelete),
          const SizedBox(width: 4),
        ],
      ),
      body: NexusBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoLabel('${t.sourceName} / DATASET', color: NColors.lime),
                      const SizedBox(height: 6),
                      Text(t.title, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('${t.rows.length} 行 × ${t.headers.length} 列 · ${prettyDate(_record!.createdAt)}',
                          style: kMono.copyWith(fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (years.length >= 2) _yearFilter(years),
            if (years.length >= 2) const SizedBox(height: 10),
            _columnSelectors(t),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NeonButton(
                    label: 'AI 建议指标',
                    icon: Icons.auto_awesome,
                    color: NColors.violet,
                    loading: _aiBusy,
                    onTap: _suggest,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    label: 'AI 解读',
                    icon: Icons.insights,
                    color: NColors.cyan,
                    loading: _aiBusy,
                    onTap: _interpret,
                  ),
                ),
              ],
            ),
            if (_aiPlan != null) ...[
              const SizedBox(height: 12),
              _suggestionCard(),
            ],
            if (_aiText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _aiCard(),
            ],
            const SizedBox(height: 18),
            SectionHeader(
              kicker: 'COMPUTED METRICS',
              title: '本地计算结果',
              trailing: MonoLabel('${_metrics.length} 项'),
            ),
            if (_metrics.isEmpty)
              const EmptyState(
                icon: Icons.functions,
                title: '没有可计算的指标',
                subtitle: '检查数值列是否识别正确，或换一列。',
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.75,
                children: [for (final m in _metrics) _metricCard(m)],
              ),
            const SizedBox(height: 20),
            SectionHeader(kicker: 'PREVIEW', title: '数据预览', trailing: MonoLabel('前 10 行')),
            GlassCard(
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: kMono.copyWith(fontSize: 8, color: NColors.cyan),
                  dataTextStyle: const TextStyle(fontSize: 9, color: NColors.text),
                  columnSpacing: 14,
                  horizontalMargin: 6,
                  columns: [for (final h in t.headers.take(8)) DataColumn(label: Text(h))],
                  rows: [
                    for (final r in t.rows.take(10))
                      DataRow(cells: [for (var i = 0; i < t.headers.take(8).length; i++) DataCell(Text(i < r.length ? r[i] : ''))]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(kicker: 'EXPORT', title: '导出'),
            Row(
              children: [
                Expanded(child: _exportButton('Excel', Icons.grid_on, NColors.lime, _exportExcel)),
                const SizedBox(width: 8),
                Expanded(child: _exportButton('PDF', Icons.picture_as_pdf_outlined, NColors.pink, _exportPdf)),
                const SizedBox(width: 8),
                Expanded(child: _exportButton('CSV', Icons.description_outlined, NColors.cyan, _exportCsv)),
              ],
            ),
            if (_exportBusy)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2, color: NColors.cyan),
              ),
            const SizedBox(height: 16),
            Text(
              '所有指标由本地 Dart 代码计算；公式见指标详情。AI 只做建议与解释，不生成公式或数字。',
              style: kMono.copyWith(fontSize: 8, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearFilter(List<int> years) {
    final min = years.first.toDouble();
    final max = years.last.toDouble();
    final start = _startYear.clamp(years.first, years.last).toDouble();
    final end = _endYear.clamp(years.first, years.last).toDouble();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              const MonoLabel('YEAR RANGE'),
              const Spacer(),
              Text('$_startYear – $_endYear', style: kMono.copyWith(fontSize: 9, color: NColors.cyan)),
            ],
          ),
          RangeSlider(
            values: RangeValues(start <= end ? start : end, end >= start ? end : start),
            min: min,
            max: max,
            divisions: (max - min).round().clamp(1, 200).toInt(),
            labels: RangeLabels('${start.round()}', '${end.round()}'),
            activeColor: NColors.cyan,
            onChanged: (v) {
              setState(() {
                _startYear = v.start.round();
                _endYear = v.end.round();
              });
              _recompute();
            },
          ),
        ],
      ),
    );
  }

  Widget _columnSelectors(TableData t) {
    final nums = t.numericColumns();
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _intDropdown('数值列', _valueCol, nums, t.headers, (v) {
                setState(() => _valueCol = v);
                _recompute();
              })),
              const SizedBox(width: 8),
              Expanded(child: _intDropdown('对比列', _compareCol, nums, t.headers, (v) {
                setState(() => _compareCol = v);
                _recompute();
              })),
            ],
          ),
          const SizedBox(height: 8),
          _intDropdown('年份列', _yearCol, List.generate(t.headers.length, (i) => i), t.headers, (v) {
            setState(() {
              _yearCol = v;
              final years = t.years();
              if (years.isNotEmpty) {
                _startYear = years.first;
                _endYear = years.last;
              }
            });
            _recompute();
          }),
        ],
      ),
    );
  }

  Widget _intDropdown(String label, int? value, List<int> options, List<String> headers, ValueChanged<int?> onChanged) {
    final v = value != null && options.contains(value) ? value : null;
    return DropdownButtonFormField<int?>(
      value: v,
      isExpanded: true,
      dropdownColor: NColors.surface,
      style: const TextStyle(fontSize: 11, color: NColors.text),
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('无')),
        for (final i in options)
          DropdownMenuItem<int?>(value: i, child: Text(i < headers.length ? headers[i] : '列$i', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _metricCard(MetricResult m) {
    return GlassCard(
      padding: const EdgeInsets.all(11),
      accent: _metricColor(m.group),
      onTap: () => _showMetric(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: NColors.muted)),
              ),
              Text(m.unit, style: kMono.copyWith(fontSize: 7.5)),
            ],
          ),
          const Spacer(),
          Text(m.value, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14, fontWeight: FontWeight.w700, color: _metricColor(m.group))),
        ],
      ),
    );
  }

  Color _metricColor(MetricGroup g) => switch (g) {
        MetricGroup.descriptive => NColors.cyan,
        MetricGroup.trend => NColors.lime,
        MetricGroup.relation => NColors.violet,
        MetricGroup.digital => NColors.amber,
      };

  void _showMetric(MetricResult m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                Text(m.unit, style: kMono.copyWith(fontSize: 9)),
              ],
            ),
            const SizedBox(height: 10),
            Text(m.value, style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 22, fontWeight: FontWeight.w700, color: _metricColor(m.group))),
            const SizedBox(height: 14),
            const MonoLabel('FORMULA'),
            const SizedBox(height: 6),
            SelectableText(m.formula, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, height: 1.7, color: NColors.violet)),
            const SizedBox(height: 12),
            Text(m.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7)),
            const SizedBox(height: 10),
            Text('假设：${m.assumption}', style: kMono.copyWith(fontSize: 8.5, height: 1.6)),
            if (m.raw.isNotEmpty) ...[
              const SizedBox(height: 12),
              const MonoLabel('COMPUTATION / DETAIL'),
              const SizedBox(height: 5),
              Text(
                m.raw.entries
                    .map((e) => '${e.key}: ${e.value is num ? (e.value as num).toStringAsFixed(4) : e.value}')
                    .join('\n'),
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 8.5, height: 1.6, color: NColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard() {
    final summary = (_aiPlan!['summary'] ?? '').toString();
    final list = _aiPlan!['metrics'];
    return GlassCard(
      accent: NColors.violet,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoLabel('AI SUGGESTION / WHITELIST ONLY', color: NColors.violet),
          const SizedBox(height: 8),
          if (summary.isNotEmpty) Text(summary, style: const TextStyle(fontSize: 12, height: 1.6)),
          if (list is List)
            for (final e in list.whereType<Map>()) ...[
              const SizedBox(height: 7),
              Text(
                '• ${specOf((e['key'] ?? '').toString())?.name ?? e['key']}：${e['reason'] ?? ''}',
                style: const TextStyle(fontSize: 11, height: 1.5, color: NColors.text),
              ),
            ],
        ],
      ),
    );
  }

  Widget _aiCard() {
    return GlassCard(
      accent: NColors.cyan,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 14, color: NColors.cyan),
              const SizedBox(width: 6),
              const MonoLabel('AI INTERPRETATION / GROUNDED', color: NColors.cyan),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _aiText = ''),
                child: const Icon(Icons.close, size: 14, color: NColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(_aiText, style: const TextStyle(fontSize: 12.5, height: 1.75, color: Color(0xFFDCE7F5))),
        ],
      ),
    );
  }

  Widget _exportButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _exportBusy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _suggest() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      _snack('先在设置里填写 DeepSeek API Key');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final t = _filtered;
      final catalog = metricSpecs
          .map((e) => {'key': e.key, 'name': e.name, 'formula': e.formula, 'assumption': e.assumption})
          .toList();
      final columns = t.headers.asMap().entries
          .map((e) => '${e.value} (${t.numericColumns().contains(e.key) ? '数值' : '文本'})')
          .join('\n');
      final sample = t.rows.take(5).map((r) => r.join(' | ')).join('\n');
      final plan = await ref.read(deepSeekClientProvider).suggestMetrics(
            columns: columns,
            sampleRows: sample,
            catalog: catalog,
            language: settings.outputLanguage,
          );
      if (!mounted) return;
      setState(() {
        _aiPlan = plan;
        _aiBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      _snack(e.toString());
    }
  }

  Future<void> _interpret() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      _snack('先在设置里填写 DeepSeek API Key');
      return;
    }
    if (_metrics.isEmpty) {
      _snack('先有可计算的指标，再让 AI 解读');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final t = _filtered;
      final buf = StringBuffer();
      buf.writeln('数据集：${t.title}');
      buf.writeln('列：${t.headers.join(', ')}');
      if (_yearCol != null) {
        final points = t.yearValuePairs(_valueCol!, _yearCol!);
        buf.writeln('时间序列（${t.headers[_valueCol!]}）：');
        buf.writeln(points.take(40).map((p) => '${p.year}: ${p.value}').join('; '));
      }
      buf.writeln('本地已计算指标（不得改动）：');
      for (final m in _metrics) {
        buf.writeln('- ${m.name}: ${m.value}${m.unit.isEmpty ? '' : ' ${m.unit}'}');
      }
      final text = await ref.read(deepSeekClientProvider).interpretDataset(
            context: buf.toString(),
            language: settings.outputLanguage,
          );
      await ref.read(datasetsRepositoryProvider).saveAnalysis(
            datasetId: widget.datasetId,
            metrics: _metrics,
            aiText: text,
            model: settings.model,
            inputTokens: 0,
            outputTokens: 0,
          );
      if (!mounted) return;
      setState(() {
        _aiText = text;
        _aiBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      _snack(e.toString());
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exportBusy = true);
    try {
      final f = await DatasetExporter.excel(_filtered, _metrics, _aiText);
      await DatasetExporter.share(f, text: '${_filtered.title} · Nexus 数据导出');
    } catch (e) {
      _snack('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exportBusy = true);
    try {
      final f = await DatasetExporter.pdf(_filtered, _metrics, _aiText);
      await DatasetExporter.share(f, text: '${_filtered.title} · Nexus 数据报告');
    } catch (e) {
      _snack('PDF 导出失败：$e');
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportBusy = true);
    try {
      final f = await DatasetExporter.csv(_filtered);
      await DatasetExporter.share(f, text: '${_filtered.title} · CSV');
    } catch (e) {
      _snack('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('删除数据集？'),
        content: const Text('只删除这个数据集，不影响情报流。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Color(0xFFFF8A9A)))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(datasetsRepositoryProvider).deleteDataset(widget.datasetId);
      if (mounted) context.pop();
    }
  }
}
