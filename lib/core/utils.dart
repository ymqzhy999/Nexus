import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'models.dart';

String sha1Hex(String input) => sha1.convert(utf8.encode(input)).toString();

String normalizeUrl(String raw, {String? base}) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  if (base != null && base.isNotEmpty) {
    final b = Uri.tryParse(base);
    final u = Uri.tryParse(value);
    if (b != null && u != null && !u.hasScheme) {
      value = b.resolveUri(u).toString();
    }
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  const tracking = {
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'fbclid', 'gclid', 'spm', 'ref', 'ref_src', 'share_token', 'from',
  };
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((k, v) => tracking.contains(k.toLowerCase()));
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  final auth = uri.userInfo.isEmpty ? '' : '${uri.userInfo}@';
  final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
  return '${uri.scheme.toLowerCase()}://$auth${uri.host.toLowerCase()}$port$path$qs';
}

String cleanText(String input) {
  var s = input
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t\u00a0]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
  return s.trim();
}

String truncate(String input, int max) {
  if (input.length <= max) return input;
  return '${input.substring(0, max).trimRight()}…';
}

String prettyDate(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String fullDate(DateTime? d) {
  if (d == null) return '未知时间';
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime? parseFlexibleDate(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  final direct = DateTime.tryParse(s);
  if (direct != null) return direct;
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})').firstMatch(s);
  if (m != null) {
    final month = months[m.group(2)!.toLowerCase()];
    if (month != null) {
      return DateTime.tryParse(
          '${m.group(3)}-${month.toString().padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}');
    }
  }
  final n = RegExp(r'([A-Za-z]{3})[a-z]*\s+(\d{1,2}),?\s+(\d{4})').firstMatch(s);
  if (n != null) {
    final month = months[n.group(1)!.toLowerCase()];
    if (month != null) {
      return DateTime.tryParse(
          '${n.group(3)}-${month.toString().padLeft(2, '0')}-${n.group(2)!.padLeft(2, '0')}');
    }
  }
  return null;
}

List<String> decodeTags(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  } catch (_) {}
  return const [];
}

Color categoryColor(String category) {
  if (category.contains('AI') || category.contains('科技')) return const Color(0xFF22D3EE);
  if (category.contains('商业') || category.contains('金融')) return const Color(0xFFFBBF24);
  if (category.contains('产品') || category.contains('设计')) return const Color(0xFFF472B6);
  if (category.contains('编程') || category.contains('工程')) return const Color(0xFFA3E635);
  if (category.contains('科学') || category.contains('研究')) return const Color(0xFFA78BFA);
  if (category.contains('社会') || category.contains('文化')) return const Color(0xFF60A5FA);
  if (category.contains('生活') || category.contains('健康')) return const Color(0xFF34D399);
  return const Color(0xFF94A3B8);
}

IconData categoryIcon(String category) {
  if (category.contains('AI') || category.contains('科技')) return Icons.memory;
  if (category.contains('商业') || category.contains('金融')) return Icons.trending_up;
  if (category.contains('产品') || category.contains('设计')) return Icons.auto_awesome_mosaic;
  if (category.contains('编程') || category.contains('工程')) return Icons.terminal;
  if (category.contains('科学') || category.contains('研究')) return Icons.science_outlined;
  if (category.contains('社会') || category.contains('文化')) return Icons.public;
  if (category.contains('生活') || category.contains('健康')) return Icons.spa_outlined;
  return Icons.article_outlined;
}

String scoreLabel(int score) {
  if (score >= 85) return '核心信号';
  if (score >= 70) return '高价值';
  if (score >= 50) return '值得一看';
  if (score > 0) return '一般';
  return '待分析';
}

List<String> topTags(List<String> tags, {int n = 4}) => tags.take(n).toList();

String sourceHost(String url) {
  final uri = Uri.tryParse(url);
  return (uri?.host ?? url).replaceFirst('www.', '');
}

AiResult? aiResultFromJson(Map<String, dynamic> json) {
  final summary = (json['summary'] ?? '').toString().trim();
  if (summary.isEmpty) return null;
  final tags = _stringList(json['tags']);
  final points = _stringList(json['key_points']);
  final rawEntities = json['entities'];
  final entities = rawEntities is List
      ? rawEntities
          .whereType<Map>()
          .map((e) => AiEntity.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList()
      : <AiEntity>[];
  final score = _intValue(json['value_score'], 50);
  return AiResult(
    summary: summary,
    whyValuable: (json['why_valuable'] ?? '').toString(),
    keyPoints: points,
    category: (json['category'] ?? '未分类').toString(),
    tags: tags,
    entities: entities,
    valueScore: score.clamp(0, 100).toInt(),
    sentiment: (json['sentiment'] ?? 'neutral').toString(),
    language: (json['language'] ?? 'zh').toString(),
    readingMinutes: _intValue(json['reading_minutes'], 1).clamp(1, 120).toInt(),
    contentType: (json['content_type'] ?? 'other').toString(),
  );
}


int _intValue(dynamic v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) {
    final m = RegExp(r'-?\d+').firstMatch(v);
    return m == null ? fallback : int.tryParse(m.group(0)!) ?? fallback;
  }
  return fallback;
}

List<String> _stringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) {
    return v.split(RegExp(r'[,，、]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}
