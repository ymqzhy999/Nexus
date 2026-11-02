import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class FetchResult {
  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
  final String contentType;
  final Uri uri;

  FetchResult({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.contentType,
    required this.uri,
  });

  bool get ok => statusCode >= 200 && statusCode < 400;
}

class FetchException implements Exception {
  final String message;
  final int? statusCode;

  FetchException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class FetchBytesResult {
  final Uint8List bytes;
  final int statusCode;
  final String contentType;
  final Uri uri;

  FetchBytesResult({
    required this.bytes,
    required this.statusCode,
    required this.contentType,
    required this.uri,
  });

  bool get ok => statusCode >= 200 && statusCode < 400;
}

class _CacheEntry {
  final DateTime at;
  final FetchResult result;

  _CacheEntry(this.at, this.result);
}

class HttpFetcher {
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0 Mobile Safari/537.36 Nexus/0.1';

  final String? proxyUrl;
  final Dio _dio;
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, DateTime> _lastHit = {};
  Duration hostInterval = const Duration(milliseconds: 700);
  Duration cacheTtl = const Duration(minutes: 3);

  HttpFetcher({this.proxyUrl}) : _dio = Dio() {
    _dio.options = BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
      maxRedirects: 6,
      connectTimeout: const Duration(seconds: 18),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 18),
      validateStatus: (_) => true,
      headers: {
        'User-Agent': userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,application/rss+xml;q=0.9,'
                'application/atom+xml;q=0.9,application/json;q=0.9,text/plain;q=0.8,*/*;q=0.5',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    );
    final proxy = proxyUrl?.trim() ?? '';
    if (proxy.isNotEmpty) {
      var raw = proxy;
      if (!raw.contains('://')) raw = 'http://$raw';
      final p = Uri.tryParse(raw);
      if (p != null && p.host.isNotEmpty) {
        _dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.findProxy = (uri) => 'PROXY ${p.host}:${p.port == 0 ? 8080 : p.port}';
            client.connectionTimeout = const Duration(seconds: 18);
            return client;
          },
        );
      }
    }
  }

  Future<FetchResult> get(
    String url, {
    Map<String, String>? headers,
    bool force = false,
    int retries = 2,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw FetchException('URL 格式不正确');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FetchException('只支持 http/https 链接');
    }
    final cacheKey = '$url|${headers?.toString() ?? ''}';
    if (!force) {
      final hit = _cache[cacheKey];
      if (hit != null && DateTime.now().difference(hit.at) < cacheTtl) {
        return hit.result;
      }
    }
    await _throttle(uri.host);
    FetchException? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(headers: headers),
        );
        final status = response.statusCode ?? 0;
        if (status == 429 || status >= 500) {
          last = FetchException('服务器返回 HTTP $status', statusCode: status);
          if (attempt < retries) {
            await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
            continue;
          }
          throw last;
        }
        if (status >= 400) {
          throw FetchException(_describeStatus(status), statusCode: status);
        }
        final body = response.data ?? '';
        final result = FetchResult(
          statusCode: status,
          body: body,
          headers: response.headers.map,
          contentType: response.headers.value('content-type') ?? '',
          uri: response.realUri,
        );
        _cache[cacheKey] = _CacheEntry(DateTime.now(), result);
        return result;
      } on FetchException {
        rethrow;
      } on DioException catch (e) {
        last = FetchException(_describeDio(e));
        if (attempt < retries) {
          await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
          continue;
        }
      } catch (e) {
        last = FetchException('请求失败：$e');
      }
    }
    throw last ?? FetchException('请求失败');
  }

  Future<FetchBytesResult> getBytes(
    String url, {
    Map<String, String>? headers,
    int retries = 2,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) throw FetchException('URL 格式不正确');
    await _throttle(uri.host);
    FetchException? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes, headers: headers),
        );
        final status = response.statusCode ?? 0;
        if (status == 429 || status >= 500) {
          last = FetchException('服务器返回 HTTP $status', statusCode: status);
          if (attempt < retries) {
            await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
            continue;
          }
          throw last;
        }
        if (status >= 400) {
          throw FetchException(_describeStatus(status), statusCode: status);
        }
        return FetchBytesResult(
          bytes: Uint8List.fromList(response.data ?? const []),
          statusCode: status,
          contentType: response.headers.value('content-type') ?? '',
          uri: response.realUri,
        );
      } on FetchException {
        rethrow;
      } on DioException catch (e) {
        last = FetchException(_describeDio(e));
        if (attempt < retries) {
          await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
          continue;
        }
      } catch (e) {
        last = FetchException('下载失败：$e');
      }
    }
    throw last ?? FetchException('下载失败');
  }

  Future<void> _throttle(String host) async {
    final last = _lastHit[host];
    if (last != null) {
      final wait = hostInterval - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastHit[host] = DateTime.now();
  }

  String _describeStatus(int status) {
    if (status == 401) return '需要登录或认证（401）';
    if (status == 403) return '访问被拒绝（403），可能被站点风控或 Cloudflare 拦截';
    if (status == 404) return '页面不存在（404）';
    if (status == 429) return '请求过于频繁（429）';
    return 'HTTP $status';
  }

  String _describeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络或代理设置';
      case DioExceptionType.badCertificate:
        return 'TLS 证书校验失败';
      case DioExceptionType.connectionError:
        return '无法连接（DNS/网络/代理异常）';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络错误：${e.message ?? e.type.name}';
    }
  }
}
