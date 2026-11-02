import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/analysis_service.dart';
import '../ai/deepseek.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/utils.dart';
import '../catalog/catalog.dart';
import '../crawl/engine.dart';
import '../crawl/http_client.dart';
import '../data/database.dart';
import '../data/datasets_repository.dart';
import '../data/repository.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final repositoryProvider = Provider<NexusRepository>((ref) => NexusRepository(ref.watch(dbProvider)));

final httpFetcherProvider = Provider<HttpFetcher>((ref) {
  final s = ref.watch(appSettingsProvider);
  return HttpFetcher(proxyUrl: s.proxyEnabled ? s.proxyUrl : null);
});

final crawlEngineProvider = Provider<CrawlEngine>((ref) => CrawlEngine(ref.watch(httpFetcherProvider)));

final deepSeekClientProvider = Provider<DeepSeekClient>((ref) {
  final s = ref.watch(appSettingsProvider);
  return DeepSeekClient(
    apiKey: s.apiKey,
    baseUrl: s.baseUrl,
    model: s.model,
    proxyUrl: s.proxyEnabled ? s.proxyUrl : '',
  );
});

final feedFilterProvider = StateProvider<FeedFilter>((ref) => FeedFilter.all);
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.value);

final feedDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final filter = ref.watch(feedFilterProvider);
  final sort = ref.watch(feedSortProvider);
  return repo.watchDocuments(filter, sort: sort);
});

final sourcesProvider = StreamProvider<List<Source>>((ref) {
  return ref.watch(repositoryProvider).watchSources();
});

final statsProvider = StreamProvider<AppStats>((ref) {
  return ref.watch(dbProvider).watchStats();
});

final documentProvider = FutureProvider.family<Document?, int>((ref, id) {
  return ref.watch(repositoryProvider).getDocument(id);
});

final categoriesProvider = FutureProvider<List<CategoryStat>>((ref) {
  return ref.watch(repositoryProvider).categories();
});

final libraryDocsProvider = FutureProvider<List<Document>>((ref) {
  return ref.watch(repositoryProvider).allDocuments(limit: 500);
});

final usageProvider = FutureProvider<AiUsage>((ref) {
  return ref.watch(repositoryProvider).usage();
});

final datasetsRepositoryProvider = Provider<DatasetsRepository>((ref) {
  return DatasetsRepository(ref.watch(dbProvider));
});

final datasetsProvider = StreamProvider<List<Dataset>>((ref) {
  return ref.watch(datasetsRepositoryProvider).watchDatasets();
});

final datasetProvider = FutureProvider.family<Dataset?, int>((ref, id) {
  return ref.watch(datasetsRepositoryProvider).getDataset(id);
});

final datasetAnalysisProvider = FutureProvider.family<DataAnalysis?, int>((ref, id) {
  return ref.watch(datasetsRepositoryProvider).latestAnalysis(id);
});

class AiQueueState {
  final bool running;
  final int done;
  final int total;
  final int analyzed;
  final int failed;
  final int tokens;
  final String? error;

  const AiQueueState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.analyzed = 0,
    this.failed = 0,
    this.tokens = 0,
    this.error,
  });
}

class AiQueueController extends StateNotifier<AiQueueState> {
  final Ref ref;

  AiQueueController(this.ref) : super(const AiQueueState());

