import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../catalog/data_sources.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class ProvincePage extends StatefulWidget {
  const ProvincePage({super.key});

  @override
  State<ProvincePage> createState() => _ProvincePageState();
}

class _ProvincePageState extends State<ProvincePage> {
  String _query = '';

  void _open(String url, String title) {
    context.push('/data-browser?url=${Uri.encodeComponent(url)}&title=${Uri.encodeComponent(title)}');
  }

  @override
  Widget build(BuildContext context) {
    final list = provinceSources
        .where((p) => _query.trim().isEmpty || p.name.contains(_query.trim()))
        .toList();
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
        title: const Text('统计年鉴 / 数据开放', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: NexusBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 30),
            children: [
              const MonoLabel('YEARBOOKS / OPEN DATA', color: NColors.amber),
              const SizedBox(height: 6),
              Text(
                '优先用「年鉴直达」；没有直达的省进统计局首页，找「统计年鉴」栏目。进入具体表格页后点右上角「抓表格」。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '搜索省份…',
                  prefixIcon: Icon(Icons.search, size: 17, color: NColors.muted),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                kicker: 'PROVINCIAL OPEN DATA',
                title: '省级数据开放平台',
                trailing: MonoLabel('${dataCenters.length} 个'),
              ),
              for (final d in dataCenters)
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  accent: NColors.violet,
                  onTap: () => _open(d.url, d.name),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: NColors.violet.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.dataset_outlined, size: 16, color: NColors.violet),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      const Icon(Icons.chevron_right, size: 17, color: NColors.muted),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SectionHeader(
                kicker: 'PROVINCIAL YEARBOOKS',
                title: '省份统计年鉴',
                trailing: MonoLabel('${provinceSources.length} 个入口'),
              ),
              for (final p in list)
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  accent: p.yearbook ? NColors.lime : NColors.amber,
                  onTap: () => _open(p.url, p.name),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: (p.yearbook ? NColors.lime : NColors.amber).withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          p.yearbook ? Icons.menu_book_outlined : Icons.account_balance_outlined,
                          size: 16,
                          color: p.yearbook ? NColors.lime : NColors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (p.yearbook ? NColors.lime : NColors.amber).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.yearbook ? '年鉴直达' : '统计局入口',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: p.yearbook ? NColors.lime : NColors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(p.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: kMono.copyWith(fontSize: 8)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 17, color: NColors.muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
