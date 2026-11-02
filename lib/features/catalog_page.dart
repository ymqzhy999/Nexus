import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/catalog.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../state/providers.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final Set<String> _selected = {};
  final TextEditingController _keyword = TextEditingController();
  String _query = '';
  CatalogCategory? _category;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  List<CatalogSource> get _filtered {
    final q = _query.trim().toLowerCase();
    return catalogSources.where((s) {
      if (_category != null && s.category != _category) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.category.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(batchProvider);
    final list = _filtered;
    final selected = catalogSources.where((s) => _selected.contains(s.id)).toList();
    final keyword = _keyword.text.trim();
    final needsKeyword = selected.any((s) => s.keywordOnly) && keyword.isEmpty;

    return Scaffold(
      backgroundColor: NColors.bg,
      body: NexusBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MonoLabel('SOURCE DIRECTORY / CURATED', color: NColors.cyan),
                          const SizedBox(height: 6),
                          Text('精选来源库', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 3),
                          Text(
                            '${catalogSources.length} 个站点 · 勾选后填关键词即可批量采集',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '搜索站点、分类或描述…',
                    prefixIcon: Icon(Icons.search, size: 18, color: NColors.muted),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CatChip(
                      label: '全部',
                      color: NColors.cyan,
                      active: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in CatalogCategory.values)
                      _CatChip(
                        label: c.label,
                        color: c.color,
                        icon: c.icon,
                        active: _category == c,
                        onTap: () => setState(() => _category = _category == c ? null : c),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const MonoLabel('快速选择'),
                            const SizedBox(width: 8),
                            _PackChip(
                              label: 'AI 日报',
                              onTap: () => _applyPack(['hn', 'huggingface', 'qbitai', 'arxiv', 'decoder', 'googleai']),
                            ),
                            _PackChip(
                              label: '开发者',
                              onTap: () => _applyPack(['githubblog', 'lobsters', 'simon', 'ruanyf', 'v2ex', 'devto']),
                            ),
                            _PackChip(
                              label: '中文科技',
                              onTap: () => _applyPack(['qbitai', 'sspai', 'ifanr', 'v2ex', 'juejin', 'ruanyf']),
                            ),
                            _PackChip(
                              label: '国际视野',
                              onTap: () => _applyPack(['bbc', 'guardian', 'nyt', 'aljazeera', 'npr', 'verge']),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (list.every((s) => _selected.contains(s.id))) {
                            for (final s in list) {
                              _selected.remove(s.id);
                            }
                          } else {
                            for (final s in list) {
                              _selected.add(s.id);
                            }
                          }
                        });
                      },
                      child: Text(
                        list.every((s) => _selected.contains(s.id)) && list.isNotEmpty ? '取消全选' : '全选当前',
                        style: const TextStyle(fontSize: 11, color: NColors.cyan),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text('已选 ${_selected.length} 个 · 内容永久保存在本地', style: kMono.copyWith(fontSize: 8.5)),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(_selected.clear),
                        child: const Text('清空', style: TextStyle(fontSize: 11, color: NColors.muted)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: '没有匹配的来源',
                        subtitle: '换个关键词或分类试试。',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final active = _selected.contains(s.id);
                          return _CatalogTile(
                            source: s,
                            selected: active,
                            enabled: !batch.running,
                            onTap: () => setState(() {
                              if (active) {
                                _selected.remove(s.id);
                              } else {
                                _selected.add(s.id);
                              }
                            }),
                          );
                        },
                      ),
              ),
              _BottomPanel(
                batch: batch,
                selectedCount: selected.length,
                keyword: keyword,
                needsKeyword: needsKeyword,
                controller: _keyword,
                onChanged: () => setState(() {}),
                onRun: batch.running || selected.isEmpty
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        ref.read(batchProvider.notifier).run(sources: selected, keyword: keyword);
                      },
                onOpenFeed: () => context.go('/feed'),
                onClose: () => ref.read(batchProvider.notifier).reset(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyPack(List<String> ids) {
    setState(() {
      _selected
        ..clear()
        ..addAll(ids.where((id) => catalogSources.any((s) => s.id == id)));
    });
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: active ? color : NColors.muted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: active ? color : NColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PackChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: NColors.violet.withValues(alpha: 0.22)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 9.5, color: NColors.violet)),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final CatalogSource source;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CatalogTile({
    required this.source,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = source.category.color;
    final typeLabel = source.kind == SourceKind.rss || source.kind == SourceKind.atom
        ? 'RSS'
        : source.kind == SourceKind.jsonApi
            ? 'API'
            : source.kind == SourceKind.sitemap
                ? 'SITEMAP'
                : 'WEB';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      accent: selected ? color : NColors.line,
      onTap: enabled ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(source.category.icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (source.featured) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.star_rounded, size: 12, color: NColors.amber),
                    ],
                    const SizedBox(width: 6),
                    Text(typeLabel, style: kMono.copyWith(fontSize: 7.5)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  source.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(source.category.label, style: TextStyle(fontSize: 9, color: color)),
                    if (source.keywordCapable) ...[
                      const SizedBox(width: 7),
                      Text('可搜关键词', style: TextStyle(fontSize: 9, color: NColors.violet.withValues(alpha: 0.9))),
                    ],
                    if (source.keywordOnly) ...[
                      const SizedBox(width: 7),
                      const Text('需关键词', style: TextStyle(fontSize: 9, color: NColors.amber)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? color : Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final BatchState batch;
  final int selectedCount;
  final String keyword;
  final bool needsKeyword;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onRun;
  final VoidCallback onOpenFeed;
  final VoidCallback onClose;

  const _BottomPanel({
    required this.batch,
    required this.selectedCount,
    required this.keyword,
    required this.needsKeyword,
    required this.controller,
    required this.onChanged,
    required this.onRun,
    required this.onOpenFeed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom > 0 ? bottom + 6 : 10),
      decoration: BoxDecoration(
        color: NColors.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (batch.running) ...[
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: NColors.cyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '采集中 ${batch.done}/${batch.total} · ${batch.current}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: NColors.cyan),
                  ),
                ),
                Text('+${batch.added}', style: kMono.copyWith(fontSize: 9, color: NColors.lime)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: batch.progress,
                minHeight: 3,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(NColors.cyan),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (batch.finished && !batch.running) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: NColors.lime),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '采集完成 · 新增 ${batch.added} 条${batch.failed > 0 ? ' · ${batch.failed} 个失败' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: NColors.text),
                  ),
                ),
                GestureDetector(
                  onTap: onOpenFeed,
                  child: const Text('查看信息流', style: TextStyle(fontSize: 11, color: NColors.cyan, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                GestureDetector(onTap: onClose, child: const Icon(Icons.close, size: 15, color: NColors.muted)),
              ],
            ),
            if (batch.errors.isNotEmpty)
              GestureDetector(
                onTap: () => _showErrors(context),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${batch.errors.length} 个来源失败：${batch.errors.first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFFFF9AA8)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '关键词（可选，空格分隔多个词）',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              NeonButton(
                label: batch.running ? '采集中' : '采集 $selectedCount',
                icon: Icons.radar,
                loading: batch.running,
                onTap: onRun,
              ),
            ],
          ),
          if (needsKeyword)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选中的「关键词搜索」来源需要填写关键词；否则会被跳过。',
                  style: TextStyle(fontSize: 9.5, color: NColors.amber),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showErrors(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MonoLabel('BATCH REPORT / ERRORS', color: NColors.pink),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in batch.errors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text('• $e', style: const TextStyle(fontSize: 11, color: Color(0xFFFFB3BE), height: 1.45)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
