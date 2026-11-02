import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app.dart';
import 'core/settings.dart';
import 'services/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF04060C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final settings = await SettingsController.load();
  try {
    await BackgroundSync.configure(settings.state.backgroundSync);
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: [settingsControllerProvider.overrideWith((ref) => settings)],
      child: const NexusApp(),
    ),
  );
}
