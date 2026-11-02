import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences prefs;
  final FlutterSecureStorage secure;

  SettingsController({
    required this.prefs,
    required this.secure,
    required AppSettings initial,
  }) : super(initial);

  static const _key = 'nexus.deepseek.api_key';

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    var key = '';
    try {
      key = await secure.read(key: _key) ?? '';
    } catch (_) {
      key = prefs.getString(_key) ?? '';
    }
    final settings = AppSettings(
      apiKey: key,
      model: prefs.getString('nexus.model') ?? 'deepseek-chat',
      baseUrl: prefs.getString('nexus.base_url') ?? 'https://api.deepseek.com',
      autoAnalyze: prefs.getBool('nexus.auto_analyze') ?? true,
      maxItemsPerRun: prefs.getInt('nexus.max_items') ?? 20,
      maxAiPerRun: prefs.getInt('nexus.max_ai') ?? 5,
      proxyEnabled: prefs.getBool('nexus.proxy_enabled') ?? false,
      proxyUrl: prefs.getString('nexus.proxy_url') ?? '',
      backgroundSync: prefs.getBool('nexus.background_sync') ?? false,
      outputLanguage: prefs.getString('nexus.output_language') ?? '中文',
      crawlMaxPages: prefs.getInt('nexus.crawl_max_pages') ?? 60,
      crawlMaxDepth: prefs.getInt('nexus.crawl_max_depth') ?? 3,
    );
    return SettingsController(prefs: prefs, secure: secure, initial: settings);
  }

  Future<void> setApiKey(String value) async {
    final key = value.trim();
    state = state.copyWith(apiKey: key);
    try {
      if (key.isEmpty) {
        await secure.delete(key: _key);
      } else {
        await secure.write(key: _key, value: key);
      }
    } catch (_) {
      await prefs.setString(_key, key);
    }
  }

  Future<void> setModel(String value) async {
    state = state.copyWith(model: value);
    await prefs.setString('nexus.model', value);
  }

  Future<void> setBaseUrl(String value) async {
    final v = value.trim().isEmpty ? 'https://api.deepseek.com' : value.trim();
    state = state.copyWith(baseUrl: v);
    await prefs.setString('nexus.base_url', v);
  }

  Future<void> setAutoAnalyze(bool value) async {
    state = state.copyWith(autoAnalyze: value);
    await prefs.setBool('nexus.auto_analyze', value);
  }

  Future<void> setMaxItems(int value) async {
    state = state.copyWith(maxItemsPerRun: value);
    await prefs.setInt('nexus.max_items', value);
  }

  Future<void> setMaxAi(int value) async {
    state = state.copyWith(maxAiPerRun: value);
    await prefs.setInt('nexus.max_ai', value);
  }

  Future<void> setProxy({bool? enabled, String? url}) async {
    state = state.copyWith(
      proxyEnabled: enabled ?? state.proxyEnabled,
      proxyUrl: url ?? state.proxyUrl,
    );
    await prefs.setBool('nexus.proxy_enabled', state.proxyEnabled);
    await prefs.setString('nexus.proxy_url', state.proxyUrl);
  }

  Future<void> setBackgroundSync(bool value) async {
    state = state.copyWith(backgroundSync: value);
    await prefs.setBool('nexus.background_sync', value);
  }

  Future<void> setOutputLanguage(String value) async {
    state = state.copyWith(outputLanguage: value);
    await prefs.setString('nexus.output_language', value);
  }

  Future<void> setCrawlMaxPages(int value) async {
    state = state.copyWith(crawlMaxPages: value);
    await prefs.setInt('nexus.crawl_max_pages', value);
  }

  Future<void> setCrawlMaxDepth(int value) async {
    state = state.copyWith(crawlMaxDepth: value);
    await prefs.setInt('nexus.crawl_max_depth', value);
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => throw UnimplementedError('SettingsController must be overridden at startup'),
);

final appSettingsProvider = Provider<AppSettings>((ref) => ref.watch(settingsControllerProvider));