  Future<void> run({int limit = 5}) async {
    if (state.running) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      state = const AiQueueState(error: '未配置 DeepSeek API Key');
      return;
    }
    state = AiQueueState(running: true, total: limit);
    try {
      final service = AnalysisService(
        repo: ref.read(repositoryProvider),
        client: ref.read(deepSeekClientProvider),
        language: settings.outputLanguage,
      );
      final report = await service.analyzePending(
        limit: limit,
        onProgress: (done, total) {
          if (!mounted) return;
          state = AiQueueState(
            running: true,
            done: done,
            total: total,
            analyzed: state.analyzed,
            failed: state.failed,
          );
        },
      );
      if (!mounted) return;
      state = AiQueueState(
        analyzed: report.analyzed,
        failed: report.failed,
        tokens: report.inputTokens + report.outputTokens,
        error: report.fatal ?? (report.errors.isEmpty ? null : report.errors.last),
      );
    } catch (e) {
      if (!mounted) return;
      state = AiQueueState(error: e.toString());
    }
  }

  Future<void> runOne(int documentId) async {
    if (state.running) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      state = const AiQueueState(error: '未配置 DeepSeek API Key');
      return;
    }
    final doc = await ref.read(repositoryProvider).getDocument(documentId);
    if (doc == null) return;
    state = const AiQueueState(running: true, total: 1);
    try {
      final service = AnalysisService(
        repo: ref.read(repositoryProvider),
        client: ref.read(deepSeekClientProvider),
        language: settings.outputLanguage,
      );
      final r = await service.analyzeOne(doc);
      if (!mounted) return;
      state = AiQueueState(
        analyzed: 1,
        tokens: r.inputTokens + r.outputTokens,
      );
    } catch (e) {
      if (!mounted) return;
      state = AiQueueState(error: e.toString());
    }
  }
}

final aiQueueProvider = StateNotifierProvider<AiQueueController, AiQueueState>(
  (ref) => AiQueueController(ref),
);

class IngestState {
  final bool running;
  final String phase;
  final String? error;
  final String? note;
  final int found;
  final int added;
  final int? sourceId;

  const IngestState({
    this.running = false,
    this.phase = '',
    this.error,
    this.note,
    this.found = 0,
    this.added = 0,
    this.sourceId,
  });

  IngestState copyWith({
    bool? running,
    String? phase,
    String? error,
    String? note,
    int? found,
    int? added,
    int? sourceId,
  }) =>
      IngestState(
        running: running ?? this.running,
        phase: phase ?? this.phase,
        error: error ?? this.error,
        note: note ?? this.note,
        found: found ?? this.found,
        added: added ?? this.added,
        sourceId: sourceId ?? this.sourceId,
      );
}

class IngestController extends StateNotifier<IngestState> {
  final Ref ref;

  IngestController(this.ref) : super(const IngestState());

  Future<void> addSource(String rawUrl, {SourceKind hint = SourceKind.auto, String keyword = ''}) async {
    if (state.running) return;
    final clean = normalizeUrl(rawUrl);
    if (clean.isEmpty) {
      state = const IngestState(error: '请输入有效网址');
      return;
    }
    final kw = keyword.trim();
    final meta = SourceMeta(keyword: kw, fetchUrl: clean);
    final config = meta.toConfig();
    final repo = ref.read(repositoryProvider);
    final existing = await repo.findSourceByUrlAndConfig(clean, config);
    if (existing != null) {
      await refreshSource(existing);
      return;
    }
    final settings = ref.read(appSettingsProvider);
    final engine = ref.read(crawlEngineProvider);
    state = const IngestState(running: true, phase: '连接并识别来源…');
    Source? source;
    int? runId;
    try {
      final outcome = await engine.crawl(clean, hint: hint, limit: settings.maxItemsPerRun);
      var items = outcome.items;
      if (kw.isNotEmpty) items = filterByKeyword(items, kw);
      if (items.isEmpty) {
        throw Exception(kw.isEmpty ? '没有抓取到内容' : '没有匹配「$kw」的内容');
      }
      state = IngestState(running: true, phase: '建立来源…', note: outcome.note, found: items.length);
      final created = await repo.createSource(
        url: clean,
        name: outcome.feedTitle.isEmpty ? sourceHost(clean) : '${outcome.feedTitle}${kw.isEmpty ? '' : ' · $kw'}',
        kind: outcome.kind,
        config: config,
      );
      source = created;
      runId = await repo.startRun(created.id);
      var added = 0;
      for (final item in items) {
        final r = await repo.saveItem(source: created, item: item, kind: outcome.kind);
        if (r.isNew) added++;
        state = state.copyWith(phase: '写入本地库 ${added}/${items.length}');
      }
      await repo.finishRun(
        runId,
        sourceId: created.id,
        found: items.length,
        added: added,
        sourceName: created.name,
        kind: outcome.kind,
      );
      state = IngestState(
        phase: '已入库 $added 条${kw.isEmpty ? '' : ' · 关键词「$kw」'}',
        note: outcome.note,
        found: items.length,
        added: added,
        sourceId: created.id,
      );
      await _maybeAnalyze(settings, added);
    } catch (e) {
      if (source != null && runId != null) {
        try {
          await repo.finishRun(runId, sourceId: source.id, found: 0, added: 0, error: e.toString());
        } catch (_) {}
      }
      state = IngestState(error: e.toString(), phase: '失败');
    }
  }

