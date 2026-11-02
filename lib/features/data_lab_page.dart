import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/data_sources.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../crawl/http_client.dart';
import '../data/database.dart';
import '../data/table_data.dart';
import '../data/table_parser.dart';
import '../data/world_bank.dart';
import '../state/providers.dart';

class DataLabPage extends ConsumerWidget {
  const DataLabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasets = ref.watch(datasetsProvider);
    return NexusBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const MonoLabel('DATA LAB / OPEN DATA', color: NColors.lime),
            const SizedBox(height: 8),
            Text('数据实验室', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text('政府统计 · 世界银行 · 年鉴表格 · 计量分析 · Excel/PDF',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.32,
              children: [
                _ActionTile(
                  icon: Icons.public,
                  color: NColors.cyan,
                  title: '世界银行',
                  subtitle: '按国家/年份取 GDP、CPI、人口等',
                  onTap: () => _openWorldBank(context),
                ),
                _ActionTile(
                  icon: Icons.table_chart_outlined,
                  color: NColors.lime,
                  title: '表格导入',
                  subtitle: '网页 / CSV / JSON / Excel',
                  onTap: () => _openImport(context),
                ),
                _ActionTile(
                  icon: Icons.account_balance_outlined,
                  color: NColors.amber,
                  title: '省份年鉴',
                  subtitle: '31 个省级统计局 + 抓表格',
                  onTap: () => context.push('/provinces'),
                ),
                _ActionTile(
                  icon: Icons.auto_stories_outlined,
                  color: NColors.violet,
                  title: '数字经济理论',
                  subtitle: '摩尔、梅特卡夫、索洛、CD 函数',
                  onTap: () => context.push('/theory'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionHeader(
              kicker: 'AUTHORITATIVE SOURCES',
              title: '权威数据入口',
              trailing: MonoLabel('${govPortals.length} SITES'),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: govPortals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = govPortals[i];
                  return GestureDetector(
                    onTap: () => context.push(
                      '/data-browser?url=${Uri.encodeComponent(p.url)}&title=${Uri.encodeComponent(p.name)}',
                    ),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(p.category, style: kMono.copyWith(fontSize: 8, color: NColors.violet)),
                          const Spacer(),
                          Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5, color: NColors.muted, height: 1.4)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader(
              kicker: 'DATASETS',
              title: '我的数据集',
              trailing: MonoLabel('${datasets.valueOrNull?.length ?? 0} 个'),
            ),
            datasets.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: NColors.lime)),
              ),
              error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.table_view,
                    title: '还没有数据集',
                    subtitle: '从世界银行导入，或贴一个政府统计表格 URL。\n所有数据永久保存在本地。',
                  );
                }
                return Column(children: [for (final d in list) _DatasetCard(dataset: d)]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWorldBank(BuildContext context) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _WorldBankSheet(),
    );
    if (id != null && context.mounted) context.push('/dataset/$id');
  }

  Future<void> _openImport(BuildContext context) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _ImportSheet(),
    );
    if (id != null && context.mounted) context.push('/dataset/$id');
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.11), Colors.white.withValues(alpha: 0.02)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, color: NColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _DatasetCard extends ConsumerWidget {
  final Dataset dataset;

  const _DatasetCard({required this.dataset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = dataset.rowCount;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 9),
      accent: NColors.lime,
      padding: const EdgeInsets.all(13),
      onTap: () => context.push('/dataset/${dataset.id}'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NColors.lime.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.table_chart_outlined, size: 19, color: NColors.lime),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dataset.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('$rows 行 · ${dataset.sourceName} · ${prettyDate(dataset.createdAt)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: kMono.copyWith(fontSize: 8)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: NColors.muted),
        ],
      ),
    );
  }
}

class _WorldBankSheet extends ConsumerStatefulWidget {
  const _WorldBankSheet();

  @override
  ConsumerState<_WorldBankSheet> createState() => _WorldBankSheetState();
}

