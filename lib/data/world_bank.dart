import '../catalog/data_sources.dart';
import '../crawl/http_client.dart';
import 'table_data.dart';
import 'table_parser.dart';

class WorldBankService {
  final HttpFetcher http;

  WorldBankService(this.http);

  Future<TableData> fetch({
    required WbCountry country,
    required WbIndicator indicator,
    required int startYear,
    required int endYear,
  }) async {
    final url = 'https://api.worldbank.org/v2/country/${country.code}/indicator/${indicator.code}'
        '?format=json&per_page=200&date=$startYear:$endYear';
    final res = await http.get(url, force: true);
    if (!res.ok) throw Exception('世界银行接口 HTTP ${res.statusCode}');
    final parsed = TableParser.parseText(
      text: res.body,
      url: url,
      sourceName: '世界银行',
      contentType: res.contentType,
    );
    if (parsed.tables.isEmpty || parsed.tables.first.rows.isEmpty) {
      throw Exception(parsed.error ?? '世界银行没有返回该指标的数据');
    }
    final t = parsed.tables.first;
    return TableData(
      title: '${country.name} · ${indicator.name} · $startYear-$endYear',
      sourceUrl: url,
      sourceName: '世界银行',
      headers: t.headers,
      rows: t.rows,
      meta: {
        ...t.meta,
        'provider': 'World Bank',
        'country': country.name,
        'country_code': country.code,
        'indicator': indicator.name,
        'indicator_code': indicator.code,
        'unit': indicator.unit,
        'start_year': startYear,
        'end_year': endYear,
      },
    );
  }
}