  Future<void> refreshSource(Source source) async {
    if (state.running) return;
    final settings = ref.read(appSettingsProvider);
    state = IngestState(running: true, phase: '刷新 ${source.name}…', sourceId: source.id);
    await _refreshOne(source, settings);
  }

  Future<void> refreshAll() async {
    if (state.running) return;
    final settings = ref.read(appSettingsProvider);
    final repo = ref.read(repositoryProvider);
    final sources = await repo.dueSources();
    if (sources.isEmpty) {
      state = const IngestState(phase: '没有到期的来源');
      return;
    }
    state = IngestState(running: true, phase: '开始检查 ${sources.length} 个来源…');
    var added = 0;
    for (var i = 0; i < sources.length; i++) {
      state = state.copyWith(phase: '刷新 ${i + 1}/${sources.length}：${sources[i].name}');
      added += await _refreshOne(sources[i], settings, quiet: true, analyze: false);
    }
    state = IngestState(phase: '完成，新增 $added 条', added: added);
    await _maybeAnalyze(settings, added);
  }

  Future<int> _refreshOne(
    Source source,
    AppSettings settings, {
    bool quiet = false,
    bool analyze = true,
  }) async {
    final repo = ref.read(repositoryProvider);
    final engine = ref.read(crawlEngineProvider);
    int? runId;
    try {
      runId = await repo.startRun(source.id);
      final meta = SourceMeta.fromConfig(source.config);
      final fetchUrl = meta.fetchUrl.isNotEmpty ? meta.fetchUrl : source.url;
      final outcome = await engine.crawl(
        fetchUrl,
        hint: SourceKindX.parse(source.kind),
        limit: settings.maxItemsPerRun,
      );
      var items = outcome.items;
      if (meta.hasKeyword) items = filterByKeyword(items, meta.keyword);
      if (items.isEmpty) {
        await repo.finishRun(
          runId,
          sourceId: source.id,
          found: 0,
          added: 0,
          sourceName: source.name,
          kind: SourceKindX.parse(source.kind),
        );
        if (!quiet) {
          state = IngestState(
            phase: meta.hasKeyword ? '没有匹配「${meta.keyword}」的新内容' : '这次没有新内容',
            sourceId: source.id,
          );
        }
        return 0;
      }
      var added = 0;
      for (final item in items) {
        final r = await repo.saveItem(source: source, item: item, kind: outcome.kind);
        if (r.isNew) added++;
      }
      await repo.finishRun(
        runId,
        sourceId: source.id,
        found: items.length,
        added: added,
        sourceName: outcome.feedTitle.isEmpty ? source.name : outcome.feedTitle,
        kind: outcome.kind,
      );
      if (!quiet) {
        state = IngestState(
          phase: '已新增 $added 条',
          added: added,
          found: outcome.items.length,
          note: outcome.note,
          sourceId: source.id,
        );
      }
      if (analyze) await _maybeAnalyze(settings, added);
      return added;
    } catch (e) {
      if (runId != null) {
        try {
          await repo.finishRun(runId, sourceId: source.id, found: 0, added: 0, error: e.toString());
        } catch (_) {}
      }
      if (!quiet) {
        state = IngestState(error: e.toString(), phase: '刷新失败', sourceId: source.id);
      }
      return 0;
    }
  }

