import 'package:flutter/material.dart';

enum SourceKind { auto, rss, atom, sitemap, jsonApi, html }

extension SourceKindX on SourceKind {
  String get label => switch (this) {
        SourceKind.auto => '自动识别',
        SourceKind.rss => 'RSS',
        SourceKind.atom => 'Atom',
        SourceKind.sitemap => 'Sitemap',
        SourceKind.jsonApi => 'JSON API',
        SourceKind.html => '网页',
      };

  IconData get icon => switch (this) {
        SourceKind.auto => Icons.auto_awesome,
        SourceKind.rss => Icons.rss_feed,
        SourceKind.atom => Icons.rss_feed,
        SourceKind.sitemap => Icons.account_tree_outlined,
        SourceKind.jsonApi => Icons.data_object,
        SourceKind.html => Icons.language,
      };

  static SourceKind parse(String? raw) => SourceKind.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => SourceKind.html,
      );
}

class CrawlItem {
  final String url;
  final String title;
  final String content;
  final String excerpt;
  final String author;
  final String imageUrl;
  final String language;
  final DateTime? publishedAt;
  final String raw;

  const CrawlItem({
    required this.url,
    required this.title,
    this.content = '',
    this.excerpt = '',
    this.author = '',
    this.imageUrl = '',
    this.language = '',
    this.publishedAt,
    this.raw = '',
  });
}

class CrawlOutcome {
  final SourceKind kind;
  final String feedTitle;
  final List<CrawlItem> items;
  final String note;

  const CrawlOutcome({
    required this.kind,
    required this.items,
    this.feedTitle = '',
    this.note = '',
  });
}

class AiEntity {
  final String name;
  final String type;

  const AiEntity({required this.name, this.type = 'other'});

  factory AiEntity.fromJson(Map<String, dynamic> json) => AiEntity(
        name: (json['name'] ?? '').toString().trim(),
        type: (json['type'] ?? 'other').toString(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type};
}

class AiResult {
  final String summary;
  final String whyValuable;
  final List<String> keyPoints;
  final String category;
  final List<String> tags;
  final List<AiEntity> entities;
  final int valueScore;
  final String sentiment;
  final String language;
  final int readingMinutes;
  final String contentType;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final Map<String, dynamic> raw;

  const AiResult({
    required this.summary,
    this.whyValuable = '',
    this.keyPoints = const [],
    this.category = '未分类',
    this.tags = const [],
    this.entities = const [],
    this.valueScore = 50,
    this.sentiment = 'neutral',
    this.language = 'zh',
    this.readingMinutes = 1,
    this.contentType = 'other',
    this.model = '',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.raw = const {},
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'why_valuable': whyValuable,
        'key_points': keyPoints,
        'category': category,
        'tags': tags,
        'entities': entities.map((e) => e.toJson()).toList(),
        'value_score': valueScore,
        'sentiment': sentiment,
        'language': language,
        'reading_minutes': readingMinutes,
        'content_type': contentType,
      };
}

class AiUsage {
  final int inputTokens;
  final int outputTokens;
  final int calls;

  const AiUsage({this.inputTokens = 0, this.outputTokens = 0, this.calls = 0});

  int get total => inputTokens + outputTokens;
}

class AppSettings {
  final String apiKey;
  final String model;
  final String baseUrl;
  final bool autoAnalyze;
  final int maxItemsPerRun;
  final int maxAiPerRun;
  final bool proxyEnabled;
  final String proxyUrl;
  final bool backgroundSync;
  final String outputLanguage;

  const AppSettings({
    this.apiKey = '',
    this.model = 'deepseek-chat',
    this.baseUrl = 'https://api.deepseek.com',
    this.autoAnalyze = true,
    this.maxItemsPerRun = 20,
    this.maxAiPerRun = 5,
    this.proxyEnabled = false,
    this.proxyUrl = '',
    this.backgroundSync = false,
    this.outputLanguage = '中文',
  });

  bool get hasKey => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    String? model,
    String? baseUrl,
    bool? autoAnalyze,
    int? maxItemsPerRun,
    int? maxAiPerRun,
    bool? proxyEnabled,
    String? proxyUrl,
    bool? backgroundSync,
    String? outputLanguage,
  }) =>
      AppSettings(
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        baseUrl: baseUrl ?? this.baseUrl,
        autoAnalyze: autoAnalyze ?? this.autoAnalyze,
        maxItemsPerRun: maxItemsPerRun ?? this.maxItemsPerRun,
        maxAiPerRun: maxAiPerRun ?? this.maxAiPerRun,
        proxyEnabled: proxyEnabled ?? this.proxyEnabled,
        proxyUrl: proxyUrl ?? this.proxyUrl,
        backgroundSync: backgroundSync ?? this.backgroundSync,
        outputLanguage: outputLanguage ?? this.outputLanguage,
      );
}

enum FeedFilter { all, highValue, unread, saved }

enum FeedSort { value, latest }

extension FeedFilterX on FeedFilter {
  String get label => switch (this) {
        FeedFilter.all => '全部',
        FeedFilter.highValue => '高价值',
        FeedFilter.unread => '未读',
        FeedFilter.saved => '收藏',
      };
}

class AppStats {
  final int documents;
  final int sources;
  final int highValue;
  final int analyzed;
  final double avgScore;

  const AppStats({
    this.documents = 0,
    this.sources = 0,
    this.highValue = 0,
    this.analyzed = 0,
    this.avgScore = 0,
  });
}

class CategoryStat {
  final String category;
  final int count;

  const CategoryStat(this.category, this.count);
}
