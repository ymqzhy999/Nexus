import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/models.dart';
import '../core/utils.dart';
import 'database.dart';

class SaveOutcome {
  final int documentId;
  final bool isNew;
  final bool changed;

  const SaveOutcome({required this.documentId, required this.isNew, required this.changed});
}

class NexusRepository {
  final AppDatabase db;

  NexusRepository(this.db);

  Stream<List<Document>> watchDocuments(FeedFilter filter, {FeedSort sort = FeedSort.value}) {
    final q = db.select(db.documents);
    switch (filter) {
      case FeedFilter.all:
        break;
      case FeedFilter.highValue:
        q.where((t) => t.valueScore.isBiggerOrEqualValue(70));
        break;
      case FeedFilter.unread:
        q.where((t) => t.isRead.equals(false));
        break;
      case FeedFilter.saved:
        q.where((t) => t.isBookmarked.equals(true));
        break;
    }
    q.orderBy([
      if (sort == FeedSort.value) (t) => OrderingTerm.desc(t.valueScore),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    q.limit(200);
    return q.watch();
  }

  Stream<List<Source>> watchSources() {
    final q = db.select(db.sources)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch();
  }

  Future<Source?> getSource(int id) =>
      (db.select(db.sources)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Source?> findSourceByUrl(String url) =>
      (db.select(db.sources)..where((t) => t.url.equals(url))).getSingleOrNull();

  Future<Document?> getDocument(int id) =>
      (db.select(db.documents)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Document>> pendingDocuments({int limit = 10}) {
    final q = db.select(db.documents)
      ..where((t) => t.aiStatus.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return q.get();
  }

  Future<List<Source>> dueSources() async {
    final list = await (db.select(db.sources)..where((t) => t.enabled.equals(true))).get();
    final now = DateTime.now();
    return list.where((s) {
      final last = s.lastRunAt;
      if (last == null) return true;
      return now.difference(last).inMinutes >= s.scheduleMinutes;
    }).toList();
  }

  Future<Source> createSource({
    required String url,
    required String name,
    required SourceKind kind,
  }) async {
    final id = await db.into(db.sources).insert(SourcesCompanion.insert(
          url: url,
          name: name.isEmpty ? sourceHost(url) : name,
          kind: Value(kind.name),
        ));
    return (db.select(db.sources)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<SaveOutcome> saveItem({
    required Source source,
    required CrawlItem item,
    required SourceKind kind,
  }) async {
    final url = normalizeUrl(item.url.isEmpty ? source.url : item.url, base: source.url);
    if (url.isEmpty) {
      return const SaveOutcome(documentId: -1, isNew: false, changed: false);
    }
    final urlHash = sha1Hex(url);
    final content = cleanText(item.content.isEmpty ? item.excerpt : item.content);
    final title = cleanText(item.title).isEmpty ? sourceHost(url) : cleanText(item.title);
    final contentHash = sha1Hex('$title|$content');
    final existing = await (db.select(db.documents)..where((t) => t.urlHash.equals(urlHash))).getSingleOrNull();

    if (existing != null) {
      if (existing.contentHash == contentHash) {
        return SaveOutcome(documentId: existing.id, isNew: false, changed: false);
      }
      await (db.update(db.documents)..where((t) => t.id.equals(existing.id))).write(DocumentsCompanion(
        title: Value(title),
        content: Value(content),
        excerpt: Value(item.excerpt.isEmpty ? truncate(content, 220) : cleanText(item.excerpt)),
        author: Value(item.author),
        imageUrl: Value(item.imageUrl),
        language: Value(item.language),
        publishedAt: Value(item.publishedAt ?? existing.publishedAt),
        contentHash: Value(contentHash),
        wordCount: Value(content.length),
        summary: const Value(''),
        whyValuable: const Value(''),
        keyPointsJson: const Value('[]'),
        entitiesJson: const Value('[]'),
        category: const Value('未分类'),
        tagsJson: const Value('[]'),
        valueScore: const Value(0),
        aiStatus: const Value('pending'),
        aiError: const Value(''),
      ));
      await db.indexDocument(existing.id, title, content);
      await _refreshSourceCount(source.id);
      return SaveOutcome(documentId: existing.id, isNew: false, changed: true);
    }

    final rawId = await db.into(db.rawDocuments).insert(RawDocumentsCompanion.insert(
          url: url,
          sourceId: Value(source.id),
          title: Value(title),
          raw: Value(truncate(item.raw.isEmpty ? content : item.raw, 400000)),
          contentHash: Value(contentHash),
        ));

    final id = await db.into(db.documents).insert(DocumentsCompanion.insert(
          url: url,
          urlHash: urlHash,
          title: title,
          sourceId: Value(source.id),
          rawId: Value(rawId),
          content: Value(content),
          excerpt: Value(item.excerpt.isEmpty ? truncate(content, 220) : cleanText(item.excerpt)),
          author: Value(item.author),
          imageUrl: Value(item.imageUrl),
          language: Value(item.language),
          publishedAt: Value(item.publishedAt),
          contentHash: Value(contentHash),
          wordCount: Value(content.length),
          aiStatus: const Value('pending'),
        ));
    await db.indexDocument(id, title, content);
    await _refreshSourceCount(source.id);
    return SaveOutcome(documentId: id, isNew: true, changed: true);
  }

  Future<void> _refreshSourceCount(int sourceId) async {
    await db.customStatement(
      'UPDATE sources SET item_count = (SELECT COUNT(*) FROM documents WHERE source_id = ?) WHERE id = ?',
      [sourceId, sourceId],
    );
  }

  Future<int> startRun(int? sourceId) async {
    final id = await db.into(db.crawlRuns).insert(CrawlRunsCompanion.insert(
          sourceId: Value(sourceId),
        ));
    if (sourceId != null) {
      await (db.update(db.sources)..where((t) => t.id.equals(sourceId))).write(
        SourcesCompanion(lastStatus: const Value('running'), lastError: const Value('')),
      );
    }
    return id;
  }

  Future<void> finishRun(
    int runId, {
    required int sourceId,
    required int found,
    required int added,
    String? error,
    String? sourceName,
    SourceKind? kind,
  }) async {
    final ok = error == null;
    await (db.update(db.crawlRuns)..where((t) => t.id.equals(runId))).write(CrawlRunsCompanion(
      finishedAt: Value(DateTime.now()),
      status: Value(ok ? 'success' : 'failed'),
      itemsFound: Value(found),
      itemsNew: Value(added),
      error: Value(error ?? ''),
    ));
    await (db.update(db.sources)..where((t) => t.id.equals(sourceId))).write(SourcesCompanion(
      lastRunAt: Value(DateTime.now()),
      lastStatus: Value(ok ? 'success' : 'failed'),
      lastError: Value(error ?? ''),
      name: sourceName == null || sourceName.isEmpty ? const Value<String>.absent() : Value(sourceName),
      kind: kind == null ? const Value<String>.absent() : Value(kind.name),
    ));
    await _refreshSourceCount(sourceId);
  }

  Future<void> applyAi(int documentId, AiResult r, String promptVersion) async {
    final raw = jsonEncode(r.raw);
    final tags = jsonEncode(r.tags);
    final points = jsonEncode(r.keyPoints);
    final entities = jsonEncode(r.entities.map((e) => e.toJson()).toList());
    await db.transaction(() async {
      await (db.update(db.documents)..where((t) => t.id.equals(documentId))).write(DocumentsCompanion(
        summary: Value(r.summary),
        whyValuable: Value(r.whyValuable),
        keyPointsJson: Value(points),
        category: Value(r.category),
        tagsJson: Value(tags),
        entitiesJson: Value(entities),
        valueScore: Value(r.valueScore),
        sentiment: Value(r.sentiment),
        language: Value(r.language),
        readingMinutes: Value(r.readingMinutes),
        contentType: Value(r.contentType),
        aiModel: Value(r.model),
        aiStatus: const Value('done'),
        aiError: const Value(''),
        analyzedAt: Value(DateTime.now()),
      ));
      await db.into(db.aiAnalysis).insert(
            AiAnalysisCompanion.insert(
              documentId: documentId,
              summary: Value(r.summary),
              whyValuable: Value(r.whyValuable),
              keyPointsJson: Value(points),
              category: Value(r.category),
              tagsJson: Value(tags),
              entitiesJson: Value(entities),
              valueScore: Value(r.valueScore),
              sentiment: Value(r.sentiment),
              language: Value(r.language),
              readingMinutes: Value(r.readingMinutes),
              contentType: Value(r.contentType),
              model: Value(r.model),
              promptVersion: Value(promptVersion),
              inputTokens: Value(r.inputTokens),
              outputTokens: Value(r.outputTokens),
              rawJson: Value(raw),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<void> markAiError(int documentId, String message) async {
    await (db.update(db.documents)..where((t) => t.id.equals(documentId))).write(
      DocumentsCompanion(
        aiStatus: const Value('error'),
        aiError: Value(truncate(message, 300)),
      ),
    );
  }

  Future<void> toggleBookmark(Document doc) async {
    final next = !doc.isBookmarked;
    await db.transaction(() async {
      await (db.update(db.documents)..where((t) => t.id.equals(doc.id))).write(
        DocumentsCompanion(isBookmarked: Value(next)),
      );
      if (next) {
        await db.into(db.bookmarks).insert(
              BookmarksCompanion.insert(documentId: doc.id),
              mode: InsertMode.insertOrReplace,
            );
      } else {
        await (db.delete(db.bookmarks)..where((t) => t.documentId.equals(doc.id))).go();
      }
    });
  }

  Future<void> markRead(int id, {bool read = true}) async {
    await (db.update(db.documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(isRead: Value(read)),
    );
  }

  Future<void> deleteDocument(int id) async {
    await db.transaction(() async {
      await (db.delete(db.documents)..where((t) => t.id.equals(id))).go();
      await db.customStatement('DELETE FROM doc_fts WHERE rowid = ?', [id]);
    });
  }

  Future<void> deleteSource(int id) async {
    await (db.delete(db.sources)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setSourceEnabled(int id, bool enabled) async {
    await (db.update(db.sources)..where((t) => t.id.equals(id))).write(
      SourcesCompanion(enabled: Value(enabled)),
    );
  }

  Future<List<Document>> topDocuments({int limit = 8}) {
    final q = db.select(db.documents)
      ..where((t) => t.aiStatus.equals('done'))
      ..orderBy([(t) => OrderingTerm.desc(t.valueScore)])
      ..limit(limit);
    return q.get();
  }

  Future<List<Document>> allDocuments({int limit = 300}) {
    final q = db.select(db.documents)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return q.get();
  }

  Future<List<CategoryStat>> categories() => db.loadCategories();

  Future<AppStats> stats() => db.loadStats();

  Future<AiUsage> usage() => db.loadUsage();

  Future<List<Document>> search(String query) async {
    final docs = await db.searchDocuments(query);
    if (query.trim().isNotEmpty) {
      await db.into(db.searchHistory).insert(
            SearchHistoryCompanion.insert(query: query.trim(), resultCount: Value(docs.length)),
          );
    }
    return docs;
  }
}
