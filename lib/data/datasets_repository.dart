import 'dart:convert';

import 'package:drift/drift.dart';

import '../analysis/metrics.dart';
import '../core/utils.dart';
import 'database.dart';
import 'table_data.dart';

class DatasetBundle {
  final Dataset record;
  final TableData table;

  const DatasetBundle({required this.record, required this.table});
}

class DatasetsRepository {
  final AppDatabase db;

  DatasetsRepository(this.db);

  Stream<List<Dataset>> watchDatasets() {
    final q = db.select(db.datasets)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch();
  }

  Future<Dataset?> getDataset(int id) =>
      (db.select(db.datasets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> saveDataset(TableData input) async {
    final table = input.isWideYearTable ? input.toLongFormat() : input;
    final rows = table.rows.length > 20000 ? table.rows.take(20000).toList() : table.rows;
    return db.into(db.datasets).insert(DatasetsCompanion.insert(
          name: truncate(table.title.trim().isEmpty ? '未命名数据集' : table.title.trim(), 120),
          sourceUrl: Value(table.sourceUrl),
          sourceName: Value(table.sourceName),
          columnsJson: Value(jsonEncode(table.headers)),
          rowsJson: Value(jsonEncode(rows)),
          rowCount: Value(rows.length),
          metaJson: Value(jsonEncode(table.meta)),
        ));
  }

  Future<void> deleteDataset(int id) async {
    await (db.delete(db.datasets)..where((t) => t.id.equals(id))).go();
  }

  Future<DataAnalysis?> latestAnalysis(int datasetId) {
    final q = db.select(db.dataAnalyses)
      ..where((t) => t.datasetId.equals(datasetId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);
    return q.getSingleOrNull();
  }

  Future<void> saveAnalysis({
    required int datasetId,
    required List<MetricResult> metrics,
    required String aiText,
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) async {
    await db.into(db.dataAnalyses).insert(DataAnalysesCompanion.insert(
          datasetId: datasetId,
          metricsJson: Value(jsonEncode(metrics.map((e) => e.toJson()).toList())),
          aiJson: Value(jsonEncode({'text': aiText})),
          model: Value(model),
          inputTokens: Value(inputTokens),
          outputTokens: Value(outputTokens),
        ));
  }
}
