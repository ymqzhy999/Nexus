import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crawler/site_crawler.dart';
import '../data/database.dart';
import '../data/datasets_repository.dart';
import '../data/table_data.dart';

class CrawlState {
  final bool running;
  final int? jobId;
  final int pages;
  final int pagesSaved;
  final int queued;
  final int tables;
  final int datasets;
  final String current;
  final List<String> errors;
  final bool finished;
  final String? error;

  const CrawlState({
    this.running = false,
    this.jobId,
    this.pages = 0,
    this.pagesSaved = 0,
    this.queued = 0,
    this.tables = 0,
    this.datasets = 0,
    this.current = '',
    this.errors = const [],
    this.finished = false,
    this.error,
  });
}

class CrawlController extends StateNotifier<CrawlState> {
  final AppDatabase db;
  final DatasetsRepository datasets;
  final SiteCrawler crawler;
  bool _cancelled = false;

  CrawlController({
    required this.db,
    required this.datasets,
    required this.crawler,
  }) : super(const CrawlState());

  Future<void> start({
    required String keyword,
    required List<String> seeds,
    required int maxPages,
    required int maxDepth,
    int? startYear,
    int? endYear,
  }) async {
    if (state.running) return;
    final cleanSeeds = seeds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (cleanSeeds.isEmpty) {
      state = const CrawlState(error: '没有可爬取的站点，请先在站点库选择或填写 URL', finished: true);
      return;
    }
    _cancelled = false;
    final jobId = await db.into(db.crawlJobs).insert(CrawlJobsCompanion.insert(
          keyword: keyword.trim(),
          seedsJson: Value(jsonEncode(cleanSeeds)),
          configJson: Value(jsonEncode({
            'max_pages': maxPages,
            'max_depth': maxDepth,
            'start_year': startYear,
            'end_year': endYear,
          })),
        ));
    state = CrawlState(running: true, jobId: jobId, current: '准备爬取…');

    try {
      final outcome = await crawler.crawl(
        CrawlConfig(
          keyword: keyword.trim(),
          seeds: cleanSeeds,
          maxPages: maxPages,
          maxDepth: maxDepth,
          startYear: startYear,
          endYear: endYear,
        ),
        onProgress: (p) {
          if (!mounted) return;
          state = CrawlState(
            running: true,
            jobId: jobId,
            pages: p.pages,
            pagesSaved: p.pagesSaved,
            queued: p.queued,
            tables: p.tables,
            datasets: p.datasets,
            current: p.current,
            errors: p.errors,
          );
          if (p.pages % 5 == 0) {
            _updateJob(jobId, p.pages, p.pagesSaved, p.tables, p.datasets, p.errors, 'running');
          }
        },
        onPage: (page) async {
          await db.into(db.capturedPages).insert(CapturedPagesCompanion.insert(
            jobId: Value(jobId),
            url: page.url,
            title: Value(page.title),
            domain: Value(page.domain),
            text: Value(page.text),
            excerpt: Value(page.excerpt),
            status: Value(page.status),
            httpStatus: Value(page.httpStatus),
            tableCount: Value(page.tableCount),
            attachmentsJson: Value(jsonEncode(page.attachments.map((e) => e.toJson()).toList())),
            keyword: Value(keyword.trim()),
            matched: Value(page.matched),
          ));
          return true;
        },
        onTable: (table) async {
          final withMeta = TableData(
            title: table.title,
            sourceUrl: table.sourceUrl,
            sourceName: table.sourceName,
            headers: table.headers,
            rows: table.rows,
            meta: {
              ...table.meta,
              'job_id': jobId,
              'keyword': keyword.trim(),
            },
          );
          await datasets.saveDataset(withMeta);
          return true;
        },
        isCancelled: () => _cancelled,
      );
      final status = outcome.cancelled ? 'cancelled' : 'done';
      await _updateJob(jobId, outcome.pages, outcome.pagesSaved, outcome.tables, outcome.datasets, outcome.errors, status, finished: true);
      if (!mounted) return;
      state = CrawlState(
        jobId: jobId,
        pages: outcome.pages,
        pagesSaved: outcome.pagesSaved,
        tables: outcome.tables,
        datasets: outcome.datasets,
        errors: outcome.errors,
        finished: true,
      );
    } catch (e) {
      await _updateJob(jobId, state.pages, state.pagesSaved, state.tables, state.datasets, [...state.errors, e.toString()], 'failed', finished: true);
      if (!mounted) return;
      state = CrawlState(
        jobId: jobId,
        pages: state.pages,
        pagesSaved: state.pagesSaved,
        tables: state.tables,
        datasets: state.datasets,
        errors: [...state.errors, e.toString()],
        finished: true,
        error: e.toString(),
      );
    }
  }

  void cancel() {
    _cancelled = true;
  }

  Future<void> _updateJob(
    int jobId,
    int pages,
    int pagesSaved,
    int tables,
    int datasets,
    List<String> errors,
    String status, {
    bool finished = false,
  }) async {
    await (db.update(db.crawlJobs)..where((t) => t.id.equals(jobId))).write(CrawlJobsCompanion(
      pages: Value(pages),
      pagesSaved: Value(pagesSaved),
      tablesFound: Value(tables),
      datasetsSaved: Value(datasets),
      errorsJson: Value(jsonEncode(errors.take(30).toList())),
      status: Value(status),
      finishedAt: finished ? Value<DateTime?>(DateTime.now()) : const Value<DateTime?>.absent(),
    ));
  }

  Future<void> deleteJob(int id) async {
    await (db.delete(db.crawlJobs)..where((t) => t.id.equals(id))).go();
  }
}
