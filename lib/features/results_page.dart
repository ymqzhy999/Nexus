import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../data/table_data.dart';
import '../state/providers.dart';

class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _query = TextEditingController();
  final Set<int> _pageSel = {};
  final Set<int> _tableSel = {};
  bool _manage = false;

  @override
  void dispose() {
    _tabs.dispose();
    _query.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(capturedPagesProvider).valueOrNull ?? [];
    final tables = ref.watch(datasetsProvider).valueOrNull ?? [];
    final filteredPages = pages.where((p) {
      if (_q.isEmpty) return true;
      return p.title.toLowerCase().contains(_q) ||
          p.url.toLowerCase().contains(_q) ||
          p.excerpt.toLowerCase().contains(_q) ||
          p.keyword.toLowerCase().contains(_q);
    }).toList();
    final filteredTables = tables.where((d) {
      if (_q.isEmpty) return true;
      return d.name.toLowerCase().contains(_q) || d.sourceName.toLowerCase().contains(_q);
    }).toList();
    final attachments = _attachments(pages).where((a) {
      if (_q.isEmpty) return true;
      return a.label.toLowerCase().contains(_q) || a.url.toLowerCase().contains(_q);
    }).toList();

    return Scaffold(
      backgroundColor: NColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: MonoLabel('RESULTS / PAGES · TABLES · FILES', color: NColors.lime)),
                      GestureDetector(
                        onTap: () => setState(() {
                          _manage = !_manage;
                          _pageSel.clear();
                          _tableSel.clear();
                        }),
                        child: Text(_manage ? '完成' : '批量删除',
                            style: TextStyle(fontSize: 10.5, color: _manage ? NColors.lime : NColors.cyan)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('采集结果', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 3),
                  Text('页面正文、表格、附件都保留；默认显示全部页面。',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '搜索标题/URL/关键词…',
                      prefixIcon: Icon(Icons.search, size: 17, color: NColors.muted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (_manage) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('已选 ${_tabs.index == 1 ? _tableSel.length : _pageSel.length}',
                            style: kMono.copyWith(fontSize: 9)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_tabs.index == 1) {
                              if (filteredTables.every((d) => _tableSel.contains(d.id))) {
                                _tableSel.clear();
                              } else {
                                _tableSel.addAll(filteredTables.map((d) => d.id));
                              }
                            } else if (_tabs.index == 0) {
                              if (filteredPages.every((p) => _pageSel.contains(p.id))) {
                                _pageSel.clear();
                              } else {
                                _pageSel.addAll(filteredPages.map((p) => p.id));
                              }
                            }
                          }),
                          child: const Text('全选当前', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
                        ),
                        if (_tabs.index != 2)
                          TextButton(
                            onPressed: _deleteSelected,
                            child: Text('删除 ${_tabs.index == 1 ? _tableSel.length : _pageSel.length}',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8))),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              onTap: (_) => setState(() {}),
              indicatorColor: NColors.lime,
              labelColor: NColors.lime,
              unselectedLabelColor: NColors.muted,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: '页面 ${filteredPages.length}'),
                Tab(text: '表格 ${filteredTables.length}'),
                Tab(text: '附件 ${attachments.length}'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _pageList(filteredPages),
                  _tableList(filteredTables),
                  _attachmentList(attachments),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageList(List<CapturedPage> pages) {
    if (pages.isEmpty) {
      return const EmptyState(icon: Icons.article_outlined, title: '没有页面结果', subtitle: '回「采集」跑一个任务；每爬一页都会存进来。');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 100),
      children: [
        for (final p in pages) _pageCard(p),
      ],
    );
  }

  Widget _pageCard(CapturedPage p) {
    final checked = _pageSel.contains(p.id);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      accent: checked ? NColors.cyan : NColors.line,
      onTap: () {
        if (_manage) {
          setState(() {
            if (checked) {
              _pageSel.remove(p.id);
            } else {
              _pageSel.add(p.id);
            }
          });
        } else {
          context.push('/page/${p.id}');
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_manage)
            Padding(
              padding: const EdgeInsets.only(right: 9, top: 2),
              child: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: checked ? NColors.cyan : Colors.white24),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 9, top: 2),
              child: Icon(p.matched ? Icons.article : Icons.article_outlined,
                  size: 17, color: p.matched ? NColors.lime : NColors.muted),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title.isEmpty ? p.url : p.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${p.domain} · ${p.status} · ${p.tableCount} 表 · ${p.content.length} 字',
                    style: kMono.copyWith(fontSize: 8.5)),
                if (p.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(p.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, color: NColors.muted, height: 1.5)),
                ],
              ],
            ),
          ),
          if (!_manage) const Icon(Icons.chevron_right, size: 16, color: NColors.muted),
        ],
      ),
    );
  }

  Widget _tableList(List<Dataset> tables) {
    if (tables.isEmpty) {
      return const EmptyState(icon: Icons.table_chart_outlined, title: '没有表格', subtitle: '页面里的 HTML/XLSX/CSV 表会进这里；没有表也不影响页面结果。');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 100),
      children: [
        for (final d in tables) _tableCard(d),
      ],
    );
  }

  Widget _tableCard(Dataset d) {
    final checked = _tableSel.contains(d.id);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      accent: checked ? NColors.cyan : NColors.line,
      onTap: () {
        if (_manage) {
          setState(() {
            if (checked) {
              _tableSel.remove(d.id);
            } else {
              _tableSel.add(d.id);
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
              decoration: BoxDecoration(color: NColors.lime.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
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
              ],
            ),
          ),
          if (!_manage) const Icon(Icons.chevron_right, size: 16, color: NColors.muted),
        ],
      ),
    );
  }

  Widget _attachmentList(List<_Attachment> attachments) {
    if (attachments.isEmpty) {
      return const EmptyState(icon: Icons.attach_file, title: '没有附件', subtitle: '页面里的 XLSX/CSV/PDF 链接会汇总在这里。');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 100),
      children: [
        for (final a in attachments)
          GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            onTap: () async {
              final uri = Uri.tryParse(a.url);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Row(
              children: [
                Icon(a.type == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.grid_on,
                    size: 17, color: NColors.amber),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(a.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8.5, color: NColors.muted)),
                      const SizedBox(height: 2),
                      Text('来自：${a.pageTitle}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: kMono.copyWith(fontSize: 8)),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 13, color: NColors.muted),
              ],
            ),
          ),
      ],
    );
  }

  List<_Attachment> _attachments(List<CapturedPage> pages) {
    final out = <_Attachment>[];
    final seen = <String>{};
    for (final p in pages) {
      try {
        final v = jsonDecode(p.attachmentsJson);
        if (v is! List) continue;
        for (final e in v.whereType<Map>()) {
          final url = (e['url'] ?? '').toString();
          if (url.isEmpty || !seen.add(url)) continue;
          out.add(_Attachment(
            url: url,
            label: (e['label'] ?? url).toString(),
            type: (e['type'] ?? '').toString(),
            pageTitle: p.title.isEmpty ? p.url : p.title,
          ));
        }
      } catch (_) {}
    }
    return out;
  }

  Future<void> _deleteSelected() async {
    final isTable = _tabs.index == 1;
    final count = isTable ? _tableSel.length : _pageSel.length;
    if (count == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: Text('删除 $count 个${isTable ? '表格' : '页面'}？', style: const TextStyle(fontSize: 15)),
        content: Text(isTable ? '已入库表格会删除，页面结果保留。' : '页面记录会删除，已入库表格保留。',
            style: const TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    if (isTable) {
      await ref.read(datasetsRepositoryProvider).deleteDatasets(_tableSel.toList());
    } else {
      final db = ref.read(dbProvider);
      for (final id in _pageSel) {
        await (db.delete(db.capturedPages)..where((t) => t.id.equals(id))).go();
      }
    }
    if (!mounted) return;
    setState(() {
      _pageSel.clear();
      _tableSel.clear();
      _manage = false;
    });
  }
}

class _Attachment {
  final String url;
  final String label;
  final String type;
  final String pageTitle;

  const _Attachment({required this.url, required this.label, required this.type, required this.pageTitle});
}
