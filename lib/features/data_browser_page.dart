import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/table_data.dart';
import '../data/table_parser.dart';
import '../state/providers.dart';

class DataBrowserPage extends ConsumerStatefulWidget {
  final String url;
  final String title;

  const DataBrowserPage({super.key, required this.url, required this.title});

  @override
  ConsumerState<DataBrowserPage> createState() => _DataBrowserPageState();
}

class _DataBrowserPageState extends ConsumerState<DataBrowserPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  bool _busy = false;
  String _pageUrl = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(NColors.bg)
      ..addJavaScriptChannel('NexusTables', onMessageReceived: _onTables)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (url) {
          _pageUrl = url;
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (url) async {
          if (mounted) setState(() => _loading = false);
          final current = await _controller.currentUrl();
          if (current != null) _pageUrl = current;
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) {
            setState(() {
              _error = e.description;
              _loading = false;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
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
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 19), onPressed: () => _controller.reload()),
          IconButton(
            icon: const Icon(Icons.table_rows_outlined, size: 20, color: NColors.lime),
            tooltip: '抓取本页表格',
            onPressed: _busy ? null : _capture,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress / 100,
              minHeight: 2,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(NColors.cyan),
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFF6B81).withValues(alpha: 0.08),
              child: Text('页面加载失败：$_error', style: const TextStyle(fontSize: 11, color: Color(0xFFFFB3BE))),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
          if (_busy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: NColors.surface,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: NColors.lime)),
                  SizedBox(width: 8),
                  Text('正在读取页面表格…', style: TextStyle(fontSize: 11, color: NColors.lime)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    final current = await _controller.currentUrl();
    if (current != null) _pageUrl = current;
    const js = '''
(function(){
  try {
    var tables = Array.prototype.slice.call(document.querySelectorAll('table')).slice(0, 30);
    var out = tables.map(function(t, i){
      var rows = t.rows ? t.rows.length : 0;
      var cols = (t.rows && t.rows[0]) ? t.rows[0].cells.length : 0;
      return {i: i, rows: rows, cols: cols, html: t.outerHTML};
    });
    NexusTables.postMessage(JSON.stringify({tables: out}));
  } catch (e) {
    NexusTables.postMessage(JSON.stringify({error: String(e)}));
  }
})();
''';
    await _controller.runJavaScript(js);
    Future<void>.delayed(const Duration(seconds: 10), () {
      if (mounted && _busy) setState(() => _busy = false);
    });
  }

  Future<void> _onTables(JavaScriptMessage message) async {
    if (!mounted) return;
    setState(() => _busy = false);
    dynamic data;
    try {
      data = jsonDecode(message.message);
    } catch (_) {
      _snack('页面返回格式异常');
      return;
    }
    if (data is Map && data['error'] != null) {
      _snack('抓取失败：${data['error']}');
      return;
    }
    final rawTables = data is Map ? data['tables'] : null;
    if (rawTables is! List || rawTables.isEmpty) {
      _snack('没有找到表格。请进入具体的年鉴/统计表页面再抓。');
      return;
    }
    final parsed = <TableData>[];
    for (final raw in rawTables.whereType<Map>()) {
      final html = (raw['html'] ?? '').toString();
      if (html.isEmpty) continue;
      final tables = TableParser.parseHtmlTables(html, url: _pageUrl, sourceName: widget.title);
      if (tables.isNotEmpty) parsed.add(tables.first);
    }
    if (parsed.isEmpty) {
      _snack('识别到表格，但没有可用行列。');
      return;
    }
    final chosen = await _pickTable(parsed);
    if (chosen == null) return;
    final id = await ref.read(datasetsRepositoryProvider).saveDataset(chosen);
    if (!mounted) return;
    context.push('/dataset/$id');
  }

  Future<TableData?> _pickTable(List<TableData> tables) {
    return showModalBottomSheet<TableData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const MonoLabel('CAPTURED TABLES', color: NColors.lime),
            const SizedBox(height: 6),
            Text('识别到 ${tables.length} 个表格', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < tables.length; i++)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.pop(context, tables[i]),
                child: Row(
                  children: [
                    Text('${i + 1}', style: kMono.copyWith(fontSize: 11, color: NColors.lime)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tables[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('${tables[i].rows.length} 行 × ${tables[i].headers.length} 列',
                              style: kMono.copyWith(fontSize: 8.5)),
                          const SizedBox(height: 2),
                          Text(tables[i].headers.take(5).join(' · '), maxLines: 1,
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: NColors.muted)),
                        ],
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