  Future<void> _maybeAnalyze(AppSettings settings, int added) async {
    if (!settings.autoAnalyze || !settings.hasKey || added <= 0) return;
    state = state.copyWith(phase: 'AI 正在分析…');
    await ref.read(aiQueueProvider.notifier).run(limit: math.min(settings.maxAiPerRun, added));
  }
}

final ingestProvider = StateNotifierProvider<IngestController, IngestState>(
  (ref) => IngestController(ref),
);

class SearchState {
  final bool loading;
  final String query;
  final List<Document> results;
  final String? error;

  const SearchState({
    this.loading = false,
    this.query = '',
    this.results = const [],
    this.error,
  });
}

class SearchController extends StateNotifier<SearchState> {
  final Ref ref;

  SearchController(this.ref) : super(const SearchState());

  Future<void> run(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = const SearchState();
      return;
    }
    state = SearchState(loading: true, query: q);
    try {
      final docs = await ref.read(repositoryProvider).search(q);
      if (!mounted) return;
      state = SearchState(query: q, results: docs);
    } catch (e) {
      if (!mounted) return;
      state = SearchState(query: q, error: e.toString());
    }
  }

  void clear() => state = const SearchState();
}

final searchProvider = StateNotifierProvider<SearchController, SearchState>(
  (ref) => SearchController(ref),
);

class BriefingState {
  final bool loading;
  final String text;
  final String? error;
  final DateTime? at;

  const BriefingState({this.loading = false, this.text = '', this.error, this.at});
}

class BriefingController extends StateNotifier<BriefingState> {
  final Ref ref;
  SharedPreferences? _prefs;

  BriefingController(this.ref) : super(const BriefingState()) {
    _loadCached();
  }

  String get _key {
    final now = DateTime.now();
    return 'nexus.briefing.${now.year}${now.month}${now.day}';
  }

  Future<void> _loadCached() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final cached = _prefs!.getString(_key);
      if (cached != null && cached.isNotEmpty && mounted) {
        state = BriefingState(text: cached, at: DateTime.now());
      }
    } catch (_) {}
  }

  Future<void> generate() async {
    if (state.loading) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.hasKey) {
      state = const BriefingState(error: '先在设置里配置 DeepSeek API Key');
      return;
    }
    state = BriefingState(text: state.text, loading: true);
    try {
      final docs = await ref.read(repositoryProvider).topDocuments(limit: 8);
      if (docs.isEmpty) {
        state = const BriefingState(error: '还没有已分析的高价值内容');
        return;
      }
      final contexts = docs
          .map((d) => AiContext(
                title: d.title,
                url: d.url,
                summary: d.summary,
                content: d.content,
              ))
          .toList();
      final text = await ref.read(deepSeekClientProvider).briefing(
            contexts: contexts,
            language: settings.outputLanguage,
          );
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_key, text);
      if (!mounted) return;
      state = BriefingState(text: text, at: DateTime.now());
    } catch (e) {
      if (!mounted) return;
      state = BriefingState(text: state.text, error: e.toString());
    }
  }
}

final briefingProvider = StateNotifierProvider<BriefingController, BriefingState>(
  (ref) => BriefingController(ref),
);


class BatchState {
  final bool running;
  final int total;
  final int done;
  final int added;
  final int failed;
  final String current;
  final List<String> errors;
  final bool finished;

  const BatchState({
    this.running = false,
    this.total = 0,
    this.done = 0,
    this.added = 0,
    this.failed = 0,
    this.current = '',
    this.errors = const [],
    this.finished = false,
  });

  double get progress => total == 0 ? 0 : done / total;
}

class BatchController extends StateNotifier<BatchState> {
  final Ref ref;

