import 'dart:math' as math;

import '../core/models.dart';
import '../core/utils.dart';
import 'extractors.dart';
import 'http_client.dart';

class CrawlException implements Exception {
  final String message;

  CrawlException(this.message);

  @override
  String toString() => message;
}

class CrawlEngine {
  final HttpFetcher http;

  CrawlEngine(this.http);

  Future<CrawlOutcome> crawl(
    String url, {
    SourceKind hint = SourceKind.auto,
    int limit = 20,
  }) async {
    final clean = normalizeUrl(url);
    if (clean.isEmpty) throw CrawlException('请输入有效的网址');
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme) throw CrawlException('网址需要以 http:// 或 https:// 开头');

    final first = await http.get(clean, force: true);
    if (!first.ok) throw CrawlException('抓取失败：HTTP ${first.statusCode}');
    if (first.body.trim().isEmpty) throw CrawlException('页面内容为空');

    var kind = hint == SourceKind.auto
        ? sniffKind(first.body, first.contentType, first.uri)
        : hint;
    if (kind == SourceKind.auto) kind = SourceKind.html;

    switch (kind) {
      case SourceKind.rss:
      case SourceKind.atom:
        try {
          final out = parseFeed(first.body, clean, limit: limit);
          if (out.items.isEmpty) throw CrawlException('订阅源里没有解析到文章');
          return out;
        } on FormatException catch (e) {
          throw CrawlException('订阅源解析失败：$e');
        }
      case SourceKind.sitemap:
        return _crawlSitemap(clean, first.body, limit: limit);
      case SourceKind.jsonApi:
        try {
          final out = parseJsonFeed(first.body, clean, limit: limit);
          if (out.items.isEmpty) throw CrawlException('JSON 中没有可用条目');
          return out;
        } on FormatException catch (e) {
          throw CrawlException('JSON 解析失败：${e.message}');
        }
      case SourceKind.html:
        final out = parseHtmlPage(first.body, clean);
        if (out.items.isEmpty) throw CrawlException('没有提取到正文');
        return out;
      case SourceKind.auto:
        throw CrawlException('无法识别来源类型');
    }
  }

  Future<CrawlOutcome> _crawlSitemap(String url, String body, {required int limit}) async {
    SitemapParse parsed;
    try {
      parsed = parseSitemap(body);
    } on FormatException catch (e) {
      throw CrawlException('Sitemap 解析失败：$e');
    }
    var urls = parsed.urls;
    if (parsed.isIndex) {
      final pages = <String>[];
      for (final child in urls.take(2)) {
        try {
          final res = await http.get(child, force: true);
          final sub = parseSitemap(res.body);
          pages.addAll(sub.urls);
        } catch (_) {}
      }
      urls = pages;
    }
    urls = urls.where((u) => u.startsWith('http')).toSet().toList();
    if (urls.isEmpty) throw CrawlException('Sitemap 中没有找到页面 URL');
    final targets = urls.take(math.min(limit, 8)).toList();
    final items = <CrawlItem>[];
    var failed = 0;
    for (final target in targets) {
      try {
        final res = await http.get(target, force: true);
        if (!res.ok) {
          failed++;
          continue;
        }
        final out = parseHtmlPage(res.body, target);
        if (out.items.isNotEmpty) items.add(out.items.first);
      } catch (_) {
        failed++;
      }
    }
    if (items.isEmpty) throw CrawlException('Sitemap 页面抓取失败（成功 0/${targets.length}）');
    return CrawlOutcome(
      kind: SourceKind.sitemap,
      feedTitle: sourceHost(url),
      items: items,
      note: 'Sitemap 模式抓取了 ${items.length} 个页面'
          '${failed > 0 ? '，$failed 个失败' : ''}。移动端建议小批量使用。',
    );
  }
}
