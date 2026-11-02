import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';

part 'database.g.dart';

class Sources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get url => text()();
  TextColumn get kind => text().withDefault(const Constant('html'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get config => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get lastRunAt => dateTime().nullable()();
  TextColumn get lastStatus => text().withDefault(const Constant('idle'))();
  TextColumn get lastError => text().withDefault(const Constant(''))();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  IntColumn get scheduleMinutes => integer().withDefault(const Constant(360))();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
}

class CrawlRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId => integer().nullable().references(Sources, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('running'))();
  IntColumn get itemsFound => integer().withDefault(const Constant(0))();
  IntColumn get itemsNew => integer().withDefault(const Constant(0))();
  TextColumn get error => text().withDefault(const Constant(''))();
  TextColumn get engine => text().withDefault(const Constant('dart-local'))();
}

class RawDocuments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId => integer().nullable().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get raw => text().withDefault(const Constant(''))();
  TextColumn get contentType => text().withDefault(const Constant(''))();
  IntColumn get httpStatus => integer().withDefault(const Constant(200))();
  DateTimeColumn get fetchedAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get contentHash => text().withDefault(const Constant(''))();
}

class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId => integer().nullable().references(Sources, #id, onDelete: KeyAction.setNull)();
  IntColumn get rawId => integer().nullable()();
  TextColumn get url => text()();
  TextColumn get urlHash => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get excerpt => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant(''))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get contentHash => text().withDefault(const Constant(''))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  IntColumn get valueScore => integer().withDefault(const Constant(0))();
  TextColumn get category => text().withDefault(const Constant('未分类'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get whyValuable => text().withDefault(const Constant(''))();
  TextColumn get keyPointsJson => text().withDefault(const Constant('[]'))();
  TextColumn get entitiesJson => text().withDefault(const Constant('[]'))();
  TextColumn get aiStatus => text().withDefault(const Constant('pending'))();
  TextColumn get aiError => text().withDefault(const Constant(''))();
  TextColumn get aiModel => text().withDefault(const Constant(''))();
  DateTimeColumn get analyzedAt => dateTime().nullable()();
  IntColumn get readingMinutes => integer().withDefault(const Constant(1))();
  TextColumn get contentType => text().withDefault(const Constant('other'))();
  TextColumn get sentiment => text().withDefault(const Constant('neutral'))();
}

class AiAnalysis extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().unique().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get whyValuable => text().withDefault(const Constant(''))();
  TextColumn get keyPointsJson => text().withDefault(const Constant('[]'))();
  TextColumn get category => text().withDefault(const Constant('未分类'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get entitiesJson => text().withDefault(const Constant('[]'))();
  IntColumn get valueScore => integer().withDefault(const Constant(0))();
  TextColumn get sentiment => text().withDefault(const Constant('neutral'))();
  TextColumn get language => text().withDefault(const Constant(''))();
  IntColumn get readingMinutes => integer().withDefault(const Constant(1))();
  TextColumn get contentType => text().withDefault(const Constant('other'))();
  TextColumn get model => text().withDefault(const Constant(''))();
  TextColumn get promptVersion => text().withDefault(const Constant('v1'))();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get analyzedAt => dateTime().clientDefault(() => DateTime.now())();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().withDefault(const Constant('#22D3EE'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

class DocumentTags extends Table {
  IntColumn get documentId => integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {documentId, tagId};
}

class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

class CollectionDocuments extends Table {
  IntColumn get collectionId => integer().references(Collections, #id, onDelete: KeyAction.cascade)();
  IntColumn get documentId => integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {collectionId, documentId};
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().unique().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  IntColumn get resultCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  IntColumn get entityId => integer()();
  TextColumn get op => text()();
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

class SettingsEntries extends Table {
  TextColumn get settingKey => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {settingKey};
}

@DriftDatabase(tables: [
  Sources,
  CrawlRuns,
  RawDocuments,
  Documents,
  AiAnalysis,
  Tags,
  DocumentTags,
  Collections,
  CollectionDocuments,
  Bookmarks,
  SearchHistory,
  SyncOutbox,
  SettingsEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSearchIndex();
          for (final sql in _indexes) {
            await customStatement(sql);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static const List<String> _indexes = [
    'CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(source_id)',
    'CREATE INDEX IF NOT EXISTS idx_documents_created ON documents(created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_documents_score ON documents(value_score DESC)',
    'CREATE INDEX IF NOT EXISTS idx_documents_hash ON documents(content_hash)',
    'CREATE INDEX IF NOT EXISTS idx_ai_document ON ai_analysis(document_id)',
  ];

  Future<void> _createSearchIndex() async {
    try {
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS doc_fts USING fts5(title, body, tokenize='trigram')",
      );
      return;
    } catch (_) {}
    try {
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS doc_fts USING fts5(title, body)",
      );
      return;
    } catch (_) {}
    await customStatement('CREATE TABLE IF NOT EXISTS doc_fts (title TEXT, body TEXT)');
  }

  Future<void> indexDocument(int id, String title, String body) async {
    try {
      await customStatement('DELETE FROM doc_fts WHERE rowid = ?', [id]);
      await customStatement('INSERT INTO doc_fts(rowid, title, body) VALUES (?, ?, ?)', [id, title, body]);
    } catch (_) {}
  }

  Future<List<Document>> searchDocuments(String query, {int limit = 80}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    List<int> ids = [];
    if (q.length >= 3) {
      try {
        final rows = await customSelect(
          'SELECT rowid AS doc_id FROM doc_fts WHERE doc_fts MATCH ? ORDER BY rank LIMIT ?',
          variables: [Variable.withString('"${q.replaceAll('"', '""')}"'), Variable.withInt(limit)],
        ).get();
        ids = rows.map((r) => r.read<int>('doc_id')).toList();
      } catch (_) {}
    }
    if (ids.isEmpty) {
      final like = '%${q.replaceAll('%', '').replaceAll('_', '')}%';
      final rows = await customSelect(
        'SELECT id AS doc_id FROM documents '
        'WHERE title LIKE ? OR content LIKE ? OR summary LIKE ? '
        'ORDER BY value_score DESC LIMIT ?',
        variables: [
          Variable.withString(like),
          Variable.withString(like),
          Variable.withString(like),
          Variable.withInt(limit),
        ],
      ).get();
      ids = rows.map((r) => r.read<int>('doc_id')).toList();
    }
    if (ids.isEmpty) return const [];
    final docs = await (select(documents)..where((t) => t.id.isIn(ids))).get();
    final byId = {for (final d in docs) d.id: d};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<AppStats> loadStats() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c, SUM(CASE WHEN value_score >= 70 THEN 1 ELSE 0 END) AS hv, '
      'SUM(CASE WHEN ai_status = "done" THEN 1 ELSE 0 END) AS an, AVG(value_score) AS av '
      'FROM documents',
    ).getSingle();
    final src = await customSelect('SELECT COUNT(*) AS c FROM sources').getSingle();
    return AppStats(
      documents: row.read<int?>('c') ?? 0,
      sources: src.read<int?>('c') ?? 0,
      highValue: row.read<int?>('hv') ?? 0,
      analyzed: row.read<int?>('an') ?? 0,
      avgScore: (row.read<double?>('av') ?? 0).toDouble(),
    );
  }

  Stream<AppStats> watchStats() {
    return customSelect(
      'SELECT (SELECT COUNT(*) FROM documents) AS c, '
      '(SELECT COUNT(*) FROM sources) AS s, '
      '(SELECT COUNT(*) FROM documents WHERE value_score >= 70) AS hv, '
      '(SELECT COUNT(*) FROM documents WHERE ai_status = "done") AS an, '
      '(SELECT COALESCE(AVG(value_score), 0) FROM documents) AS av',
    ).watchSingle().map((row) => AppStats(
          documents: row.read<int?>('c') ?? 0,
          sources: row.read<int?>('s') ?? 0,
          highValue: row.read<int?>('hv') ?? 0,
          analyzed: row.read<int?>('an') ?? 0,
          avgScore: (row.read<double?>('av') ?? 0).toDouble(),
        ));
  }

  Future<List<CategoryStat>> loadCategories() async {
    final rows = await customSelect(
      'SELECT category, COUNT(*) AS c FROM documents GROUP BY category ORDER BY c DESC LIMIT 12',
    ).get();
    return rows.map((r) => CategoryStat(r.read<String>('category'), r.read<int>('c'))).toList();
  }

  Future<AiUsage> loadUsage() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(input_tokens),0) AS i, COALESCE(SUM(output_tokens),0) AS o, COUNT(*) AS c FROM ai_analysis',
    ).getSingle();
    return AiUsage(
      inputTokens: row.read<int?>('i') ?? 0,
      outputTokens: row.read<int?>('o') ?? 0,
      calls: row.read<int?>('c') ?? 0,
    );
  }

  Future<void> wipeAll() async {
    await transaction(() async {
      for (final table in [
        documentTags,
        collectionDocuments,
        bookmarks,
        aiAnalysis,
        documents,
        rawDocuments,
        crawlRuns,
        sources,
        tags,
        collections,
        searchHistory,
        syncOutbox,
        settingsEntries,
      ]) {
        await delete(table).go();
      }
      await customStatement('DELETE FROM doc_fts');
    });
    await customStatement('VACUUM');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'nexus.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
