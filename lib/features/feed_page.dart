import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(feedDocumentsProvider);
    final stats = ref.watch(statsProvider).valueOrNull ?? const AppStats();
    final filter = ref.watch(feedFilterProvider);
    final sort = ref.watch(feedSortProvider);
    final ingest = ref.watch(ingestProvider);
    final queue = ref.watch(aiQueueProvider);
    final briefing = ref.watch(briefingProvider);

    return NexusBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: NColors.cyan,
          backgroundColor: NColors.surface,
          onRefresh: () => ref.read(ingestProvider.notifier).refreshAll(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 18),
                      _StatsCard(stats: stats),
                      const SizedBox(height: 12),
                      _BriefingCard(state: briefing),
                      if (queue.running) ...[
                        const SizedBox(height: 12),
                        _QueueCard(state: queue),
                      ],
                      if (ingest.error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: ingest.error!),
                      ],
                      if (ingest.running) ...[
                        const SizedBox(height: 12),
                        _IngestCard(state: ingest),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final f in FeedFilter.values)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _FilterChip(
                                        label: f.label,
                                        active: filter == f,
                                        onTap: () => ref.read(feedFilterProvider.notifier).state = f,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _SortButton(
                            sort: sort,
                            onTap: () {
                              ref.read(feedSortProvider.notifier).state =
                                  sort == FeedSort.value ? FeedSort.latest : FeedSort.value;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SectionHeader(
                        kicker: 'INTELLIGENCE FEED',
                        title: '情报卡片',
                        trailing: MonoLabel('${docs.valueOrNull?.length ?? 0} ITEMS'),
                      ),
                    ],
                  ),
                ),
              ),
              docs.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: _SkeletonList(),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ErrorBanner(message: '读取本地数据库失败：$e'),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.radar,
                        title: '情报流还是空的',
                        subtitle: '添加一个 RSS、网页或 JSON API，\nNexus 会把内容抓回来并交给 AI 结构化。',
                        action: NeonButton(
                          label: '去发现来源',
                          icon: Icons.add,
                          onTap: () => context.go('/discover'),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => _DocumentCard(document: list[i]),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MonoLabel('NEXUS / LOCAL-FIRST', color: NColors.cyan),
                  const SizedBox(width: 8),
                  Container(width: 5, height: 5, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NColors.lime,
                    boxShadow: [BoxShadow(color: NColors.lime.withValues(alpha: 0.7), blurRadius: 8)],
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Text('情报流', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                '采集 · 理解 · 按价值密度沉淀',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const _StatusPill(),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: NColors.lime),
          SizedBox(width: 5),
          Text('LOCAL', style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
            letterSpacing: 1.2,
            color: NColors.lime,
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final AppStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final score = stats.avgScore.round();
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoLabel('SIGNAL DENSITY'),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 42,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: NColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text('/100', style: kMono),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('平均价值密度 · 越高越值得读', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              ValueRing(score: score, size: 66),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatTile(value: '${stats.documents}', label: '情报总数')),
              Expanded(child: StatTile(value: '${stats.highValue}', label: '高价值', color: NColors.lime)),
              Expanded(child: StatTile(value: '${stats.sources}', label: '来源', color: NColors.violet)),
              Expanded(child: StatTile(value: '${stats.analyzed}', label: '已分析', color: NColors.amber)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BriefingCard extends ConsumerWidget {
  final BriefingState state;

  const _BriefingCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasText = state.text.trim().isNotEmpty;
    return GlassCard(
      accent: NColors.violet,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: NColors.violet),
              const SizedBox(width: 7),
              const MonoLabel('AI BRIEFING', color: NColors.violet),
              const Spacer(),
              if (state.loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: NColors.violet),
                )
              else
                GestureDetector(
                  onTap: () => ref.read(briefingProvider.notifier).generate(),
                  child: Icon(
                    hasText ? Icons.refresh : Icons.play_arrow_rounded,
                    size: 19,
                    color: NColors.violet,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.error != null)
            Text(state.error!, style: const TextStyle(color: Color(0xFFFF8A9A), fontSize: 12)),
          if (hasText) ...[
            Text(
              state.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '基于今日高价值情报生成',
                  style: kMono.copyWith(fontSize: 8.5),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showBriefing(context, state.text),
                  child: const Text(
                    '展开全文',
                    style: TextStyle(color: NColors.violet, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ] else if (!state.loading)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '把今天的高价值情报压缩成 30 秒可读的简报。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 10),
                NeonButton(
                  label: '生成',
                  color: NColors.violet,
                  onTap: () => ref.read(briefingProvider.notifier).generate(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void _showBriefing(BuildContext context, String text) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: NColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF1E2A3E))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(Icons.auto_awesome, color: NColors.violet, size: 18),
                SizedBox(width: 8),
                MonoLabel('AI BRIEFING / TODAY', color: NColors.violet),
              ]),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.8)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QueueCard extends StatelessWidget {
  final AiQueueState state;

  const _QueueCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = state.total == 0 ? 0.0 : state.done / state.total;
    return GlassCard(
      accent: NColors.amber,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: NColors.amber),
              ),
              const SizedBox(width: 9),
              Text('AI 正在结构化情报', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: NColors.amber)),
              const Spacer(),
              MonoLabel('${state.done}/${state.total}', color: NColors.amber),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 3,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(NColors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngestCard extends StatelessWidget {
  final IngestState state;

  const _IngestCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: NColors.cyan,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: NColors.cyan),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(state.phase, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B81).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B81).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF8A9A)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFFFB3BE), fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? NColors.cyan.withValues(alpha: 0.13) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? NColors.cyan.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? NColors.cyan : NColors.muted,
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final FeedSort sort;
  final VoidCallback onTap;

  const _SortButton({required this.sort, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              sort == FeedSort.value ? Icons.local_fire_department_outlined : Icons.schedule,
              size: 13,
              color: NColors.violet,
            ),
            const SizedBox(width: 5),
            Text(
              sort == FeedSort.value ? '价值' : '最新',
              style: const TextStyle(fontSize: 11, color: NColors.violet, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  final Document document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = categoryColor(document.category);
    final tags = decodeTags(document.tagsJson);
    final summary = document.summary.isNotEmpty ? document.summary : document.excerpt;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      accent: color,
      padding: const EdgeInsets.all(15),
      onTap: () => context.push('/doc/${document.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueRing(score: document.valueScore, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        NeonChip(label: document.category, color: color, dense: true),
                        if (!document.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(color: NColors.cyan, shape: BoxShape.circle),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          prettyDate(document.publishedAt ?? document.createdAt),
                          style: kMono.copyWith(fontSize: 8.5, letterSpacing: 0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.trim().isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFAEBBCE),
                    height: 1.6,
                  ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags.take(4))
                  Text(
                    '#$t',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      color: color.withValues(alpha: 0.85),
                      letterSpacing: 0.2,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.link, size: 12, color: NColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sourceHost(document.url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kMono.copyWith(fontSize: 8.5),
                ),
              ),
              _AiBadge(status: document.aiStatus),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.read(repositoryProvider).toggleBookmark(document),
                child: Icon(
                  document.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 17,
                  color: document.isBookmarked ? NColors.amber : NColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  final String status;

  const _AiBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      'done' => ('AI', NColors.cyan),
      'error' => ('AI ERR', NColors.pink),
      _ => ('PENDING', NColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 7.5,
          letterSpacing: 0.8,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
      ],
    );
  }
}
