import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ai/deepseek.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final docs = ref.watch(libraryDocsProvider);
    final categories = ref.watch(categoriesProvider);
    final stats = ref.watch(statsProvider).valueOrNull ?? const AppStats();

    return NexusBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: NColors.cyan,
          backgroundColor: NColors.surface,
          onRefresh: () async {
            ref.invalidate(libraryDocsProvider);
            ref.invalidate(categoriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MonoLabel('KNOWLEDGE BASE / FTS5', color: NColors.violet),
                        const SizedBox(height: 8),
                        Text('知识库', style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 4),
                        Text('全文检索 · 分类分布 · 基于本地语料的 AI 问答', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stats.documents}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: NColors.violet,
                        ),
                      ),
                      const MonoLabel('DOCS'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(12),
                accent: NColors.violet,
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: NColors.violet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '搜索标题、正文、AI 摘要…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (v) => ref.read(searchProvider.notifier).run(v),
                      ),
                    ),
                    if (search.query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: NColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      ),
                    GestureDetector(
                      onTap: () => ref.read(searchProvider.notifier).run(_searchController.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [NColors.cyan, NColors.violet]),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text('搜索', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF02121A))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AskCard(onTap: () => _openAsk(context)),
              const SizedBox(height: 18),
              if (search.query.isNotEmpty) ...[
                SectionHeader(
                  kicker: 'SEARCH RESULTS',
                  title: '"${search.query}"',
                  trailing: MonoLabel('${search.results.length} 命中', color: NColors.cyan),
                ),
                if (search.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator(color: NColors.cyan)),
                  )
                else if (search.error != null)
                  Text(search.error!, style: const TextStyle(color: Color(0xFFFF8A9A), fontSize: 12))
                else if (search.results.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off,
                    title: '没有找到相关内容',
                    subtitle: '试试更短的关键词，或换一个说法。',
                  )
                else
                  for (final d in search.results) _ResultTile(document: d),
              ] else ...[
                SectionHeader(kicker: 'DISTRIBUTION', title: '知识分布'),
                categories.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: NColors.violet)),
                  ),
                  error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: Icons.donut_large,
                          title: '还没有分类数据',
                          subtitle: '采集内容并完成 AI 分析后，这里会出现知识分布。',
                        )
                      : _CategoryCard(list: list),
                ),
                const SizedBox(height: 22),
                SectionHeader(
                  kicker: 'RECENT DOCUMENTS',
                  title: '最近沉淀',
                  trailing: MonoLabel('${docs.valueOrNull?.length ?? 0} 条'),
                ),
                docs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator(color: NColors.cyan)),
                  ),
                  error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted)),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: Icons.library_books_outlined,
                          title: '知识库是空的',
                          subtitle: '在「发现」里添加来源，采集后会自动进入这里。',
                        )
                      : Column(children: [for (final d in list.take(30)) _ResultTile(document: d)]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openAsk(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => const _AskSheet(),
    );
  }
}

class _AskCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AskCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              NColors.violet.withValues(alpha: 0.16),
              NColors.cyan.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: NColors.violet.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NColors.violet.withValues(alpha: 0.15),
                border: Border.all(color: NColors.violet.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.forum_outlined, color: NColors.violet, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('问问你的知识库', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    'AI 会检索本地情报，带引用回答。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: NColors.violet),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final List<CategoryStat> list;

  const _CategoryCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final max = list.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            Padding(
              padding: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      list[i].category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: NColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: list[i].count / max,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation(categoryColor(list[i].category)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${list[i].count}',
                      textAlign: TextAlign.right,
                      style: kMono.copyWith(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Document document;

  const _ResultTile({required this.document});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(document.category);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      accent: color,
      onTap: () => context.push('/doc/${document.id}'),
      child: Row(
        children: [
          ValueRing(score: document.valueScore, size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(document.category, style: TextStyle(fontSize: 9, color: color)),
                    const SizedBox(width: 6),
                    Text('·', style: kMono.copyWith(fontSize: 8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prettyDate(document.createdAt),
                        style: kMono.copyWith(fontSize: 8, letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AskSheet extends ConsumerStatefulWidget {
  const _AskSheet();

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String _answer = '';
  String? _error;
  List<Document> _sources = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height - bottom) * 0.88;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, size: 17, color: NColors.violet),
                  SizedBox(width: 8),
                  MonoLabel('ASK NEXUS / RAG', color: NColors.violet),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_answer.isEmpty && !_loading && _error == null)
                      Text(
                        '例如：今天有哪些值得关注的 AI 动态？\n最近关于 Agent 的观点有什么分歧？',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.8),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.8, color: NColors.violet)),
                            SizedBox(width: 10),
                            Text('Nexus 正在检索本地知识库…', style: TextStyle(fontSize: 12, color: NColors.muted)),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B81).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB3BE), fontSize: 12, height: 1.5)),
                      ),
                    if (_answer.isNotEmpty) ...[
                      SelectableText(
                        _answer,
                        style: const TextStyle(fontSize: 13.5, height: 1.85, color: Color(0xFFDCE7F5)),
                      ),
                      if (_sources.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const MonoLabel('SOURCES'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < _sources.length; i++)
                              GestureDetector(
                                onTap: () {
                                  final id = _sources[i].id;
                                  final router = GoRouter.of(context);
                                  Navigator.pop(context);
                                  router.push('/doc/$id');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: NColors.cyan.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '[${i + 1}] ${truncate(_sources[i].title, 24)}',
                                    style: const TextStyle(fontSize: 9.5, color: NColors.cyan),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1B2638)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '向你的知识库提问…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      onSubmitted: (_) => _ask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loading ? null : _ask,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [NColors.cyan, NColors.violet]),
                      ),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF02121A)),
                            )
                          : const Icon(Icons.arrow_upward, size: 19, color: Color(0xFF02121A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _answer = '';
      _error = null;
      _sources = const [];
    });
    try {
      final settings = ref.read(appSettingsProvider);
      if (!settings.hasKey) throw '先在设置中填写 DeepSeek API Key';
      final repo = ref.read(repositoryProvider);
      var docs = await repo.search(q);
      if (docs.isEmpty) docs = await repo.topDocuments(limit: 6);
      if (docs.isEmpty) throw '知识库为空，先采集一些内容再提问';
      final contexts = docs
          .take(6)
          .map((d) => AiContext(title: d.title, url: d.url, summary: d.summary, content: d.content))
          .toList();
      final answer = await ref.read(deepSeekClientProvider).ask(
            question: q,
            contexts: contexts,
            language: settings.outputLanguage,
          );
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _sources = docs.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
}
