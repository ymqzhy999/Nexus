import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class DocumentPage extends ConsumerStatefulWidget {
  final int documentId;

  const DocumentPage({super.key, required this.documentId});

  @override
  ConsumerState<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends ConsumerState<DocumentPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(repositoryProvider).markRead(widget.documentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncDoc = ref.watch(documentProvider(widget.documentId));
    final queue = ref.watch(aiQueueProvider);
    return Scaffold(
      backgroundColor: NColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: asyncDoc.valueOrNull == null
            ? null
            : [
                IconButton(
                  icon: Icon(
                    asyncDoc.valueOrNull!.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: asyncDoc.valueOrNull!.isBookmarked ? NColors.amber : NColors.text,
                  ),
                  onPressed: () async {
                    await ref.read(repositoryProvider).toggleBookmark(asyncDoc.valueOrNull!);
                    ref.invalidate(documentProvider(widget.documentId));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () => _confirmDelete(context, ref, asyncDoc.valueOrNull!),
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: NexusBackground(
        child: asyncDoc.when(
          loading: () => const Center(child: CircularProgressIndicator(color: NColors.cyan)),
          error: (e, _) => Center(child: Text('读取失败：$e', style: const TextStyle(color: NColors.muted))),
          data: (doc) {
            if (doc == null) {
              return const Center(child: Text('这条情报不存在', style: TextStyle(color: NColors.muted)));
            }
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                if (doc.imageUrl.isNotEmpty)
                  _HeroImage(url: doc.imageUrl)
                else
                  const SizedBox(height: 92),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.paddingOf(context).bottom + 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NeonChip(
                            label: doc.category,
                            color: categoryColor(doc.category),
                            icon: categoryIcon(doc.category),
                            dense: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            scoreLabel(doc.valueScore),
                            style: kMono.copyWith(fontSize: 9, color: categoryColor(doc.category)),
                          ),
                          const Spacer(),
                          ValueRing(score: doc.valueScore, size: 40),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        doc.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Meta(icon: Icons.link, text: sourceHost(doc.url)),
                          if (doc.author.isNotEmpty) _Meta(icon: Icons.person_outline, text: doc.author),
                          _Meta(
                            icon: Icons.schedule,
                            text: fullDate(doc.publishedAt ?? doc.createdAt),
                          ),
                          _Meta(icon: Icons.timer_outlined, text: '${doc.readingMinutes} 分钟'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ActionButton(
                            icon: Icons.article_outlined,
                            label: '原文',
                            onTap: () => context.push(
                              '/reader?url=${Uri.encodeComponent(doc.url)}'
                              '&title=${Uri.encodeComponent(doc.title)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.auto_awesome,
                            label: doc.aiStatus == 'done' ? '重新分析' : 'AI 分析',
                            accent: NColors.violet,
                            loading: queue.running,
                            onTap: () => _analyze(context, ref, doc),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.share_outlined,
                            label: '分享',
                            onTap: () => _showShare(context, doc),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _AiPanel(doc: doc, onAnalyze: () => _analyze(context, ref, doc), busy: queue.running),
                      const SizedBox(height: 18),
                      SectionHeader(
                        kicker: 'SOURCE TEXT',
                        title: '原文内容',
                        trailing: MonoLabel('${doc.wordCount} 字'),
                      ),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: _ExpandableText(text: doc.content),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.hub_outlined, size: 14, color: NColors.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '本地存储 · 原始内容与 AI 结果分开保存 · ${doc.aiModel.isEmpty ? '未使用模型' : doc.aiModel}',
                              style: kMono.copyWith(fontSize: 8.5, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _analyze(BuildContext context, WidgetRef ref, Document doc) async {
    await ref.read(aiQueueProvider.notifier).runOne(doc.id);
    ref.invalidate(documentProvider(widget.documentId));
    final err = ref.read(aiQueueProvider).error;
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _showShare(BuildContext context, Document doc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: NColors.cyan),
              title: const Text('复制标题与链接'),
              onTap: () {
                _copy(context, '${doc.title}\n${doc.url}');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notes, color: NColors.violet),
              title: const Text('复制 AI 摘要'),
              onTap: () {
                _copy(context, doc.summary);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('删除这条情报？'),
        content: const Text('原始内容和 AI 结果都会从本地删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFFF8A9A))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repositoryProvider).deleteDocument(doc.id);
      if (context.mounted) context.pop();
    }
  }
}

class _HeroImage extends StatelessWidget {
  final String url;

  const _HeroImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const ColoredBox(
              color: NColors.bg2,
              child: Center(child: Icon(Icons.image_not_supported_outlined, color: NColors.muted)),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC04060C), Color(0x0004060C), NColors.bg],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: NColors.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kMono.copyWith(fontSize: 8.5, letterSpacing: 0.3),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color accent;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
    this.accent = NColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: accent),
              )
            else
              Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AiPanel extends StatelessWidget {
  final Document doc;
  final VoidCallback onAnalyze;
  final bool busy;

  const _AiPanel({required this.doc, required this.onAnalyze, required this.busy});

  @override
  Widget build(BuildContext context) {
    if (doc.aiStatus == 'done') {
      final points = _decodeList(doc.keyPointsJson);
      final entities = _decodeEntities(doc.entitiesJson);
      final tags = decodeTags(doc.tagsJson);
      return GlassCard(
        accent: NColors.cyan,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 15, color: NColors.cyan),
                const SizedBox(width: 7),
                const MonoLabel('AI INTELLIGENCE', color: NColors.cyan),
                const Spacer(),
                MonoLabel('${doc.aiModel} · ${scoreLabel(doc.valueScore)}'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              doc.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    height: 1.75,
                    color: const Color(0xFFDCE7F5),
                  ),
            ),
            if (doc.whyValuable.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NColors.cyan.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NColors.cyan.withValues(alpha: 0.13)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: NColors.lime),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.whyValuable,
                        style: const TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFFC9F7FF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (points.isNotEmpty) ...[
              const SizedBox(height: 18),
              const MonoLabel('KEY SIGNALS'),
              const SizedBox(height: 10),
              for (var i = 0; i < points.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(i + 1).toString().padLeft(2, '0')}',
                        style: kMono.copyWith(fontSize: 9, color: NColors.cyan.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          points[i],
                          style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFFC7D3E4)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (entities.isNotEmpty) ...[
              const SizedBox(height: 12),
              const MonoLabel('ENTITIES'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in entities.take(12))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: NColors.violet.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(6),
                        color: NColors.violet.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        '${e.name} · ${e.type}',
                        style: const TextStyle(fontSize: 10, color: NColors.violet),
                      ),
                    ),
                ],
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final t in tags)
                    Text('#$t', style: const TextStyle(fontSize: 10.5, color: NColors.muted)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: doc.valueScore / 100,
                minHeight: 3,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(NColors.cyan),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('价值密度 ${doc.valueScore}/100', style: kMono.copyWith(fontSize: 8.5)),
                const Spacer(),
                Text(
                  '${_contentTypeLabel(doc.contentType)} · ${_sentimentLabel(doc.sentiment)}',
                  style: kMono.copyWith(fontSize: 8.5),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (doc.aiStatus == 'error') {
      return GlassCard(
        accent: NColors.pink,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: NColors.pink),
              const SizedBox(width: 7),
              const MonoLabel('AI ANALYSIS FAILED', color: NColors.pink),
            ]),
            const SizedBox(height: 9),
            Text(doc.aiError, style: const TextStyle(fontSize: 12, color: Color(0xFFFFB3BE), height: 1.5)),
            const SizedBox(height: 12),
            NeonButton(label: '重试分析', icon: Icons.refresh, loading: busy, onTap: onAnalyze, color: NColors.pink),
          ],
        ),
      );
    }
    return GlassCard(
      accent: NColors.violet,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: NColors.violet),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('这条情报还没有 AI 结构化结果', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  '生成摘要、分类、标签、实体与价值评分。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeonButton(label: '分析', color: NColors.violet, loading: busy, onTap: onAnalyze),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const Text('没有提取到正文，可打开原文查看。', style: TextStyle(color: NColors.muted, fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.text,
          maxLines: _open ? null : 12,
          style: const TextStyle(fontSize: 13.5, height: 1.85, color: Color(0xFFC7D3E4)),
        ),
        if (widget.text.length > 600)
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _open ? '收起' : '展开全文',
                    style: const TextStyle(color: NColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, size: 16, color: NColors.cyan),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

List<String> _decodeList(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  } catch (_) {}
  return const [];
}

List<AiEntity> _decodeEntities(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => AiEntity.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return const [];
}

String _sentimentLabel(String s) => switch (s) {
      'positive' => '积极',
      'negative' => '消极',
      _ => '中性',
    };

String _contentTypeLabel(String s) => switch (s) {
      'news' => '新闻',
      'analysis' => '分析',
      'tutorial' => '教程',
      'opinion' => '观点',
      'research' => '研究',
      'product' => '产品',
      _ => '其他',
    };
