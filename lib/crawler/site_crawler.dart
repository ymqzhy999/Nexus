import 'dart:collection';

import 'package:html/parser.dart' as html_parser;

import '../core/utils.dart';
import '../crawl/http_client.dart';
import '../data/table_data.dart';
import '../data/table_parser.dart';

class CrawlConfig {
  final String keyword;
  final List<String> seeds;
  final int maxPages;
  final int maxDepth;
  final int maxTables;
  final int? startYear;
  final int? endYear;

  const CrawlConfig({
    required this.keyword,
    required this.seeds,
    this.maxPages = 60,
    this.maxDepth = 3,
    this.maxTables = 80,
    this.startYear,
    this.endYear,
  });
}

class CrawlProgress {
  final int pages;
  final int pagesSaved;
  final int queued;
  final int tables;
  final int datasets;
  final String current;
  final List<String> errors;

  const CrawlProgress({
    required this.pages,
    required this.pagesSaved,
    required this.queued,
    required this.tables,
    required this.datasets,
    required this.current,
    required this.errors,
  });
}

class CrawlOutcome {
  final int pages;
  final int pagesSaved;
  final int tables;
  final int datasets;
  final List<String> errors;
  final bool cancelled;

  const CrawlOutcome({
    required this.pages,
    required this.pagesSaved,
    required this.tables,
    required this.datasets,
    required this.errors,
    required this.cancelled,
  });
}

class CrawlAttachment {
  final String url;
  final String label;
  final String type;

  const CrawlAttachment(this.url, this.label, this.type);

  Map<String, String> toJson() => {'url': url, 'label': label, 'type': type};
}

class CapturedPageResult {
  final String url;
  final String title;
  final String domain;
  final String text;
  final String excerpt;
  final String status;
  final int httpStatus;
  final int tableCount;
  final List<CrawlAttachment> attachments;
  final bool matched;

  const CapturedPageResult({
    required this.url,
    required this.title,
    required this.domain,
    required this.text,
    required this.excerpt,
    required this.status,
    required this.httpStatus,
    required this.tableCount,
    required this.attachments,
    required this.matched,
  });
}

class _Node {
  final String url;
  final int depth;
  final String rootKey;

  const _Node(this.url, this.depth, this.rootKey);
}

class _Link {
  final String url;
  final int score;

  const _Link(this.url, this.score);
}

class SiteCrawler {
  final HttpFetcher http;

  SiteCrawler(this.http);

