import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../core/models.dart';
import '../core/utils.dart';

class SitemapParse {
  final bool isIndex;
  final List<String> urls;

  const SitemapParse({required this.isIndex, required this.urls});
}

SourceKind sniffKind(String body, String contentType, Uri uri) {
  final ct = contentType.toLowerCase();
  final trimmed = body.trimLeft();
  final head = (trimmed.length > 800 ? trimmed.substring(0, 800) : trimmed).toLowerCase();
  if (ct.contains('rss') || ct.contains('atom')) {
    return ct.contains('atom') ? SourceKind.atom : SourceKind.rss;
  }
  if (head.startsWith('{') || head.startsWith('[') || ct.contains('json')) {
    return SourceKind.jsonApi;
  }
  if (head.contains('<urlset') || head.contains('<sitemapindex')) {
    return SourceKind.sitemap;
  }
  if (head.contains('<rss') || head.contains('<rdf:rdf') || head.contains('<rdf')) {
    return SourceKind.rss;
  }
  if (head.contains('<feed') || head.contains('<atom')) {
    return SourceKind.atom;
  }
  if (head.startsWith('<?xml')) {
    try {
      final doc = XmlDocument.parse(body);
      final name = doc.rootElement.name.local.toLowerCase();
      if (name == 'rss' || name == 'rdf') return SourceKind.rss;
      if (name == 'feed') return SourceKind.atom;
      if (name == 'urlset' || name == 'sitemapindex') return SourceKind.sitemap;
    } catch (_) {}
  }
  return SourceKind.html;
}

CrawlOutcome parseFeed(String body, String baseUrl, {int limit = 30}) {
  final doc = XmlDocument.parse(body);
  final root = doc.rootElement;
  final isAtom = root.name.local.toLowerCase() == 'feed';
  final channel = isAtom ? root : (root.findAllElements('channel').firstOrNull ?? root);
  final feedTitle = _firstText(channel, ['title']) ?? '';
  final nodes = isAtom
      ? root.findAllElements('entry').take(limit)
      : root.findAllElements('item').take(limit);
  final items = <CrawlItem>[];
  for (final node in nodes) {
    final rawTitle = _firstText(node, ['title']) ?? '';
    var link = _firstText(node, ['link']) ?? '';
    if (link.isEmpty) {
      final linkEl = node.findAllElements('link').firstOrNull;
      link = linkEl?.getAttribute('href') ?? '';
    }
    if (link.isEmpty) continue;
    final content = _firstText(node, ['encoded', 'content', 'description', 'summary']) ?? '';
    final excerpt = _firstText(node, ['summary', 'description']) ?? '';
    final published = parseFlexibleDate(
      _firstText(node, ['pubdate', 'published', 'updated', 'date', 'modified']),
    );
    final author = _firstText(node, ['creator', 'author', 'name']);
    final image = _firstAttr(node, ['enclosure', 'content', 'thumbnail'], 'url');
    final resolved = normalizeUrl(link, base: baseUrl);
    items.add(CrawlItem(
      url: resolved,
      title: rawTitle.trim().isEmpty ? resolved : cleanText(rawTitle),
      content: cleanText(content),
      excerpt: cleanText(excerpt),
      author: author ?? '',
      imageUrl: image ?? '',
      publishedAt: published,
      raw: node.toXmlString(),
    ));
  }
  return CrawlOutcome(
    kind: isAtom ? SourceKind.atom : SourceKind.rss,
    feedTitle: cleanText(feedTitle),
    items: items,
  );
}

SitemapParse parseSitemap(String body) {
  final doc = XmlDocument.parse(body);
  final rootName = doc.rootElement.name.local.toLowerCase();
  final urls = doc
      .findAllElements('loc')
      .map((e) => e.innerText.trim())
      .where((e) => e.startsWith('http'))
      .toList();
  return SitemapParse(
    isIndex: rootName == 'sitemapindex',
    urls: urls,
  );
}

CrawlOutcome parseJsonFeed(String body, String baseUrl, {int limit = 30}) {
  dynamic data;
  try {
    data = jsonDecode(body);
  } catch (e) {
    throw FormatException('JSON 解析失败：$e');
  }
  final list = _findList(data);
  if (list == null) {
    throw const FormatException('JSON 中没有找到文章列表（支持 items/data/articles/posts/results 等字段）');
  }
  final items = <CrawlItem>[];
  for (final entry in list.take(limit)) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final title = _pick(map, ['title', 'name', 'headline', 'subject']).trim();
    final link = _pick(map, ['url', 'link', 'href', 'permalink', 'web_url']).trim();
    if (title.isEmpty && link.isEmpty) continue;
    final summary = _pick(map, ['summary', 'description', 'excerpt', 'abstract', 'intro']);
    final content = _pick(map, ['content', 'body', 'text', 'article', 'html']);
    final published = parseFlexibleDate(
      _pick(map, ['published_at', 'publishedAt', 'published', 'date', 'created_at', 'pubDate', 'time']),
    );
    final image = _pick(map, ['image', 'cover', 'thumbnail', 'image_url', 'featured_image']);
    items.add(CrawlItem(
      url: link.isEmpty ? baseUrl : normalizeUrl(link, base: baseUrl),
      title: title.isEmpty ? sourceHost(link) : title,
      content: cleanText(content.isEmpty ? summary : content),
      excerpt: cleanText(summary),
      author: _pick(map, ['author', 'creator', 'byline']),
      imageUrl: image,
      publishedAt: published,
      raw: jsonEncode(map),
    ));
  }
  return CrawlOutcome(kind: SourceKind.jsonApi, items: items);
}

