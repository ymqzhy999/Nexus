import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/database.dart';
import '../state/providers.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _controller = TextEditingController();
  SourceKind _mode = SourceKind.auto;

  static const _presets = [
    ('Hacker News', 'https://hnrss.org/frontpage', Icons.terminal),
    ('阮一峰周刊', 'https://www.ruanyifeng.com/blog/atom.xml', Icons.code),
    ('少数派', 'https://sspai.com/feed', Icons.apple),
    ('V2EX', 'https://www.v2ex.com/index.xml', Icons.forum_outlined),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider);
    final ingest = ref.watch(ingestProvider);

    return NexusBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoLabel('SOURCE LAB / PLUGIN ENGINE', color: NColors.cyan),
                      const SizedBox(height: 8),
                      Text('采集来源', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text('任意公开网页 · RSS · JSON API · Sitemap', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NColors.cyan.withValues(alpha: 0.08),
                    border: Border.all(color: NColors.cyan.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.add_link, color: NColors.cyan, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoLabel('TARGET URL'),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 13, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/feed.xml',
                      prefixIcon: const Icon(Icons.link, size: 17, color: NColors.muted),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste, size: 16, color: NColors.muted),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) _controller.text = data!.text!.trim();
                        },
                      ),
                    ),
                    onSubmitted: (_) => _start(),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final kind in const [
                          SourceKind.auto,
                          SourceKind.rss,
                          SourceKind.html,
                          SourceKind.jsonApi,
                          SourceKind.sitemap,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: _ModeChip(
                              label: kind.label,
                              active: _mode == kind,
                              onTap: () => setState(() => _mode = kind),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: ingest.running ? '采集中…' : '开始采集',
                      icon: Icons.radar,
                      loading: ingest.running,
                      onTap: ingest.running ? null : _start,
                    ),
                  ),
                  if (ingest.phase.isNotEmpty || ingest.error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          ingest.error != null ? Icons.error_outline : Icons.check_circle_outline,
                          size: 14,
                          color: ingest.error != null ? const Color(0xFFFF8A9A) : NColors.lime,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            ingest.error ?? ingest.phase,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: ingest.error != null ? const Color(0xFFFFB3BE) : NColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ingest.note != null && ingest.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(ingest.note!, style: kMono.copyWith(fontSize: 8.5, height: 1.6)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const MonoLabel('QUICK START'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  GestureDetector(
                    onTap: () {
                      _controller.text = p.$2;
                      _controller.selection = TextSelection.collapsed(offset: p.$2.length);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.$3, size: 13, color: NColors.violet),
                          const SizedBox(width: 6),
                          Text(p.$1, style: const TextStyle(fontSize: 11, color: NColors.text)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            SectionHeader(
              kicker: 'CONNECTED SOURCES',
              title: '已连接',
              trailing: GestureDetector(
                onTap: () => ref.read(ingestProvider.notifier).refreshAll(),
                child: const Row(
                  children: [
                    Icon(Icons.sync, size: 13, color: NColors.cyan),
                    SizedBox(width: 4),
                    Text('刷新全部', style: TextStyle(fontSize: 10.5, color: NColors.cyan)),
                  ],
                ),
              ),
            ),
            sources.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: NColors.cyan)),
              ),
              error: (e, _) => Text('读取来源失败：$e', style: const TextStyle(color: NColors.muted)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.rss_feed,
                    title: '还没有连接来源',
                    subtitle: '从一个 RSS 或任意网页开始。\n采集后可随时暂停、刷新或删除。',
                  );
                }
                return Column(
                  children: [for (final s in list) _SourceCard(source: s)],
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoLabel('ENGINE NOTES'),
                  const SizedBox(height: 8),
                  Text(
                    '• 手机端只抓取公开可访问页面，遇到 Cloudflare / 登录墙会显示具体失败原因。\n'
                    '• Sitemap 适合中小站点，移动端批量抓取较慢，默认最多 8 个页面。\n'
                    '• 站点风控、TLS 或 DNS 失败时，先检查系统 VPN / 代理设置。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7, fontSize: 10.5),
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
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(ingestProvider.notifier).addSource(url, hint: _mode);
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? NColors.violet.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? NColors.violet.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? NColors.violet : NColors.muted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends ConsumerWidget {
  final Source source;

  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = SourceKindX.parse(source.kind);
    final failed = source.lastStatus == 'failed';
    final color = failed ? NColors.pink : (source.enabled ? NColors.cyan : NColors.muted);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(kind.icon, size: 18, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      source.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(fontSize: 8.5, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${source.itemCount}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Text('条', style: TextStyle(fontSize: 8, color: NColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                failed
                    ? '失败'
                    : source.lastRunAt == null
                        ? '待运行'
                        : '${prettyDate(source.lastRunAt)} · ${kind.label}',
                style: kMono.copyWith(fontSize: 8.5),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(ingestProvider.notifier).refreshSource(source),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.refresh, size: 16, color: NColors.cyan),
                ),
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: source.enabled,
                  activeColor: NColors.cyan,
                  onChanged: (v) => ref.read(repositoryProvider).setSourceEnabled(source.id, v),
                ),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(context, ref, source),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline, size: 16, color: NColors.muted),
                ),
              ),
            ],
          ),
          if (failed && source.lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                source.lastError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFFFF9AA8), height: 1.45),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Source source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('删除来源？'),
        content: Text('「${source.name}」会被移除，已采集的情报会保留。'),
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
      await ref.read(repositoryProvider).deleteSource(source.id);
    }
  }
}