  Future<CrawlOutcome> crawl(
    CrawlConfig config, {
    required void Function(CrawlProgress) onProgress,
    required Future<bool> Function(TableData) onTable,
    required Future<bool> Function(CapturedPageResult) onPage,
    required bool Function() isCancelled,
  }) async {
    final queue = Queue<_Node>();
    final visited = <String>{};
    final errors = <String>[];
    final terms = _expandTerms(config.keyword);
    final seenTables = <String>{};
    var pages = 0;
    var pagesSaved = 0;
    var tables = 0;
    var datasets = 0;
    var cancelled = false;

    for (final seed in config.seeds) {
      final clean = normalizeUrl(seed);
      final uri = Uri.tryParse(clean);
      if (uri == null || !uri.hasScheme) continue;
      queue.add(_Node(clean, 0, _siteKey(uri)));
    }

    void report(String current) {
      onProgress(CrawlProgress(
        pages: pages,
        pagesSaved: pagesSaved,
        queued: queue.length,
        tables: tables,
        datasets: datasets,
        current: current,
        errors: List.of(errors),
      ));
    }

    while (queue.isNotEmpty && pages < config.maxPages) {
      if (isCancelled()) {
        cancelled = true;
        break;
      }
      final node = queue.removeFirst();
      if (!visited.add(node.url)) continue;
      pages++;
      report(node.url);

      try {
        final uri = Uri.parse(node.url);
        final ext = _extension(uri.path);

        if (ext == 'pdf') {
          final page = _pageResult(
            url: node.url,
            title: _fileName(uri),
            text: '',
            status: 'pdf',
            httpStatus: 0,
            tableCount: 0,
            attachments: [CrawlAttachment(node.url, _fileName(uri), 'pdf')],
            terms: terms,
          );
          if (await onPage(page)) pagesSaved++;
          continue;
        }

        if (ext == 'xls') {
          final page = _pageResult(
            url: node.url,
            title: _fileName(uri),
            text: '',
            status: 'xls',
            httpStatus: 0,
            tableCount: 0,
            attachments: [CrawlAttachment(node.url, _fileName(uri), 'xls')],
            terms: terms,
          );
          if (await onPage(page)) pagesSaved++;
          continue;
        }

        if (ext == 'xlsx') {
          final res = await http.getBytes(node.url);
          if (!res.ok) {
            _err(errors, 'HTTP ${res.statusCode}：${node.url}');
            if (await onPage(_pageResult(
              url: node.url,
              title: _fileName(uri),
              text: '',
              status: 'http_${res.statusCode}',
              httpStatus: res.statusCode,
              tableCount: 0,
              attachments: const [],
              terms: terms,
            ))) pagesSaved++;
            continue;
          }
          final parsed = TableParser.parseBytes(
            bytes: res.bytes,
            url: node.url,
            sourceName: uri.host,
            contentType: res.contentType,
          );
          final saved = await _saveTables(parsed.tables, node.url, '', config, seenTables, onTable, config.maxTables - tables);
          tables += saved;
          datasets += saved;
          final page = _pageResult(
            url: node.url,
            title: _fileName(uri),
            text: '',
            status: 'xlsx',
            httpStatus: res.statusCode,
            tableCount: parsed.tables.length,
            attachments: [CrawlAttachment(node.url, _fileName(uri), 'xlsx')],
            terms: terms,
          );
          if (await onPage(page)) pagesSaved++;
          continue;
        }

        final res = await http.get(node.url, force: true);
        if (!res.ok) {
          _err(errors, 'HTTP ${res.statusCode}：${node.url}');
          if (await onPage(_pageResult(
            url: node.url,
            title: '',
            text: '',
            status: 'http_${res.statusCode}',
            httpStatus: res.statusCode,
            tableCount: 0,
            attachments: const [],
            terms: terms,
          ))) pagesSaved++;
          continue;
        }

        final contentType = res.contentType.toLowerCase();
        final bodyTrim = res.body.trimLeft();
        if (contentType.contains('json') || bodyTrim.startsWith('{') || bodyTrim.startsWith('[')) {
          final parsed = TableParser.parseText(
            text: res.body,
            url: node.url,
            sourceName: uri.host,
            contentType: res.contentType,
          );
          final saved = await _saveTables(parsed.tables, node.url, '', config, seenTables, onTable, config.maxTables - tables);
          tables += saved;
          datasets += saved;
          final text = _clip(res.body, 50000);
          final page = _pageResult(
            url: node.url,
            title: 'JSON · ${uri.host}',
            text: text,
            status: 'json',
            httpStatus: res.statusCode,
            tableCount: parsed.tables.length,
            attachments: const [],
            terms: terms,
          );
          if (await onPage(page)) pagesSaved++;
          continue;
        }

        final doc = html_parser.parse(res.body);
        final title = doc.querySelector('title')?.text.trim() ?? '';
        for (final el in doc.querySelectorAll('script,style,noscript,svg,nav,header,footer,aside')) {
          el.remove();
        }
        final text = _cleanText(doc.body?.text ?? doc.documentElement?.text ?? '');
        final attachments = <CrawlAttachment>[];
        final attachmentUrls = <String>{};
        for (final a in doc.querySelectorAll('a[href]')) {
          final href = a.attributes['href'];
          if (href == null) continue;
          final resolved = normalizeUrl(href, base: node.url);
          final u = Uri.tryParse(resolved);
          if (u == null || !u.hasScheme) continue;
          final e = _extension(u.path);
          if (!['xlsx', 'xls', 'csv', 'pdf'].contains(e)) continue;
          if (!attachmentUrls.add(resolved)) continue;
          final label = a.text.trim().isEmpty ? _fileName(u) : a.text.trim();
          attachments.add(CrawlAttachment(resolved, _clip(label, 120), e));
          if (attachments.length >= 50) break;
        }

        final pageTables = TableParser.parseHtmlTables(res.body, url: node.url, sourceName: uri.host);
        final saved = await _saveTables(pageTables, node.url, title, config, seenTables, onTable, config.maxTables - tables);
        tables += saved;
        datasets += saved;

        final page = _pageResult(
          url: node.url,
          title: title,
          text: _clip(text, 50000),
          status: 'ok',
          httpStatus: res.statusCode,
          tableCount: pageTables.length,
          attachments: attachments,
          terms: terms,
        );
        if (await onPage(page)) pagesSaved++;

        if (node.depth < config.maxDepth) {
          final links = <_Link>[];
          for (final el in doc.querySelectorAll('a[href], iframe[src], frame[src]')) {
            final href = el.attributes['href'] ?? el.attributes['src'];
            if (href == null || href.trim().isEmpty) continue;
            final resolved = normalizeUrl(href, base: node.url);
            final u = Uri.tryParse(resolved);
            if (u == null || !u.hasScheme || (u.scheme != 'http' && u.scheme != 'https')) continue;
            if (_siteKey(u) != node.rootKey) continue;
            if (_skipExtension(u.path)) continue;
            final e = _extension(u.path);
            if (e == 'pdf') continue;
            final text = el.text.trim();
            links.add(_Link(resolved, _linkScore(u, text, terms)));
          }
          links.sort((a, b) => b.score.compareTo(a.score));
          for (final l in links.take(32)) {
            queue.add(_Node(l.url, node.depth + 1, node.rootKey));
          }
        }
      } catch (e) {
        _err(errors, '${node.url} → $e');
        try {
          if (await onPage(_pageResult(
            url: node.url,
            title: '',
            text: '',
            status: 'error',
            httpStatus: 0,
            tableCount: 0,
            attachments: const [],
            terms: terms,
          ))) pagesSaved++;
        } catch (_) {}
      }
    }

    report('完成');
    return CrawlOutcome(
      pages: pages,
      pagesSaved: pagesSaved,
      tables: tables,
      datasets: datasets,
      errors: List.of(errors),
      cancelled: cancelled,
    );
  }

