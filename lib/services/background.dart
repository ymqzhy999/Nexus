import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:workmanager/workmanager.dart';

import '../core/models.dart';
import '../crawl/engine.dart';
import '../crawl/http_client.dart';
import '../data/database.dart';
import '../data/repository.dart';

const String nexusSyncTask = 'nexus.sync';
const String nexusSyncUnique = 'nexus-sync';

@pragma('vm:entry-point')
void nexusCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      final prefs = await SharedPreferences.getInstance();
      final proxyEnabled = prefs.getBool('nexus.proxy_enabled') ?? false;
      final proxyUrl = prefs.getString('nexus.proxy_url') ?? '';
      final maxItems = prefs.getInt('nexus.max_items') ?? 20;
      final db = AppDatabase();
      final repo = NexusRepository(db);
      final engine = CrawlEngine(HttpFetcher(proxyUrl: proxyEnabled ? proxyUrl : null));
      final sources = await repo.dueSources();
      for (final source in sources.take(5)) {
        final runId = await repo.startRun(source.id);
        try {
          final out = await engine.crawl(
            source.url,
            hint: SourceKindX.parse(source.kind),
            limit: maxItems,
          );
          var added = 0;
          for (final item in out.items) {
            final r = await repo.saveItem(source: source, item: item, kind: out.kind);
            if (r.isNew) added++;
          }
          await repo.finishRun(
            runId,
            sourceId: source.id,
            found: out.items.length,
            added: added,
            sourceName: out.feedTitle,
            kind: out.kind,
          );
        } catch (e) {
          await repo.finishRun(
            runId,
            sourceId: source.id,
            found: 0,
            added: 0,
            error: e.toString(),
          );
        }
      }
      await db.close();
    } catch (_) {
      return false;
    }
    return true;
  });
}

class BackgroundSync {
  static Future<void> configure(bool enabled) async {
    await Workmanager().initialize(nexusCallbackDispatcher);
    if (!enabled) {
      await Workmanager().cancelByUniqueName(nexusSyncUnique);
      return;
    }
    await Workmanager().registerPeriodicTask(
      nexusSyncUnique,
      nexusSyncTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
