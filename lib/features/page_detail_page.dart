import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class PageDetailPage extends ConsumerWidget {
  final int pageId;

  const PageDetailPage({super.key, required this.pageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(capturedPageProvider(pageId));
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => context.pop()),
        title: const Text('页面结果', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NColors.lime)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: NColors.muted))),
        data: (page) {
          if (page == null) return const Center(child: Text('页面不存在'));
          final attachments = _attachments(page.attachmentsJson);
          final datasets = ref.watch(datasetsProvider).valueOrNull ?? [];
          final pageTables = datasets.where((d) => d.sourceUrl == page.url).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 60),
            children: [
              Row(
                children: [
                  MonoLabel(page.matched ? 'MATCHED' : 'CAPTURED', color: page.matched ? NColors.lime : NColors.muted),
                  const Spacer(),
                  _statusChip(page.status),
                ],
              ),
              const SizedBox(height: 7),
              Text(page.title.isEmpty ? page.url : page.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () => _open(page.url),
                child: Text(page.url, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: NColors.cyan)),
              ),
              const SizedBox(height: 5),
              Text('${page.domain} · HTTP ${page.httpStatus} · ${page.tableCount} 张表 · ${page.text.length} 字符',
                  style: kMono.copyWith(fontSize: 8.5)),
              if (page.status == 'pdf') ...[
                const SizedBox(height: 10),
                GlassCard(accent: NColors.amber, padding: const EdgeInsets.all(12),
                    child: Text('这是一个 PDF 链接：当前只保存链接，不解析 PDF 表格。',
                        style: Theme.of(context).textTheme.bodySmall)),
              ],
              if (page.status.startsWith('http_')) ...[
                const SizedBox(height: 10),
                GlassCard(accent: NColors.pink, padding: const EdgeInsets.all(12),
                    child: Text('页面返回 ${page.status}：可能被反爬、需要登录或链接已失效。',
                        style: Theme.of(context).textTheme.bodySmall)),
              ],
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionHeader(kicker: 'ATTACHMENTS', title: '附件', trailing: MonoLabel('${attachments.length}')),
                for (final a in attachments)
                  GlassCard(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    onTap: () => _open(a['url'] ?? ''),
                    child: Row(
                      children: [
                        Icon(_attachmentIcon(a['type'] ?? ''), size: 16, color: NColors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['label'] ?? a['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              Text(a['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 8, color: NColors.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new, size: 13, color: NColors.muted),
                      ],
                    ),
                  ),
              ],
              if (pageTables.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionHeader(kicker: 'TABLES', title: '本页表格', trailing: MonoLabel('${pageTables.length}')),
                for (final d in pageTables)
                  GlassCard(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    onTap: () => context.push('/dataset/${d.id}'),
                    child: Row(
                      children: [
                        const Icon(Icons.table_chart_outlined, size: 16, color: NColors.lime),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                        Text('${d.rowCount} 行', style: kMono.copyWith(fontSize: 8)),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, size: 14, color: NColors.muted),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              SectionHeader(kicker: 'TEXT', title: '正文/数据摘要'),
              const SizedBox(height: 6),
              if (page.text.trim().isEmpty)
                Text('这个页面没有可提取的正文；可能是 PDF、表格下载或纯 JS 页面。',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: SelectableText(
                    page.text,
                    style: const TextStyle(fontSize: 11, height: 1.7, color: NColors.text),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'ok' || status == 'json' || status == 'xlsx'
        ? NColors.lime
        : status.startsWith('http_')
            ? NColors.pink
            : NColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(status, style: TextStyle(fontSize: 8.5, color: color)),
    );
  }

  List<Map<String, dynamic>> _attachments(String json) {
    try {
      final v = jsonDecode(json);
      if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return [];
  }

  IconData _attachmentIcon(String type) {
    if (type == 'pdf') return Icons.picture_as_pdf_outlined;
    if (type == 'xlsx' || type == 'xls') return Icons.grid_on;
    return Icons.attach_file;
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('删除这个页面？', style: TextStyle(fontSize: 15)),
        content: const Text('页面记录删除，已入库的表格保留。', style: TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(dbProvider);
    await (db.delete(db.capturedPages)..where((t) => t.id.equals(pageId))).go();
    if (context.mounted) context.pop();
  }
}