  Future<int> _saveTables(
    List<TableData> input,
    String pageUrl,
    String pageTitle,
    CrawlConfig config,
    Set<String> seen,
    Future<bool> Function(TableData) onTable,
    int limit,
  ) async {
    if (limit <= 0) return 0;
    var saved = 0;
    for (var t in input) {
      if (saved >= limit) break;
      if (t.rows.length < 2 || t.headers.length < 2) continue;
      final indexLike = t.looksLikeIndex;
      if (t.isWideYearTable) t = t.toLongFormat();
      if (config.startYear != null && config.endYear != null) {
        final yc = t.yearColumn();
        if (yc != null) {
          final filtered = t.rows.where((r) {
            if (yc >= r.length) return false;
            final y = yearOf(r[yc]);
            return y != null && y >= config.startYear! && y <= config.endYear!;
          }).toList();
          if (filtered.isEmpty) continue;
          t = t.copyWith(rows: filtered);
        }
      }
      final sig = '${t.headers.join('|')}|${t.rows.length}|${t.rows.isEmpty ? '' : t.rows.first.join('|')}';
      if (!seen.add(sig)) continue;
      final withMeta = TableData(
        title: t.title,
        sourceUrl: pageUrl,
        sourceName: Uri.parse(pageUrl).host,
        headers: t.headers,
        rows: t.rows,
        meta: {
          ...t.meta,
          'page_url': pageUrl,
          'page_title': pageTitle,
          'table_kind': indexLike ? 'index' : 'data',
        },
      );
      if (await onTable(withMeta)) saved++;
    }
    return saved;
  }