  BatchController(this.ref) : super(const BatchState());

  Future<void> run({required List<CatalogSource> sources, required String keyword}) async {
    if (state.running || sources.isEmpty) return;
    final kw = keyword.trim();
    final settings = ref.read(appSettingsProvider);
    final repo = ref.read(repositoryProvider);
    final engine = ref.read(crawlEngineProvider);
    var added = 0;
    var failed = 0;
    var done = 0;
    final errors = <String>[];
    state = BatchState(running: true, total: sources.length, current: '准备采集…');

    for (final src in sources) {
      if (src.keywordOnly && kw.isEmpty) {
        failed++;
        done++;
        errors.add('${src.name}：需要填写关键词');
        state = BatchState(
          running: true,
          total: sources.length,
          done: done,
          added: added,
          failed: failed,
          current: src.name,
          errors: List.of(errors),
        );
        continue;
      }
      final fetchUrl = src.fetchUrl(kw);
      final displayName = '${src.name}${kw.isEmpty ? '' : ' · $kw'}';
      final meta = SourceMeta(
        keyword: kw,
        fetchUrl: fetchUrl,
        searchTemplate: src.searchTemplate,
      );
      final config = meta.toConfig();
      Source? source;
      int? runId;
      state = BatchState(
        running: true,
        total: sources.length,
        done: done,
        added: added,
        failed: failed,
        current: '${src.name} · 抓取中',
        errors: List.of(errors),
      );
      try {
        final created = await repo.ensureSource(
          url: src.url,
          name: displayName,
          kind: src.kind,
          config: config,
        );
        source = created;
        final run = await repo.startRun(created.id);
        runId = run;
        final outcome = await engine.crawl(
          fetchUrl,
          hint: src.kind,
          limit: settings.maxItemsPerRun,
        );
        var items = outcome.items;
        if (kw.isNotEmpty && !src.keywordCapable) {
          items = filterByKeyword(items, kw);
        }
        if (items.isEmpty) {
          await repo.finishRun(
            run,
            sourceId: created.id,
            found: 0,
            added: 0,
            sourceName: displayName,
            kind: outcome.kind,
          );
          failed++;
          done++;
          errors.add('${src.name}：没有匹配内容');
          state = BatchState(
            running: true,
            total: sources.length,
            done: done,
            added: added,
            failed: failed,
            current: src.name,
            errors: List.of(errors),
          );
          continue;
        }
        var localAdded = 0;
        for (final item in items) {
          final r = await repo.saveItem(source: created, item: item, kind: outcome.kind);
          if (r.isNew) localAdded++;
        }
        await repo.finishRun(
          run,
          sourceId: created.id,
          found: items.length,
          added: localAdded,
          sourceName: displayName,
          kind: outcome.kind,
        );
        added += localAdded;
        done++;
        state = BatchState(
          running: true,
          total: sources.length,
          done: done,
          added: added,
          failed: failed,
          current: src.name,
          errors: List.of(errors),
        );
      } catch (e) {
        failed++;
        done++;
        errors.add('${src.name}：$e');
        if (source != null && runId != null) {
          try {
            await repo.finishRun(runId, sourceId: source.id, found: 0, added: 0, error: e.toString());
          } catch (_) {}
        }
        state = BatchState(
          running: true,
          total: sources.length,
          done: done,
          added: added,
          failed: failed,
          current: src.name,
          errors: List.of(errors),
        );
      }
    }

    state = BatchState(
      total: sources.length,
      done: done,
      added: added,
      failed: failed,
      current: '完成',
      errors: List.of(errors),
      finished: true,
    );
    if (added > 0 && settings.autoAnalyze && settings.hasKey) {
      await ref.read(aiQueueProvider.notifier).run(
            limit: math.min(settings.maxAiPerRun, added),
          );
    }
  }

  void reset() => state = const BatchState();
}

final batchProvider = StateNotifierProvider<BatchController, BatchState>(
  (ref) => BatchController(ref),
);
