import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/stat_sites.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/crawl_controller.dart';
import '../state/providers.dart';

class CrawlPage extends ConsumerStatefulWidget {
  const CrawlPage({super.key});

  @override
  ConsumerState<CrawlPage> createState() => _CrawlPageState();
}

class _CrawlPageState extends ConsumerState<CrawlPage> {
  final _keyword = TextEditingController();
  final _seed = TextEditingController();
  final Set<String> _selected = {};
  int? _startYear;
  int? _endYear;
  bool _advanced = false;
  bool _aiLoading = false;
  bool _jobManage = false;
  final Set<int> _jobSelected = {};
  String? _aiNote;

  @override
  void dispose() {
    _keyword.dispose();
    _seed.dispose();
    super.dispose();
  }

  void _start() {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      _snack('先填关键词，例如：广东 GDP、全国 CPI、财政支出');
      return;
    }
    final settings = ref.read(appSettingsProvider);
    final seeds = <String>[
      for (final s in statSites)
        if (_selected.contains(s.id)) s.url,
    ];
    final extra = _seed.text
        .split(RegExp(r'[\s,，、;；\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    seeds.addAll(extra);
    if (seeds.isEmpty) {
      seeds.addAll(suggestStatSites(keyword).map((e) => e.url));
    }
    if (seeds.isEmpty) {
      _snack('没有可用站点，请到「站点」里选择或填写一个 URL');
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(ref.read(crawlControllerProvider.notifier).start(
          keyword: keyword,
          seeds: seeds,
          maxPages: settings.crawlMaxPages,
          maxDepth: settings.crawlMaxDepth,
          startYear: _startYear,
          endYear: _endYear,
        ));
  }

  Future<void> _aiSuggest() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      _snack('先填关键词，AI 才能判断哪些站点可能有数据');
      return;
    }
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      _snack('未配置 DeepSeek Key，已使用内置规则推荐');
      setState(() => _aiNote = '内置规则：优先国家统计局 + 省级年鉴/数据开放平台');
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiNote = null;
    });
    try {
      final catalog = statSites
          .map((s) => {'id': s.id, 'name': s.name, 'category': s.category, 'description': s.description})
          .toList();
      final json = await ref.read(deepSeekClientProvider).suggestStatSites(
            keyword: keyword,
            catalog: catalog,
            language: settings.outputLanguage,
          );
      final list = json['sites'];
      final ids = <String>{};
      if (list is List) {
        for (final e in list.whereType<Map>()) {
          final id = (e['id'] ?? '').toString();
          if (statSites.any((s) => s.id == id)) ids.add(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _selected
          ..clear()
          ..addAll(ids);
        _aiNote = (json['note'] ?? '').toString();
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      _snack('AI 推荐失败：$e');
    }
  }

  Future<void> _deleteJobs() async {
    final ids = _jobSelected.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: Text('删除 ${ids.length} 个任务？', style: const TextStyle(fontSize: 15)),
        content: const Text('任务记录会删除，已入库的数据集保留。', style: TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in ids) {
      await ref.read(crawlControllerProvider.notifier).deleteJob(id);
    }
    if (!mounted) return;
    setState(() {
      _jobSelected.clear();
      _jobManage = false;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final crawl = ref.watch(crawlControllerProvider);
    final jobs = ref.watch(crawlJobsProvider);
    final datasets = ref.watch(datasetsProvider);
    final pages = ref.watch(capturedPagesProvider);
    final keyword = _keyword.text.trim();
    final suggestions = suggestStatSites(keyword, limit: 8);
    final selectedSites = statSites.where((s) => _selected.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: NColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoLabel('CRAWLER / STATISTICAL YEARBOOKS', color: NColors.lime),
                      const SizedBox(height: 7),
                      Text('统计年鉴爬虫', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text('关键词 → 站点 → 全站抓取表格；不用记网址。',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NColors.lime.withValues(alpha: 0.08),
                    border: Border.all(color: NColors.lime.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.radar, color: NColors.lime, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GlassCard(
              accent: NColors.cyan,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoLabel('KEYWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyword,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '例如：广东 GDP、全国 CPI、地方财政支出 2023',
                      prefixIcon: Icon(Icons.search, size: 18, color: NColors.muted),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '不填 URL 也可以：按关键词自动推荐年鉴/统计局/数据开放平台',
                          style: kMono.copyWith(fontSize: 8, height: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _aiLoading ? null : _aiSuggest,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NColors.violet.withValues(alpha: 0.3)),
                            color: NColors.violet.withValues(alpha: 0.06),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_aiLoading)
                                const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.4, color: NColors.violet))
                              else
                                const Icon(Icons.auto_awesome, size: 12, color: NColors.violet),
                              const SizedBox(width: 5),
                              const Text('AI 选站点', style: TextStyle(fontSize: 10, color: NColors.violet)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_aiNote != null && _aiNote!.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(_aiNote!, style: const TextStyle(fontSize: 10, color: NColors.muted, height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MonoLabel('SEED SITES'),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/sites'),
                        child: const Text('站点库', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (keyword.isEmpty)
                    Text('输入关键词后，这里会出现推荐站点；也可以直接去站点库勾选。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.5))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in [...selectedSites, ...suggestions.where((e) => !_selected.contains(e.id))].take(10))
                          _SiteChip(
                            site: s,
                            active: _selected.contains(s.id),
                            onTap: () => setState(() {
                              if (_selected.contains(s.id)) {
                                _selected.remove(s.id);
                              } else {
                                _selected.add(s.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '选中 ${_selected.length} 个站点；不选则自动使用上面推荐的站点。',
                    style: kMono.copyWith(fontSize: 8.5),
                  ),
                  const SizedBox(height: 11),
                  GestureDetector(
                    onTap: () => setState(() => _advanced = !_advanced),
                    child: Row(
                      children: [
                        Icon(_advanced ? Icons.expand_less : Icons.expand_more, size: 15, color: NColors.muted),
                        const SizedBox(width: 4),
                        const Text('高级：手填 URL / 年份范围', style: TextStyle(fontSize: 10.5, color: NColors.muted)),
                      ],
                    ),
                  ),
                  if (_advanced) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _seed,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: const InputDecoration(
                        hintText: '可选：种子 URL（多个用空格/换行分隔）',
                        prefixIcon: Icon(Icons.link, size: 16, color: NColors.muted),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(child: _YearPick(label: '起始年', value: _startYear, onChanged: (v) => setState(() => _startYear = v))),
                        const SizedBox(width: 8),
                        Expanded(child: _YearPick(label: '结束年', value: _endYear, onChanged: (v) => setState(() => _endYear = v))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('年份只过滤已识别年份列的数据集；不选则保留全部。',
                        style: kMono.copyWith(fontSize: 8)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '每任务最多 ${settings.crawlMaxPages} 页 · 深度 ${settings.crawlMaxDepth}',
                          style: kMono.copyWith(fontSize: 8.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/crawler-settings'),
                        child: const Text('设置', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: crawl.running ? '爬取中…' : '开始爬取',
                      icon: Icons.play_arrow_rounded,
                      loading: crawl.running,
                      onTap: crawl.running ? null : _start,
                    ),
                  ),
                ],
              ),
            ),
            if (crawl.jobId != null) ...[
              const SizedBox(height: 12),
              _ProgressCard(state: crawl, onCancel: () => ref.read(crawlControllerProvider.notifier).cancel()),
            ],
            const SizedBox(height: 20),
            SectionHeader(
              kicker: 'JOBS',
              title: '爬取任务',
              trailing: Row(
                children: [
                  if (_jobManage && _jobSelected.isNotEmpty)
                    GestureDetector(
                      onTap: _deleteJobs,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text('删除 ${_jobSelected.length}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8))),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _jobManage = !_jobManage;
                      if (!_jobManage) _jobSelected.clear();
                    }),
                    child: Text(_jobManage ? '完成' : '批量',
                        style: TextStyle(fontSize: 10.5, color: _jobManage ? NColors.lime : NColors.cyan)),
                  ),
                ],
              ),
            ),
            jobs.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: NColors.lime)),
              ),
              error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.travel_explore,
                    title: '还没有爬取任务',
                    subtitle: '填一个关键词开始；例如「广东 GDP」会自动指向广东统计年鉴和数据开放平台。',
                  );
                }
                return Column(children: [
                  for (final j in list.take(8))
                    _JobCard(
                      job: j,
                      manage: _jobManage,
                      checked: _jobSelected.contains(j.id),
                      onTap: _jobManage
                          ? () => setState(() {
                                if (_jobSelected.contains(j.id)) {
                                  _jobSelected.remove(j.id);
                                } else {
                                  _jobSelected.add(j.id);
                                }
                              })
                          : null,
                    ),
                ]);
              },
            ),
            const SizedBox(height: 18),
            SectionHeader(
              kicker: 'RECENT PAGES',
              title: '最近抓到的页面',
              trailing: GestureDetector(
                onTap: () => context.push('/datasets'),
                child: const Text('全部', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
              ),
            ),
            pages.when(
              loading: () => const SizedBox(height: 20),
              error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
              data: (list) {
                if (list.isEmpty) {
                  return Text('每个爬到的页面都会进这里，哪怕没有表格。', style: Theme.of(context).textTheme.bodySmall);
                }
                return Column(children: [
                  for (final p in list.take(4))
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      onTap: () => context.push('/page/${p.id}'),
                      child: Row(
                        children: [
                          Icon(
                            p.matched ? Icons.article : Icons.article_outlined,
                            size: 17,
                            color: p.matched ? NColors.lime : NColors.muted,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title.isEmpty ? p.url : p.title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${p.domain} · ${p.status} · ${p.tableCount} 表',
                                    style: kMono.copyWith(fontSize: 8)),
                                if (p.excerpt.isNotEmpty)
                                  Text(p.excerpt, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9, color: NColors.muted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: NColors.muted),
                        ],
                      ),
                    ),
                ]);
              },
            ),
            const SizedBox(height: 18),
            SectionHeader(
              kicker: 'RECENT DATASETS',
              title: '最近抓到的表',
              trailing: GestureDetector(
                onTap: () => context.push('/datasets'),
                child: const Text('全部', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
              ),
            ),
            datasets.when(
              loading: () => const SizedBox(height: 20),
              error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
              data: (list) {
                if (list.isEmpty) {
                  return Text('抓到的统计表会出现在这里。', style: Theme.of(context).textTheme.bodySmall);
                }
                return Column(children: [
                  for (final d in list.take(3))
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      onTap: () => context.push('/dataset/${d.id}'),
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart_outlined, size: 18, color: NColors.lime),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${d.rowCount} 行 · ${d.sourceName}', style: kMono.copyWith(fontSize: 8)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16, color: NColors.muted),
                        ],
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteChip extends StatelessWidget {
  final StatSite site;
  final bool active;
  final VoidCallback onTap;

  const _SiteChip({required this.site, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? NColors.cyan.withValues(alpha: 0.13) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? NColors.cyan.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Text(
          site.name,
          style: TextStyle(fontSize: 10.5, color: active ? NColors.cyan : NColors.muted),
        ),
      ),
    );
  }
}

class _YearPick extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _YearPick({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      dropdownColor: NColors.surface,
      style: const TextStyle(fontSize: 11, color: NColors.text),
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('不限')),
        for (var y = 1990; y <= now; y++)
          DropdownMenuItem<int?>(value: y, child: Text('$y')),
      ],
      onChanged: onChanged,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final CrawlState state;
  final VoidCallback onCancel;

  const _ProgressCard({required this.state, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final running = state.running;
    return GlassCard(
      accent: running ? NColors.cyan : NColors.lime,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (running)
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: NColors.cyan))
              else
                const Icon(Icons.check_circle, size: 15, color: NColors.lime),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  running ? '正在爬取 · ${state.current}' : '任务结束',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: NColors.text),
                ),
              ),
              if (running)
                GestureDetector(
                  onTap: onCancel,
                  child: const Text('停止', style: TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8))),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _mini('已爬', '${state.pages}')),
              Expanded(child: _mini('入库页', '${state.pagesSaved}')),
              Expanded(child: _mini('表格', '${state.tables}')),
              Expanded(child: _mini('数据集', '${state.datasets}')),
            ],
          ),
          if (state.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${state.errors.length} 条失败/跳过：${state.errors.first}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Color(0xFFFF9AA8), height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 16, fontWeight: FontWeight.w700, color: NColors.cyan)),
        Text(label, style: kMono.copyWith(fontSize: 8)),
      ],
    );
  }
}

class _JobCard extends ConsumerWidget {
  final CrawlJob job;
  final bool manage;
  final bool checked;
  final VoidCallback? onTap;

  const _JobCard({required this.job, this.manage = false, this.checked = false, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = job.status == 'done'
        ? NColors.lime
        : job.status == 'failed'
            ? NColors.pink
            : job.status == 'cancelled'
                ? NColors.amber
                : NColors.cyan;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      accent: color,
      onTap: onTap,
      child: Row(
        children: [
          if (manage)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: checked ? NColors.cyan : Colors.white24),
            )
          else
            Container(width: 6, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.keyword, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${job.pages} 页 · 存 ${job.pagesSaved} 页 · ${job.tablesFound} 表 · ${job.datasetsSaved} 数据集 · ${job.status}',
                    style: kMono.copyWith(fontSize: 8)),
              ],
            ),
          ),
          if (!manage)
            GestureDetector(
              onTap: () => ref.read(crawlControllerProvider.notifier).deleteJob(job.id),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.delete_outline, size: 16, color: NColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
