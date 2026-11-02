import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/crawl/http_client.dart';
import 'package:nexus/crawler/site_crawler.dart';
import 'package:nexus/data/table_data.dart';

void main() {
  test('crawler follows yearbook links and extracts tables', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      if (req.uri.path == '/') {
        req.response.headers.contentType = ContentType.html;
        req.response.write('''
<html><head><title>GDP 统计年鉴</title></head><body>
<a href="/chapter.html">GDP 统计年鉴 2020</a>
<table><tr><td>2020年</td><td>2021年</td></tr><tr><td>2022年</td><td>2023年</td></tr></table>
</body></html>''');
      } else if (req.uri.path == '/chapter.html') {
        req.response.headers.contentType = ContentType.html;
        req.response.write('''
<html><head><title>地区生产总值</title></head><body>
<table>
<tr><th>年份</th><th>GDP</th><th>人口</th></tr>
<tr><td>2020</td><td>100</td><td>10</td></tr>
<tr><td>2021</td><td>110</td><td>11</td></tr>
<tr><td>2022</td><td>121</td><td>12</td></tr>
</table>
</body></html>''');
      } else {
        req.response.statusCode = 404;
        req.response.write('missing');
      }
      await req.response.close();
    });

    final tables = <TableData>[];
    final pages = <CapturedPageResult>[];
    final crawler = SiteCrawler(HttpFetcher());
    final outcome = await crawler.crawl(
      CrawlConfig(keyword: 'GDP', seeds: [base], maxPages: 5, maxDepth: 2),
      onProgress: (_) {},
      onTable: (t) async {
        tables.add(t);
        return true;
      },
      onPage: (p) async {
        pages.add(p);
        return true;
      },
      isCancelled: () => false,
    );
    await server.close(force: true);
    expect(outcome.pages, greaterThanOrEqualTo(2));
    expect(pages, isNotEmpty);
    expect(tables, isNotEmpty);
    expect(tables.any((t) => t.headers.contains('GDP')), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
