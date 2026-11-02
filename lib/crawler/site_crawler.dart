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
    this.maxDepth = 2,
    this.maxTables = 60,
    this.startYear,
    this.endYear,
  });
}

class CrawlProgress {
  final int pages;
  final int queued;
  final int tables;
  final int datasets;
  final String current;
  final List<String> errors;

  const CrawlProgress({
    required this.pages,
    required this.queued,
    required this.tables,
    required this.datasets,
    required this.current,
    required this.errors,
  });
}

class CrawlOutcome {
  final int pages;
  final int tables;
  final int datasets;
  final List<String> errors;
  final bool cancelled;

  const CrawlOutcome({
    required this.pages,
    required this.tables,
    required this.datasets,
    required this.errors,
    required this.cancelled,
  });
}

class _Node {
  final String url;
  final int depth;
  final String rootKey;

  const _Node(this.url, this.depth, this.rootKey);
}

class SiteCrawler {
  final HttpFetcher http;

  SiteCrawler(this.http);

  Future<CrawlOutcome> crawl(
    CrawlConfig config, {
    required void Function(CrawlProgress) onProgress,
    required Future<bool> Function(TableData) onTable,
    required bool Function() isCancelled,
  }) async {
    final queue = Queue<_Node>();
    final visited = <String>{};
    final errors = <String>[];
    final terms = _expandTerms(config.keyword);
    var pages = 0;
    var tables = 0;
    var datasets = 0;
    var cancelled = false;
    final seenTables = <String>{};

    for (final seed in config.seeds) {
      final clean = normalizeUrl(seed);
      final uri = Uri.tryParse(clean);
      if (uri == null || !uri.hasScheme) continue;
      queue.add(_Node(clean, 0, _siteKey(uri)));
    }

    void report(String current) {
      onProgress(CrawlProgress(
        pages: pages,
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
          _err(errors, 'PDF 暂不解析：${node.url}');
          continue;
        }
        if (ext == 'xlsx' || ext == 'xls' || ext == 'csv') {
          if (ext == 'xls') {
            _err(errors, '旧版 .xls 暂不解析：${node.url}');
            continue;
          }
          if (ext == 'xlsx') {
            final res = await http.getBytes(node.url);
            if (!res.ok) {
              _err(errors, 'HTTP ${res.statusCode}：${node.url}');
              continue;
            }
            final parsed = TableParser.parseBytes(
              bytes: res.bytes,
              url: node.url,
              sourceName: uri.host,
              contentType: res.contentType,
            );
            for (final t in parsed.tables) {
              if (tables >= config.maxTables) break;
              final ok = await _consider(t, node.url, '', config, terms, seenTables, onTable);
              if (ok) {
                tables++;
                datasets++;
              }
            }
            continue;
          }
        }

        final res = await http.get(node.url, force: true);
        if (!res.ok) {
          _err(errors, 'HTTP ${res.statusCode}：${node.url}');
          continue;
        }
        final contentType = res.contentType.toLowerCase();
        if (contentType.contains('json') || res.body.trimLeft().startsWith('{') || res.body.trimLeft().startsWith('[')) {
          final parsed = TableParser.parseText(
            text: res.body,
            url: node.url,
            sourceName: uri.host,
            contentType: res.contentType,
          );
          for (final t in parsed.tables) {
            if (tables >= config.maxTables) break;
            final ok = await _consider(t, node.url, '', config, terms, seenTables, onTable);
            if (ok) {
              tables++;
              datasets++;
            }
          }
          continue;
        }

        final doc = html_parser.parse(res.body);
        final title = doc.querySelector('title')?.text.trim() ?? '';
        final pageTables = TableParser.parseHtmlTables(res.body, url: node.url, sourceName: uri.host);
        for (final t in pageTables) {
          if (tables >= config.maxTables) break;
          final ok = await _consider(t, node.url, title, config, terms, seenTables, onTable);
          if (ok) {
            tables++;
            datasets++;
          }
        }

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
            final text = el.text.trim();
            final relax = '${title.toLowerCase()} ${node.url.toLowerCase()}'
                .contains(RegExp(r'年鉴|ndsj|tjnj|yearbook|统计|数据'));
            var score = _linkScore(u, text, terms);
            if (score <= 0 && relax) score = 1;
            if (score <= 0) continue;
            links.add(_Link(resolved, score));
          }
          links.sort((a, b) => b.score.compareTo(a.score));
          for (final l in links.take(28)) {
            queue.add(_Node(l.url, node.depth + 1, node.rootKey));
          }
        }
      } catch (e) {
        _err(errors, '${node.url} → $e');
      }
    }

    report('完成');
    return CrawlOutcome(
      pages: pages,
      tables: tables,
      datasets: datasets,
      errors: List.of(errors),
      cancelled: cancelled,
    );
  }

  Future<bool> _consider(
    TableData raw,
    String pageUrl,
    String pageTitle,
    CrawlConfig config,
    List<String> terms,
    Set<String> seen,
    Future<bool> Function(TableData) onTable,
  ) async {
    var t = raw;
    if (t.isWideYearTable) t = t.toLongFormat();
    if (t.looksLikeIndex) return false;
    if (t.measureColumnCount == 0) return false;

    if (terms.isNotEmpty) {
      final rowLabels = t.rows.take(40).map((r) => r.take(2).join(' ')).join(' ');
      // A table's fallback title is the page title; using it would make every
      // table on a province page match the province term. Only use a real
      // caption/sheet title, plus headers and row labels.
      final caption = pageTitle.isNotEmpty && t.title.trim() == pageTitle.trim() ? '' : t.title;
      final hay = '$caption ${t.headers.join(' ')} $rowLabels'.toLowerCase();
      if (!terms.any((term) => hay.contains(term))) return false;
    }

    if (config.startYear != null && config.endYear != null) {
      final yc = t.yearColumn();
      if (yc != null) {
        final filtered = t.rows.where((r) {
          if (yc >= r.length) return false;
          final y = yearOf(r[yc]);
          return y != null && y >= config.startYear! && y <= config.endYear!;
        }).toList();
        if (filtered.isEmpty) return false;
        t = t.copyWith(rows: filtered);
      }
    }

    final sig = '${t.headers.join('|')}|${t.rows.length}|${t.rows.isEmpty ? '' : t.rows.first.join('|')}';
    if (!seen.add(sig)) return false;
    return onTable(t);
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
    const dataHints = ['统计', '年鉴', '数据', '指标', '报表', '公报', 'tjnj', 'yearbook', 'data', 'excel', 'xls', 'csv', 'pdf'];
    for (final h in dataHints) {
      if (hay.contains(h)) score += 2;
    }
    if (['xlsx', 'xls', 'csv'].contains(_extension(uri.path))) score += 8;
    return score;
  }

  bool _skipExtension(String path) {
    final ext = _extension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'css', 'js', 'zip', 'rar', '7z', 'mp4', 'mp3', 'woff', 'woff2', 'ttf'].contains(ext);
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

class _Link {
  final String url;
  final int score;

  const _Link(this.url, this.score);
}