class _WorldBankSheetState extends ConsumerState<_WorldBankSheet> {
  WbCountry _country = wbCountries.first;
  WbIndicator _indicator = wbIndicators.first;
  int _start = 2010;
  int _end = DateTime.now().year;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('WORLD BANK / API', color: NColors.cyan),
            const SizedBox(height: 8),
            Text('导入世界银行指标', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('按国家 + 指标 + 年份区间取年度数据，写入本地数据集。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<WbCountry>(
              value: _country,
              dropdownColor: NColors.surface,
              items: wbCountries.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              onChanged: (v) => setState(() => _country = v ?? _country),
              decoration: const InputDecoration(labelText: '国家 / 地区'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<WbIndicator>(
              value: _indicator,
              dropdownColor: NColors.surface,
              isExpanded: true,
              items: wbIndicators.map((e) => DropdownMenuItem(value: e, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _indicator = v ?? _indicator),
              decoration: const InputDecoration(labelText: '指标'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _YearDropdown(label: '起始年', value: _start, onChanged: (v) => setState(() => _start = v))),
                const SizedBox(width: 10),
                Expanded(child: _YearDropdown(label: '结束年', value: _end, onChanged: (v) => setState(() => _end = v))),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF9AA8), fontSize: 11)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: '导入数据',
                icon: Icons.cloud_download_outlined,
                loading: _loading,
                onTap: _loading ? null : _import,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    if (_start > _end) {
      setState(() => _error = '起始年份不能晚于结束年份');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = WorldBankService(ref.read(httpFetcherProvider));
      final table = await service.fetch(
        country: _country,
        indicator: _indicator,
        startYear: _start,
        endYear: _end,
      );
      final id = await ref.read(datasetsRepositoryProvider).saveDataset(table);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
}

class _YearDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _YearDropdown({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    return DropdownButtonFormField<int>(
      value: value,
      dropdownColor: NColors.surface,
      items: [for (var y = 1990; y <= now; y++) DropdownMenuItem(value: y, child: Text('$y'))],
      onChanged: (v) => onChanged(v ?? value),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet();

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  final _url = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('TABLE IMPORT', color: NColors.lime),
            const SizedBox(height: 8),
            Text('导入网页表格 / CSV / JSON / Excel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('支持政府统计页的 HTML 表格、CSV、JSON 和 .xlsx 下载链接；JS 很重的页面用「省份年鉴」里的浏览器抓表。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://data.stats.gov.cn/... 或 .csv /.json /.xlsx',
                prefixIcon: Icon(Icons.link, size: 17, color: NColors.muted),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF9AA8), fontSize: 11, height: 1.5)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: '抓取并识别',
                icon: Icons.download_outlined,
                loading: _loading,
                onTap: _loading ? null : _import,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final http = ref.read(httpFetcherProvider);
      final isExcel = url.toLowerCase().endsWith('.xlsx') || url.toLowerCase().endsWith('.xls');
      ParsedTables parsed;
      if (isExcel) {
        final res = await http.getBytes(url);
        if (!res.ok) throw Exception('下载失败：HTTP ${res.statusCode}');
        parsed = TableParser.parseBytes(bytes: res.bytes, url: url, sourceName: sourceHost(url), contentType: res.contentType);
      } else {
        final res = await http.get(url, force: true);
        if (!res.ok) throw Exception('抓取失败：HTTP ${res.statusCode}');
        parsed = TableParser.parseText(text: res.body, url: url, sourceName: sourceHost(url), contentType: res.contentType);
      }
      if (parsed.tables.isEmpty) throw Exception(parsed.error ?? '没有识别到表格');
      var table = parsed.tables.first;
      if (parsed.tables.length > 1) {
        final chosen = await _pickTable(parsed.tables);
        if (chosen == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        table = chosen;
      }
      final id = await ref.read(datasetsRepositoryProvider).saveDataset(table);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<TableData?> _pickTable(List<TableData> tables) async {
    return showModalBottomSheet<TableData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const MonoLabel('SELECT TABLE', color: NColors.lime),
            const SizedBox(height: 8),
            Text('识别到 ${tables.length} 个表格，选择要导入的', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < tables.length; i++)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () => Navigator.pop(context, tables[i]),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text('${i + 1}', style: kMono.copyWith(fontSize: 11, color: NColors.lime)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tables[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('${tables[i].rows.length} 行 × ${tables[i].headers.length} 列',
                              style: kMono.copyWith(fontSize: 8.5)),
                          const SizedBox(height: 2),
                          Text(tables[i].headers.take(5).join(' · '), maxLines: 1,
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: NColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
