import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../state/providers.dart';

class CrawlerSettingsPage extends ConsumerStatefulWidget {
  const CrawlerSettingsPage({super.key});

  @override
  ConsumerState<CrawlerSettingsPage> createState() => _CrawlerSettingsPageState();
}

class _CrawlerSettingsPageState extends ConsumerState<CrawlerSettingsPage> {
  final _key = TextEditingController();

  @override
  void initState() {
    super.initState();
    _key.text = ref.read(appSettingsProvider).apiKey;
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    final datasets = ref.watch(datasetsProvider).valueOrNull ?? [];
    final jobs = ref.watch(crawlJobsProvider).valueOrNull ?? [];
    final pages = ref.watch(capturedPagesProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop()),
        title: const Text('爬虫设置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 100),
        children: [
          const MonoLabel('CRAWLER / SETTINGS', color: NColors.lime),
          const SizedBox(height: 6),
          Text('爬取范围', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('每任务最多页面', style: TextStyle(fontSize: 12))),
                  Text('${s.crawlMaxPages}', style: kMono.copyWith(fontSize: 12, color: NColors.lime)),
                ]),
                Slider(
                  value: s.crawlMaxPages.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  activeColor: NColors.lime,
                  onChanged: (v) => ref.read(settingsControllerProvider.notifier).setCrawlMaxPages(v.round()),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('站内深度', style: TextStyle(fontSize: 12))),
                  Text('${s.crawlMaxDepth}', style: kMono.copyWith(fontSize: 12, color: NColors.lime)),
                ]),
                Slider(
                  value: s.crawlMaxDepth.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  activeColor: NColors.lime,
                  onChanged: (v) => ref.read(settingsControllerProvider.notifier).setCrawlMaxDepth(v.round()),
                ),
                Text('深度 2 适合年鉴目录→章节→表格；越大越慢。',
                    style: kMono.copyWith(fontSize: 8.5, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('可选：AI 选站点', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key 只用于「AI 选站点」和可选字段辅助，不参与数据计算；不填也能用内置规则。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6)),
                const SizedBox(height: 10),
                TextField(
                  controller: _key,
                  obscureText: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(hintText: 'sk-…（可留空）'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    NeonButton(
                      label: '保存 Key',
                      icon: Icons.key,
                      onTap: () async {
                        await ref.read(settingsControllerProvider.notifier).setApiKey(_key.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    if (s.hasKey)
                      TextButton(
                        onPressed: () async {
                          _key.clear();
                          await ref.read(settingsControllerProvider.notifier).setApiKey('');
                        },
                        child: const Text('清除', style: TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('本地数据', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pages.length} 个页面 · ${datasets.length} 个表格 · ${jobs.length} 个任务', style: kMono.copyWith(fontSize: 10)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _clear(pages.length, datasets.length, jobs.length),
                  child: const Text('清空数据集与任务', style: TextStyle(fontSize: 11, color: Color(0xFFFF9AA8))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('PDF 年鉴、老式 .xls 暂不解析；抓取结果以表格/CSV/XLSX 为主。',
              style: kMono.copyWith(fontSize: 8.5, height: 1.5)),
        ],
      ),
    );
  }

  Future<void> _clear(int pages, int datasets, int jobs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('清空本地采集数据？', style: TextStyle(fontSize: 15)),
        content: Text('将删除 $pages 个页面、$datasets 个表格和 $jobs 个任务，不可恢复。', style: const TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(dbProvider);
    await db.delete(db.capturedPages).go();
    await db.delete(db.dataAnalyses).go();
    await db.delete(db.datasets).go();
    await db.delete(db.crawlJobs).go();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
    }
  }
}
