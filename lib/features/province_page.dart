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
        title: const Text('省份统计年鉴', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: NexusBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoLabel('PROVINCIAL YEARBOOKS', color: NColors.amber),
                    const SizedBox(height: 6),
                    Text(
                      '打开统计局 → 找“统计年鉴/统计数据” → 进入含年份的表格页 → 点右上角「抓表格」，Nexus 会自动识别表格并入库。',
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
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      accent: NColors.amber,
                      onTap: () => context.push(
                        '/data-browser?url=${Uri.encodeComponent(p.url)}&title=${Uri.encodeComponent(p.name)}',
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: NColors.amber.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.account_balance_outlined, size: 16, color: NColors.amber),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(p.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: kMono.copyWith(fontSize: 8)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 17, color: NColors.muted),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
