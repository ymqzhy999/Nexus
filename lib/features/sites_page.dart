import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/stat_sites.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../state/providers.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  final _keyword = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  static const _categories = ['国家统计', '部委数据', '省级年鉴', '省级统计', '数据开放'];

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final list = statSites
        .where((s) => q.isEmpty || s.name.contains(q) || s.tags.any((t) => t.contains(q)) || s.category.contains(q))
        .toList();

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
                  const MonoLabel('SITE LIBRARY / GOVERNMENT DATA', color: NColors.cyan),
                  const SizedBox(height: 7),
                  Text('站点库', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text('统计年鉴、统计局、数据开放平台；勾选后填关键词直接开爬。',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '搜索站点/省份/类别…',
                      prefixIcon: Icon(Icons.search, size: 17, color: NColors.muted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('已选 ${_selected.length} 个', style: kMono.copyWith(fontSize: 9)),
                  const Spacer(),
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
                      style: const TextStyle(fontSize: 10.5, color: NColors.cyan),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  for (final cat in _categories)
                    if (list.any((s) => s.category == cat)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NColors.text)),
                      ),
                      for (final s in list.where((e) => e.category == cat))
                        GlassCard(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(11),
                          accent: _selected.contains(s.id) ? NColors.cyan : NColors.line,
                          onTap: () => setState(() {
                            if (_selected.contains(s.id)) {
                              _selected.remove(s.id);
                            } else {
                              _selected.add(s.id);
                            }
                          }),
                          child: Row(
                            children: [
                              Icon(
                                _selected.contains(s.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 18,
                                color: _selected.contains(s.id) ? NColors.cyan : Colors.white24,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(s.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: kMono.copyWith(fontSize: 8.5)),
                                    const SizedBox(height: 2),
                                    Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 8, color: NColors.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(14, 9, 14, MediaQuery.paddingOf(context).bottom + 92),
              decoration: BoxDecoration(
                color: NColors.surface,
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyword,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '关键词，例如：广东 GDP',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeonButton(
                    label: '爬取 ${_selected.length}',
                    icon: Icons.play_arrow_rounded,
                    onTap: _selected.isEmpty ? null : _start,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _start() {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先填关键词')));
      return;
    }
    final settings = ref.read(appSettingsProvider);
    final seeds = statSites.where((s) => _selected.contains(s.id)).map((s) => s.url).toList();
    unawaited(ref.read(crawlControllerProvider.notifier).start(
          keyword: keyword,
          seeds: seeds,
          maxPages: settings.crawlMaxPages,
          maxDepth: settings.crawlMaxDepth,
        ));
    context.go('/crawl');
  }
}
