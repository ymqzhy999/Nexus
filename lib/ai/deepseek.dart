import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/models.dart';
import '../core/utils.dart';

class AiException implements Exception {
  final String message;

  AiException(this.message);

  @override
  String toString() => message;
}

class AiInput {
  final String title;
  final String url;
  final String source;
  final String content;
  final DateTime? publishedAt;

  const AiInput({
    required this.title,
    required this.url,
    required this.content,
    this.source = '',
    this.publishedAt,
  });
}

class AiContext {
  final String title;
  final String url;
  final String summary;
  final String content;

  const AiContext({
    required this.title,
    required this.url,
    required this.summary,
    this.content = '',
  });
}

class JsonCompletion {
  final Map<String, dynamic> json;
  final int inputTokens;
  final int outputTokens;
  final String model;

  const JsonCompletion({
    required this.json,
    required this.inputTokens,
    required this.outputTokens,
    required this.model,
  });
}

class _Completion {
  final String content;
  final int inputTokens;
  final int outputTokens;
  final String model;

  const _Completion(this.content, this.inputTokens, this.outputTokens, this.model);
}

class DeepSeekClient {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String proxyUrl;
  late final Dio _dio;
  late final String _endpoint;

  DeepSeekClient({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.proxyUrl = '',
  }) {
    var base = baseUrl.trim();
    if (base.isEmpty) base = 'https://api.deepseek.com';
    base = base.replaceAll(RegExp(r'/+$'), '');
    _endpoint = base.endsWith('/chat/completions') ? base : '$base/chat/completions';
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    final proxy = proxyUrl.trim();
    if (proxy.isNotEmpty) {
      var raw = proxy;
      if (!raw.contains('://')) raw = 'http://$raw';
      final p = Uri.tryParse(raw);
      if (p != null && p.host.isNotEmpty) {
        _dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.findProxy = (uri) => 'PROXY ${p.host}:${p.port == 0 ? 8080 : p.port}';
            return client;
          },
        );
      }
    }
  }

  bool get _isReasoner => model.contains('reasoner');

  Future<AiResult> analyze(AiInput input, {String language = '中文'}) async {
    final content = input.content;
    final clipped = content.length > 14000
        ? '${content.substring(0, 14000)}\n\n[正文过长，已截断，共 ${content.length} 字]'
        : content;
    final user = '''
标题：${input.title}
来源：${input.source}
链接：${input.url}
发布时间：${input.publishedAt?.toIso8601String() ?? '未知'}

正文：
$clipped
''';
    final completion = await _completeJson(
      system: _analysisSystem(language),
      user: user,
      maxTokens: 1700,
    );
    final parsed = aiResultFromJson(completion.json);
    if (parsed == null) throw AiException('AI 返回内容缺少 summary 字段');
    return AiResult(
      summary: parsed.summary,
      whyValuable: parsed.whyValuable,
      keyPoints: parsed.keyPoints,
      category: parsed.category,
      tags: parsed.tags,
      entities: parsed.entities,
      valueScore: parsed.valueScore,
      sentiment: parsed.sentiment,
      language: parsed.language,
      readingMinutes: parsed.readingMinutes,
      contentType: parsed.contentType,
      model: completion.model,
      inputTokens: completion.inputTokens,
      outputTokens: completion.outputTokens,
      raw: completion.json,
    );
  }

  Future<String> ask({
    required String question,
    required List<AiContext> contexts,
    String language = '中文',
  }) async {
    if (contexts.isEmpty) throw AiException('知识库为空，先采集一些内容再提问');
    final buf = StringBuffer();
    for (var i = 0; i < contexts.length; i++) {
      final c = contexts[i];
      buf.writeln('[${i + 1}] ${c.title}');
      buf.writeln('URL: ${c.url}');
      if (c.summary.isNotEmpty) buf.writeln('摘要：${c.summary}');
      if (c.content.isNotEmpty) buf.writeln('内容：${truncate(c.content, 1800)}');
      buf.writeln();
    }
    final c = await _complete(
      messages: [
        {
          'role': 'system',
          'content': '你是 Nexus 个人知识库助手。只根据提供的资料回答，使用$language，'
              '引用资料时用 [1][2] 标注。资料不足时明确说明，不要编造。回答控制在 500 字以内。',
        },
        {'role': 'user', 'content': '问题：$question\n\n资料：\n$buf'},
      ],
      maxTokens: 1100,
      temperature: 0.35,
    );
    return c.content.trim();
  }

  Future<String> briefing({
    required List<AiContext> contexts,
    String language = '中文',
  }) async {
    if (contexts.isEmpty) throw AiException('还没有可分析的内容');
    final buf = StringBuffer();
    for (var i = 0; i < contexts.length; i++) {
      final c = contexts[i];
      buf.writeln('${i + 1}. ${c.title}');
      buf.writeln('摘要：${c.summary}');
      if (c.content.isNotEmpty) buf.writeln('补充：${truncate(c.content, 600)}');
      buf.writeln();
    }
    final c = await _complete(
      messages: [
        {
          'role': 'system',
          'content': '你是 Nexus 情报主编。基于今日的高价值信息，写一份$language情报简报。'
              '分三段：① 今日主线（2-3 句）② 值得深读（3 条，带编号）③ 弱信号（1-2 条）。'
              '只使用给定材料，不要编造，总字数 350 字以内。不要使用 Markdown 标题符号。',
        },
        {'role': 'user', 'content': '今日材料：\n$buf'},
      ],
      maxTokens: 1000,
      temperature: 0.4,
    );
    return c.content.trim();
  }

  Future<Map<String, dynamic>> suggestMetrics({
    required String columns,
    required String sampleRows,
    required List<Map<String, String>> catalog,
    String language = '中文',
  }) async {
    final c = await _completeJson(
      system: '你是计量经济学与数据科学助教。你只能从给定指标目录中选择 key，绝不能发明指标或公式。'
          '同时判断数据是否支持该指标；不支持就不要选。只输出 JSON。',
      user: '数据列：\n$columns\n\n样例行：\n$sampleRows\n\n'
          '可用指标目录（key | 名称 | 公式 | 假设）：\n'
          '${catalog.map((e) => '${e['key']} | ${e['name']} | ${e['formula']} | ${e['assumption']}').join('\n')}\n\n'
          '请返回：\n'
          '{\n'
          '  "metrics": [{"key": "目录里的 key", "value_column": "列名", "x_column": "可选列名", "y_column": "可选列名", "reason": "为什么适合，30 字内"}],\n'
          '  "theories": ["solow_tfp", "cobb_douglas", "moore", "metcalfe", "digital_share", "hhi", "gini"],\n'
          '  "summary": "这组数据最适合做的 2-3 个分析方向"\n'
          '}\n'
          'theories 只能从给定 key 中选；如果没有合适的就返回空数组。所有解释使用$language。',
      maxTokens: 1200,
    );
    return c.json;
  }

  Future<String> interpretDataset({
    required String context,
    String language = '中文',
  }) async {
    final c = await _complete(
      messages: [
        {
          'role': 'system',
          'content': '你是 Nexus 的数据分析助手。只根据用户提供的计算结果和数据片段解释，'
              '禁止编造任何数值、公式或因果关系。若证据不足，明确说“数据不足以判断”。'
              '引用数值时必须与提供的结果一致。使用$language，400 字以内，分“趋势 / 结构 / 风险 / 可继续验证”四点。',
        },
        {'role': 'user', 'content': context},
      ],
      maxTokens: 1000,
      temperature: 0.3,
    );
    return c.content.trim();
  }

  String _analysisSystem(String language) => '''
你是 Nexus 情报分析引擎，任务是把网页内容压缩成高密度、可检索、可排序的结构化情报。
只输出合法 JSON，不要输出 Markdown 代码块，不要输出解释。

字段定义：
{
  "summary": "80-180 字的高密度摘要，说明发生了什么、关键事实、为什么重要；不要空话",
  "key_points": ["3-5 条关键信息，每条不超过 45 字"],
  "category": "只能从以下选一个：AI与科技、商业与金融、产品与设计、编程与工程、科学与研究、社会与文化、生活与健康、资讯与其他",
  "tags": ["3-6 个具体标签，不要泛词"],
  "entities": [{"name": "实体名", "type": "person|org|product|place|event|other"}],
  "value_score": "0-100 的整数。90+ 一手/深度/重大变化；70-89 有洞察可行动；50-69 常规新闻；0-49 噪音/广告/重复",
  "sentiment": "positive|neutral|negative",
  "language": "原文语言代码，如 zh、en",
  "reading_minutes": "整数，1-60",
  "why_valuable": "一句话：对关注科技、产品、商业的人为什么值得读；若是噪音直接说明",
  "content_type": "news|analysis|tutorial|opinion|research|product|other"
}

所有文本字段使用$language。必须基于原文，不得编造事实。''';

  Future<JsonCompletion> _completeJson({
    required String system,
    required String user,
    required int maxTokens,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      final c = await _complete(
        messages: [
          {'role': 'system', 'content': system},
          {
            'role': 'user',
            'content': attempt == 0
                ? user
                : '$user\n\n注意：上一次输出不是合法 JSON。请严格只输出一个 JSON 对象。',
          },
        ],
        maxTokens: maxTokens,
        temperature: 0.15,
        jsonMode: true,
      );
      try {
        final json = jsonDecode(_extractJson(c.content));
        if (json is! Map<String, dynamic>) throw const FormatException('根节点不是对象');
        return JsonCompletion(
          json: json,
          inputTokens: c.inputTokens,
          outputTokens: c.outputTokens,
          model: c.model,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw AiException('AI 返回的 JSON 无法解析：$lastError');
  }

  Future<_Completion> _complete({
    required List<Map<String, String>> messages,
    required int maxTokens,
    double temperature = 0.3,
    bool jsonMode = false,
  }) async {
    if (apiKey.trim().isEmpty) throw AiException('请先在设置中填写 DeepSeek API Key');
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
    };
    if (jsonMode && !_isReasoner) {
      body['response_format'] = {'type': 'json_object'};
    }
    dynamic data;
    try {
      final res = await _dio.post<String>(_endpoint, data: jsonEncode(body));
      final status = res.statusCode ?? 0;
      if (status != 200) {
        throw AiException(_describe(status, res.data));
      }
      data = jsonDecode(res.data ?? '{}');
    } on DioException catch (e) {
      throw AiException(_describeDio(e));
    }
    if (data is! Map) throw AiException('DeepSeek 返回格式异常');
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) throw AiException('DeepSeek 没有返回结果');
    final message = choices.first is Map ? (choices.first as Map)['message'] : null;
    final content = message is Map ? (message['content'] ?? '').toString() : '';
    final usage = data['usage'];
    final inputTokens = usage is Map ? (usage['prompt_tokens'] as num?)?.toInt() ?? 0 : 0;
    final outputTokens = usage is Map ? (usage['completion_tokens'] as num?)?.toInt() ?? 0 : 0;
    return _Completion(content, inputTokens, outputTokens, model);
  }

  String _extractJson(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) t = t.substring(start, end + 1);
    return t.trim();
  }

  String _describe(int status, String? body) {
    var detail = '';
    try {
      final m = jsonDecode(body ?? '{}');
      if (m is Map && m['error'] is Map) detail = (m['error']['message'] ?? '').toString();
    } catch (_) {}
    if (status == 401) return 'DeepSeek API Key 无效（401）';
    if (status == 402) return 'DeepSeek 账户余额不足（402）';
    if (status == 429) return '请求过于频繁（429），请稍后再试';
    if (status == 400) return '请求参数错误（400）${detail.isEmpty ? '' : '：$detail'}';
    return 'DeepSeek 请求失败（$status）${detail.isEmpty ? '' : '：$detail'}';
  }

  String _describeDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'DeepSeek 连接超时，请检查网络或代理';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接 DeepSeek，请检查网络或代理设置';
    }
    return 'DeepSeek 网络错误：${e.message ?? e.type.name}';
  }
}
