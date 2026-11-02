import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ai/deepseek.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class AskPage extends ConsumerStatefulWidget {
  const AskPage({super.key});

  @override
  ConsumerState<AskPage> createState() => _AskPageState();
}

class _AskPageState extends ConsumerState<AskPage> {
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
        title: const Row(
          children: [
            Icon(Icons.forum_outlined, size: 17, color: NColors.violet),
            SizedBox(width: 8),
            Text('问知识库', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: NexusBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoLabel('ASK NEXUS / RETRIEVAL + DEEPSEEK', color: NColors.violet),
                    const SizedBox(height: 8),
                    Text('用你的本地情报回答问题', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      '先在本机 FTS5 检索，再把最相关的几篇交给 AI；回答带引用，不编造。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                  children: [
                    if (_answer.isEmpty && !_loading && _error == null) _Suggestions(onTap: _askSuggestion),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.8, color: NColors.violet)),
                            SizedBox(width: 10),
                            Text('Nexus 正在检索本地知识库并组织回答…', style: TextStyle(fontSize: 12, color: NColors.muted)),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B81).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFFFF6B81).withValues(alpha: 0.22)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB3BE), fontSize: 12, height: 1.6)),
                      ),
                    if (_answer.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                        ),
                        child: SelectableText(
                          _answer,
                          style: const TextStyle(fontSize: 14, height: 1.85, color: Color(0xFFDCE7F5)),
                        ),
                      ),
                      if (_sources.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const MonoLabel('SOURCES'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (var i = 0; i < _sources.length; i++)
                              GestureDetector(
                                onTap: () => context.push('/doc/${_sources[i].id}'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: NColors.cyan.withValues(alpha: 0.05),
                                    border: Border.all(color: NColors.cyan.withValues(alpha: 0.22)),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '[${i + 1}] ${truncate(_sources[i].title, 26)}',
                                    style: const TextStyle(fontSize: 10, color: NColors.cyan),
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
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                decoration: BoxDecoration(
                  color: NColors.surface.withValues(alpha: 0.98),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
                ),
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
      ),
    );
  }

  void _askSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _ask();
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

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _Suggestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      '今天有哪些值得关注的 AI 动态？',
      '最近关于 Agent 的观点有什么分歧？',
      '把最近的高价值情报归纳成三条主线',
      '有哪些值得跟进的公司或产品？',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MonoLabel('TRY ASKING'),
        const SizedBox(height: 9),
        for (final s in items)
          GestureDetector(
            onTap: () => onTap(s),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: NColors.violet),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: NColors.text))),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: NColors.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