CrawlOutcome parseHtmlPage(String body, String baseUrl, {int limit = 30}) {
  final doc = html_parser.parse(body);
  final htmlLang = doc.documentElement?.attributes['lang'] ?? '';
  final canonical = doc.querySelector('link[rel="canonical"]')?.attributes['href'];
  final pageUrl = canonical != null && canonical.isNotEmpty
      ? normalizeUrl(canonical, base: baseUrl)
      : baseUrl;
  final title = _meta(doc, ['og:title', 'twitter:title']) ??
      doc.querySelector('h1')?.text.trim() ??
      doc.querySelector('title')?.text.trim() ??
      sourceHost(baseUrl);
  final description = _meta(doc, ['og:description', 'twitter:description', 'description']) ?? '';
  final image = _meta(doc, ['og:image', 'twitter:image', 'twitter:image:src']) ?? '';
  final author = _meta(doc, ['author', 'article:author', 'og:article:author']) ??
      doc.querySelector('[rel="author"]')?.text.trim() ??
      '';
  final published = parseFlexibleDate(
    _meta(doc, ['article:published_time', 'article:modified_time', 'datePublished', 'pubdate', 'date']),
  ) ??
      parseFlexibleDate(doc.querySelector('time[datetime]')?.attributes['datetime']);

  doc
      .querySelectorAll('script,style,noscript,iframe,svg,form,nav,footer,aside,button')
      .forEach((e) => e.remove());
  final candidates = doc.querySelectorAll(
    'article, main, [role="main"], .post-content, .entry-content, .article-content, '
    '.article-body, .post-body, #content, .content, .markdown-body',
  );
  dom.Element? best;
  var bestScore = 0.0;
  for (final c in candidates) {
    final s = _scoreElement(c);
    if (s > bestScore) {
      bestScore = s;
      best = c;
    }
  }
  if (best == null || bestScore < 180) best = doc.body;
  var text = _blockText(best);
  if (text.length < 160) {
    text = cleanText(best?.text ?? '');
  }
  var imageUrl = image;
  if (imageUrl.isEmpty) {
    final firstImg = doc.querySelector('img');
    imageUrl = firstImg?.attributes['src'] ?? '';
  }
  if (imageUrl.isNotEmpty) imageUrl = Uri.parse(baseUrl).resolve(imageUrl).toString();
  return CrawlOutcome(
    kind: SourceKind.html,
    feedTitle: cleanText(title),
    items: [
      CrawlItem(
        url: pageUrl,
        title: cleanText(title),
        content: text,
        excerpt: cleanText(description),
        author: cleanText(author),
        imageUrl: imageUrl,
        language: htmlLang,
        publishedAt: published,
        raw: truncate(body, 400000),
      ),
    ],
  );
}

String? _meta(dom.Document doc, List<String> keys) {
  for (final key in keys) {
    final el = doc.querySelector('meta[property="$key"]') ?? doc.querySelector('meta[name="$key"]');
    final c = el?.attributes['content']?.trim();
    if (c != null && c.isNotEmpty) return c;
  }
  return null;
}

double _scoreElement(dom.Element e) {
  final ps = e.querySelectorAll('p');
  var textLen = 0;
  for (final p in ps) {
    textLen += p.text.trim().length;
  }
  var linkLen = 0;
  for (final a in e.querySelectorAll('a')) {
    linkLen += a.text.trim().length;
  }
  if (ps.isEmpty) return e.text.trim().length * 0.35 - linkLen;
  return textLen + ps.length * 40 - linkLen * 1.1;
}

String _blockText(dom.Element? e) {
  if (e == null) return '';
  final blocks = e.querySelectorAll('p, h2, h3, li, blockquote, pre');
  final buf = <String>[];
  final seen = <String>{};
  for (final b in blocks) {
    final t = b.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length < 12) continue;
    if (seen.add(t)) buf.add(t);
  }
  return buf.join('\n\n');
}

String? _firstText(XmlElement? e, List<String> names) {
  if (e == null) return null;
  final wanted = names.map((e) => e.toLowerCase()).toSet();
  for (final child in e.descendants.whereType<XmlElement>()) {
    if (wanted.contains(child.name.local.toLowerCase())) {
      final t = child.innerText.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

String? _firstAttr(XmlElement e, List<String> names, String attr) {
  final wanted = names.map((e) => e.toLowerCase()).toSet();
  for (final child in e.descendants.whereType<XmlElement>()) {
    if (wanted.contains(child.name.local.toLowerCase())) {
      final v = child.attributes.where((a) => a.name.local == attr).firstOrNull?.value;
      if (v != null && v.isNotEmpty) return v;
    }
  }
  return null;
}

List<dynamic>? _findList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in ['items', 'data', 'articles', 'posts', 'results', 'list', 'entries', 'records']) {
      final v = data[key];
      if (v is List) return v;
      if (v is Map) {
        final nested = _findList(v);
        if (nested != null) return nested;
      }
    }
  }
  return null;
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final v = map[key];
    if (v == null) continue;
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is num || v is bool) return v.toString();
    if (v is Map) return jsonEncode(v);
    if (v is List) {
      final texts = v.map((e) => e is Map ? (e['text'] ?? e['plain_text'] ?? '') : e).join(' ');
      if (texts.trim().isNotEmpty) return texts.trim();
    }
  }
  return '';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
