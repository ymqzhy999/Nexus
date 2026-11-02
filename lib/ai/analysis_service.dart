import '../core/models.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../data/repository.dart';
import 'deepseek.dart';

class AnalysisReport {
  final int analyzed;
  final int failed;
  final int inputTokens;
  final int outputTokens;
  final List<String> errors;
  final String? fatal;

  const AnalysisReport({
    this.analyzed = 0,
    this.failed = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.errors = const [],
    this.fatal,
  });
}

class AnalysisService {
  final NexusRepository repo;
  final DeepSeekClient client;
  final String language;

  AnalysisService({
    required this.repo,
    required this.client,
    required this.language,
  });

  Future<AiResult> analyzeOne(Document doc) async {
    final content = doc.content.trim();
    if (content.length < 40) {
      throw AiException('正文太短，无法分析');
    }
    Source? source;
    if (doc.sourceId != null) {
      source = await repo.getSource(doc.sourceId!);
    }
    final result = await client.analyze(
      AiInput(
        title: doc.title,
        url: doc.url,
        source: source?.name ?? sourceHost(doc.url),
        content: content,
        publishedAt: doc.publishedAt,
      ),
      language: language,
    );
    await repo.applyAi(doc.id, result, 'v1.0');
    return result;
  }

  Future<AnalysisReport> analyzePending({
    int limit = 5,
    void Function(int done, int total)? onProgress,
  }) async {
    final docs = await repo.pendingDocuments(limit: limit);
    var analyzed = 0;
    var failed = 0;
    var input = 0;
    var output = 0;
    final errors = <String>[];
    for (var i = 0; i < docs.length; i++) {
      onProgress?.call(i, docs.length);
      try {
        final r = await analyzeOne(docs[i]);
        analyzed++;
        input += r.inputTokens;
        output += r.outputTokens;
      } on AiException catch (e) {
        failed++;
        errors.add(e.message);
        await repo.markAiError(docs[i].id, e.message);
        if (e.message.contains('API Key 无效') ||
            e.message.contains('余额不足') ||
            e.message.contains('请先')) {
          return AnalysisReport(
            analyzed: analyzed,
            failed: failed,
            inputTokens: input,
            outputTokens: output,
            errors: errors,
            fatal: e.message,
          );
        }
      } catch (e) {
        failed++;
        errors.add(e.toString());
        await repo.markAiError(docs[i].id, e.toString());
      }
    }
    onProgress?.call(docs.length, docs.length);
    return AnalysisReport(
      analyzed: analyzed,
      failed: failed,
      inputTokens: input,
      outputTokens: output,
      errors: errors,
    );
  }
}