  CapturedPageResult _pageResult({
    required String url,
    required String title,
    required String text,
    required String status,
    required int httpStatus,
    required int tableCount,
    required List<CrawlAttachment> attachments,
    required List<String> terms,
  }) {
    final hay = '${title.toLowerCase()} ${text.toLowerCase()} ${url.toLowerCase()} '
        '${attachments.map((e) => '${e.label} ${e.url}').join(' ').toLowerCase()}';
    final matched = terms.isEmpty || terms.any((t) => hay.contains(t));
    var excerpt = '';
    if (text.isNotEmpty) {
      final lower = text.toLowerCase();
      var index = -1;
      for (final t in terms) {
        final i = lower.indexOf(t);
        if (i >= 0 && (index < 0 || i < index)) index = i;
      }
      if (index >= 0) {
        final start = (index - 140).clamp(0, text.length).toInt();
        final end = (index + 320).clamp(0, text.length).toInt();
        excerpt = text.substring(start, end);
      } else {
        excerpt = text.substring(0, text.length > 420 ? 420 : text.length);
      }
    }
    return CapturedPageResult(
      url: url,
      title: title.isEmpty ? url : title,
      domain: Uri.tryParse(url)?.host ?? '',
      text: _clip(text, 50000),
      excerpt: _cleanText(excerpt),
      status: status,
      httpStatus: httpStatus,
      tableCount: tableCount,
      attachments: attachments,
      matched: matched,
    );
  }

  List<String> _expandTerms(String keyword) {
    final base = keyword
        .toLowerCase()
        .split(RegExp(r'[\s,，、;；]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final out = <String>{...base};
    const map = {
      'gdp': ['国内生产总值', '地区生产总值', '生产总值'],
      'cpi': ['居民消费价格', '消费价格'],
      '人口': ['常住人口', '户籍人口', '人口'],
      '财政': ['一般公共预算', '财政收入', '财政支出'],
      '进出口': ['进出口', '出口', '进口', '贸易'],
      '失业': ['失业率', '城镇调查失业率', '就业'],
      '收入': ['居民人均可支配收入', '可支配收入'],
      '研发': ['研发经费', 'r&d', '科技经费'],
      '债务': ['政府债务', '地方债务', '债务余额'],
      '投资': ['固定资产投资', '投资'],
      '消费': ['社会消费品零售总额', '消费'],
      '工业': ['规模以上工业', '工业增加值'],
      '农业': ['农林牧渔业', '农业产值'],
    };
    for (final b in base) {
      for (final entry in map.entries) {
        if (b.contains(entry.key) || entry.key.contains(b)) out.addAll(entry.value);
      }
    }
    return out.map((e) => e.toLowerCase()).toList();
  }

  int _linkScore(Uri uri, String text, List<String> terms) {
    final hay = '${text.toLowerCase()} ${uri.toString().toLowerCase()}';
    var score = 0;
    for (final t in terms) {
      if (hay.contains(t)) score += 10;
    }
    const dataHints = ['统计', '年鉴', '数据', '指标', '报表', '公报', 'tjnj', 'yearbook', 'data', 'excel', 'xls', 'csv'];
    for (final h in dataHints) {
      if (hay.contains(h)) score += 2;
    }
    if (['xlsx', 'csv'].contains(_extension(uri.path))) score += 8;
    return score;
  }

  String _cleanText(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _clip(String input, int max) => input.length > max ? input.substring(0, max) : input;

  String _fileName(Uri uri) {
    final seg = uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last;
    return seg.isEmpty ? uri.host : seg;
  }

  bool _skipExtension(String path) {
    final ext = _extension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'css', 'js', 'zip', 'rar', '7z', 'mp4', 'mp3', 'woff', 'woff2', 'ttf', 'pdf', 'xls'].contains(ext);
  }

  String _extension(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0 || i == path.length - 1) return '';
    return path.substring(i + 1).toLowerCase();
  }

  String _siteKey(Uri uri) {
    final host = uri.host.toLowerCase();
    final parts = host.split('.');
    if (host.endsWith('.gov.cn') || host.endsWith('.edu.cn') || host.endsWith('.com.cn') || host.endsWith('.org.cn')) {
      return parts.length >= 3 ? parts.sublist(parts.length - 3).join('.') : host;
    }
    return parts.length >= 2 ? parts.sublist(parts.length - 2).join('.') : host;
  }

  void _err(List<String> errors, String message) {
    if (errors.length < 30) errors.add(message);
  }
}
