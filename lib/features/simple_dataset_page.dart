import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../analysis/metrics.dart';
import '../data/table_data.dart';
import '../export/exporters.dart';
import '../state/providers.dart';

class SimpleDatasetPage extends ConsumerStatefulWidget {
  final int datasetId;

  const SimpleDatasetPage({super.key, required this.datasetId});

  @override
  ConsumerState<SimpleDatasetPage> createState() => _SimpleDatasetPageState();
}

class _SimpleDatasetPageState extends ConsumerState<SimpleDatasetPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(datasetProvider(widget.datasetId));
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
        title: const Text('数据集', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _delete,
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NColors.lime)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: NColors.muted))),
        data: (record) {
          if (record == null) return const Center(child: Text('数据集不存在'));
          final table = TableData.fromRecord(record);
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 100),
            children: [
              const MonoLabel('DATASET / CRAWLED TABLE', color: NColors.lime),
              const SizedBox(height: 6),
              Text(record.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('${record.rowCount} 行 × ${record.columnCount} 列 · ${record.sourceName}',
                  style: kMono.copyWith(fontSize: 9)),
              if (record.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(record.sourceUrl);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(record.sourceUrl, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: NColors.cyan)),
                ),
              ],
              const SizedBox(height: 16),
              if (table.looksLikeIndex)
                GlassCard(
                  accent: NColors.amber,
                  padding: const EdgeInsets.all(12),
                  child: Text('这看起来是目录/年份导航表，不是数据表；建议删除后到具体章节重抓。',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              if (table.looksLikeIndex) const SizedBox(height: 12),
              SectionHeader(
                kicker: 'PREVIEW',
                title: '数据预览',
                trailing: MonoLabel('前 ${table.rows.length > 30 ? 30 : table.rows.length} 行'),
              ),
              const SizedBox(height: 8),
              _table(table),
              const SizedBox(height: 18),
              SectionHeader(kicker: 'EXPORT', title: '导出'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: NeonButton(label: 'Excel', icon: Icons.grid_on, onTap: _busy ? null : () => _export('xlsx'))),
                  const SizedBox(width: 8),
                  Expanded(child: NeonButton(label: 'PDF', icon: Icons.picture_as_pdf_outlined, onTap: _busy ? null : () => _export('pdf'))),
                  const SizedBox(width: 8),
                  Expanded(child: NeonButton(label: 'CSV', icon: Icons.text_snippet_outlined, onTap: _busy ? null : () => _export('csv'))),
                ],
              ),
              const SizedBox(height: 8),
              Text('保存到系统「下载」目录；失败会显示具体原因。', style: kMono.copyWith(fontSize: 8.5)),
            ],
          );
        },
      ),
    );
  }

  Widget _table(TableData table) {
    if (table.rows.isEmpty || table.headers.isEmpty) {
      return const EmptyState(icon: Icons.table_chart_outlined, title: '没有数据', subtitle: '这个表没有可预览的行列。');
    }
    final shown = table.rows.take(30).toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 38,
          columnSpacing: 18,
          headingTextStyle: const TextStyle(fontSize: 9.5, color: NColors.cyan, fontWeight: FontWeight.w600),
          dataTextStyle: const TextStyle(fontSize: 9.5, color: NColors.text),
          columns: [for (final h in table.headers) DataColumn(label: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis))],
          rows: [
            for (final r in shown)
              DataRow(cells: [
                for (var i = 0; i < table.headers.length; i++)
                  DataCell(Text(i < r.length ? r[i] : '', maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String kind) async {
    setState(() => _busy = true);
    try {
      final record = await ref.read(datasetProvider(widget.datasetId).future);
      if (record == null) throw Exception('数据集不存在');
      final table = TableData.fromRecord(record);
      final path = switch (kind) {
        'xlsx' => await DatasetExporter.saveExcel(table, <MetricResult>[], ''),
        'pdf' => await DatasetExporter.savePdf(table, <MetricResult>[], ''),
        _ => await DatasetExporter.saveCsv(table),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存：$path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('删除这个数据集？', style: TextStyle(fontSize: 15)),
        content: const Text('不可恢复。', style: TextStyle(fontSize: 11.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF9AA8)))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(datasetsRepositoryProvider).deleteDataset(widget.datasetId);
    if (mounted) context.pop();
  }
}
