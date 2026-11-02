import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

class ReaderPage extends StatefulWidget {
  final String url;
  final String title;

  const ReaderPage({super.key, required this.url, required this.title});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(NColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = null; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) {
            setState(() {
              _error = e.description;
              _loading = false;
            });
          }
        },
      ));
    if (widget.url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        backgroundColor: NColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title.isEmpty ? '原文' : widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 19),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 19),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: widget.url.isEmpty
          ? const EmptyState(
              icon: Icons.link_off,
              title: '没有可打开的链接',
              subtitle: '这条情报没有有效 URL。',
            )
          : Column(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    color: const Color(0xFFFF6B81).withValues(alpha: 0.08),
                    child: Text(
                      '页面加载失败：$_error',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFFB3BE)),
                    ),
                  ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            ),
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
