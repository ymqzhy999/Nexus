import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/background.dart';
import '../state/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _key;
  late final TextEditingController _proxy;
  late final TextEditingController _base;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _key = TextEditingController(text: s.apiKey);
    _proxy = TextEditingController(text: s.proxyUrl);
    _base = TextEditingController(text: s.baseUrl);
  }

  @override
  void dispose() {
    _key.dispose();
    _proxy.dispose();
    _base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    final stats = ref.watch(statsProvider).valueOrNull ?? const AppStats();
    final usage = ref.watch(usageProvider);

    return NexusBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const MonoLabel('SYSTEM / CONFIG', color: NColors.cyan),
            const SizedBox(height: 8),
            Text('系统设置', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text('密钥只保存在本机安全存储，不会上传。', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            _Section(
              kicker: 'MODEL PROVIDER',
              title: 'DeepSeek',
              icon: Icons.auto_awesome,
              accent: NColors.cyan,
              children: [
                const _FieldLabel('API KEY'),
                const SizedBox(height: 7),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 17),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.hasKey ? '已配置 · 加密存储' : '未配置，AI 功能不可用',
                        style: kMono.copyWith(fontSize: 8.5, color: s.hasKey ? NColors.lime : NColors.amber),
                      ),
                    ),
                    GestureDetector(
                      onTap: _saveProvider,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [NColors.cyan, NColors.violet]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('保存', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF02121A))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _FieldLabel('模型'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: s.model,
                  dropdownColor: NColors.surface,
                  icon: const Icon(Icons.expand_more, size: 18, color: NColors.muted),
                  style: const TextStyle(fontSize: 12.5, color: NColors.text, fontFamily: 'JetBrainsMono'),
                  items: const [
                    DropdownMenuItem(value: 'deepseek-chat', child: Text('deepseek-chat · V3 通用')),
                    DropdownMenuItem(value: 'deepseek-reasoner', child: Text('deepseek-reasoner · 深度推理')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(settingsControllerProvider.notifier).setModel(v);
                  },
                ),
                const SizedBox(height: 14),
                const _FieldLabel('BASE URL（可选）'),
                const SizedBox(height: 7),
                TextField(
                  controller: _base,
                  style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5),
                  decoration: const InputDecoration(hintText: 'https://api.deepseek.com'),
                  onSubmitted: (v) => ref.read(settingsControllerProvider.notifier).setBaseUrl(v),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('输出语言'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: s.outputLanguage,
                  dropdownColor: NColors.surface,
                  icon: const Icon(Icons.expand_more, size: 18, color: NColors.muted),
                  style: const TextStyle(fontSize: 12.5, color: NColors.text),
                  items: const [
                    DropdownMenuItem(value: '中文', child: Text('中文')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: '日本語', child: Text('日本語')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(settingsControllerProvider.notifier).setOutputLanguage(v);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  '分析使用 JSON 结构化输出，失败会自动重试一次。长文截断到 1.4 万字以控制成本。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              kicker: 'PIPELINE',
              title: '智能处理',
              icon: Icons.tune,
              accent: NColors.violet,
              children: [
                _ToggleRow(
                  title: '采集后自动分析',
                  subtitle: '新内容入库后自动调用 DeepSeek 结构化',
                  value: s.autoAnalyze,
                  onChanged: (v) => ref.read(settingsControllerProvider.notifier).setAutoAnalyze(v),
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  title: '每次采集条数上限',
                  value: s.maxItemsPerRun.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '${s.maxItemsPerRun} 条',
                  onChanged: (v) => ref.read(settingsControllerProvider.notifier).setMaxItems(v.round()),
                ),
                _SliderRow(
                  title: '每次 AI 分析上限',
                  value: s.maxAiPerRun.toDouble(),
                  min: 1,
                  max: 12,
                  divisions: 11,
                  label: '${s.maxAiPerRun} 篇',
                  onChanged: (v) => ref.read(settingsControllerProvider.notifier).setMaxAi(v.round()),
                ),
                Text(
                  '省钱策略：只分析新内容；正文 hash 不变不会重复调用；每次分析的 Token 用量会记账。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              kicker: 'NETWORK',
              title: '网络与代理',
              icon: Icons.lan_outlined,
              accent: NColors.lime,
              children: [
                _ToggleRow(
                  title: '使用 HTTP 代理',
                  subtitle: '手机开启 VPN 时通常不需要；仅在分流/局域网代理时填写',
                  value: s.proxyEnabled,
                  onChanged: (v) async {
                    await ref.read(settingsControllerProvider.notifier).setProxy(enabled: v);
                    _snack(v ? '代理已开启' : '代理已关闭');
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _proxy,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5),
                  decoration: const InputDecoration(hintText: 'http://192.168.1.10:7890'),
                  onSubmitted: (v) => ref.read(settingsControllerProvider.notifier).setProxy(url: v),
                ),
                const SizedBox(height: 8),
                Text(
                  '提示：DeepSeek 与多数海外站点在开启系统 VPN 后即可直连。抓取失败会显示 DNS / 403 / 超时等具体原因。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              kicker: 'BACKGROUND',
              title: '后台采集',
              icon: Icons.sync,
              accent: NColors.amber,
              children: [
                _ToggleRow(
                  title: '定时刷新来源',
                  subtitle: '约 30 分钟一次，受 Android 省电策略影响可能延后',
                  value: s.backgroundSync,
                  onChanged: (v) async {
                    await ref.read(settingsControllerProvider.notifier).setBackgroundSync(v);
                    try {
                      await BackgroundSync.configure(v);
                      _snack(v ? '后台任务已注册' : '后台任务已取消');
                    } catch (e) {
                      _snack('后台任务设置失败：$e');
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '后台只刷新来源，不自动调用 AI，避免在不知情时消耗 Token。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              kicker: 'TELEMETRY / LOCAL',
              title: '用量与数据',
              icon: Icons.data_usage,
              accent: NColors.cyan,
              children: [
                usage.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text('$e', style: const TextStyle(color: NColors.muted, fontSize: 11)),
                  data: (u) => Row(
                    children: [
                      Expanded(child: StatTile(value: '${u.calls}', label: 'AI 调用')),
                      Expanded(child: StatTile(value: '${u.inputTokens}', label: '输入 Token', color: NColors.violet)),
                      Expanded(child: StatTile(value: '${u.outputTokens}', label: '输出 Token', color: NColors.amber)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: StatTile(value: '${stats.documents}', label: '本地情报')),
                    Expanded(child: StatTile(value: '${stats.sources}', label: '来源', color: NColors.violet)),
                    Expanded(child: StatTile(value: '${stats.highValue}', label: '高价值', color: NColors.lime)),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _confirmWipe,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B81).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF6B81).withValues(alpha: 0.22)),
                    ),
                    child: const Text(
                      '清空全部本地数据',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFFF8A9A), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  const MonoLabel('NEXUS 0.1.0 · LOCAL-FIRST'),
                  const SizedBox(height: 6),
                  Text(
                    'Flutter · Drift + SQLite FTS5 · DeepSeek\n原始内容与 AI 结果分离存储 · 可扩展到云端采集',
                    textAlign: TextAlign.center,
                    style: kMono.copyWith(fontSize: 8, height: 1.8, letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProvider() async {
    final notifier = ref.read(settingsControllerProvider.notifier);
    await notifier.setApiKey(_key.text);
    await notifier.setBaseUrl(_base.text);
    _snack('DeepSeek 配置已保存');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('清空全部数据？'),
        content: const Text('所有来源、情报、AI 分析都会删除，且无法恢复。API Key 会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清空', style: TextStyle(color: Color(0xFFFF8A9A))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dbProvider).wipeAll();
    ref.invalidate(statsProvider);
    ref.invalidate(libraryDocsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(usageProvider);
    _snack('本地数据已清空');
  }
}

class _Section extends StatelessWidget {
  final String kicker;
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  const _Section({
    required this.kicker,
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 7),
              Expanded(child: MonoLabel(kicker, color: accent)),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NColors.text)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: kMono.copyWith(fontSize: 9, letterSpacing: 1.1),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          activeColor: NColors.cyan,
          activeTrackColor: NColors.cyan.withValues(alpha: 0.25),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: NColors.text))),
            Text(label, style: kMono.copyWith(fontSize: 9, color: NColors.cyan)),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: NColors.cyan,
          inactiveColor: Colors.white.withValues(alpha: 0.08),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
