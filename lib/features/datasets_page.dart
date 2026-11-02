import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../data/table_data.dart';
import '../state/providers.dart';

class DatasetsPage extends ConsumerStatefulWidget {
  const DatasetsPage({super.key});

  @override
  ConsumerState<DatasetsPage> createState() => _DatasetsPageState();
}

class _DatasetsPageState extends ConsumerState<DatasetsPage> {
  final Set<int> _selected = {};
  bool _manage = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final datasets = ref.watch(datasetsProvider);
    return Scaffold(
      backgroundColor: NColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: MonoLabel('DATASETS / CRAWLED TABLES', color: NColors.lime)),
                      GestureDetector(
                        onTap: () => setState(() {
                          _manage = !_manage;
                          if (!_manage) _selected.clear();
                        }),
                        child: Text(_manage ? '完成' : '批量删除',
                            style: TextStyle(fontSize: 11, color: _manage ? NColors.lime : NColors.cyan)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text('数据集', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text('爬虫抓到的统计表；勾选可批量删除，点开可预览/导出。',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '搜索表名/来源…',
                      prefixIcon: Icon(Icons.search, size: 17, color: NColors.muted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (_manage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('已选 ${_selected.length}', style: kMono.copyWith(fontSize: 9)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final list = _filtered(datasets.valueOrNull ?? []);
                        setState(() {
                          if (list.every((d) => _selected.contains(d.id))) {
                            _selected.clear();
                          } else {
                            _selected.addAll(list.map((d) => d.id));
                          }
                        });
                      },
                      child: const Text('全选', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
                    ),
                    TextButton(
                      onPressed: _selected.isEmpty ? null : _deleteSelected,
                      child: Text('删除 ${_selected.length}', style: const TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8))),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: datasets.when(
                loading: () => const Center(child: CircularProgressIndicator(color: NColors.lime)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: NColors.muted))),
                data: (list) {
                  final filtered = _filtered(list);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.table_chart_outlined,
                      title: '还没有数据集',
                      subtitle: '回「采集」填关键词；爬虫会把识别到的统计表自动存进来。',
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 100),
                    children: [
                      for (final d in filtered) _card(d),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Dataset> _filtered(List<Dataset> list) {
    final q = _query.trim();
    if (q.isEmpty) return list;
    return list.where((d) => d.name.contains(q) || d.sourceName.contains(q)).toList();
  }

  Widget _card(Dataset d) {
    final checked = _selected.contains(d.id);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      accent: checked ? NColors.cyan : NColors.line,
      onTap: () {
        if (_manage) {
          setState(() {
            if (checked) {
              _selected.remove(d.id);
            } else {
              _selected.add(d.id);
            }
          });
        } else {
          context.push('/dataset/${d.id}');
        }
      },
      child: Row(
        children: [
          if (_manage)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: checked ? NColors.cyan : Colors.white24),
            )
          else
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 9),
              decoration: BoxDecoration(
                color: NColors.lime.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_chart_outlined, size: 17, color: NColors.lime),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${d.rowCount} 行 × ${d.columnCount} 列 · ${d.sourceName}',
                    style: kMono.copyWith(fontSize: 8.5)),
                if (d.sourceUrl.isNotEmpty)
                  Text(d.sourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8, color: NColors.muted)),
              ],
            ),
          ),
          if (!_manage) const Icon(Icons.chevron_right, size: 16, color: NColors.muted),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: Text('删除 ${ids.length} 个数据集？', style: const TextStyle(fontSize: 15)),
        content: const Text('原始表会从本地删除，不可恢复。', style: TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(datasetsRepositoryProvider).deleteDatasets(ids);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _manage = false;
    });
  }
}
