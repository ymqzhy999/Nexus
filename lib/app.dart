import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/crawl_page.dart';
import 'features/crawler_settings_page.dart';
import 'features/datasets_page.dart';
import 'features/simple_dataset_page.dart';
import 'features/sites_page.dart';
import 'features/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/crawl',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/crawl', builder: (context, state) => const CrawlPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/datasets', builder: (context, state) => const DatasetsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/sites', builder: (context, state) => const SitesPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const CrawlerSettingsPage()),
          ]),
        ],
      ),
      GoRoute(
        path: '/dataset/:id',
        builder: (context, state) => SimpleDatasetPage(
          datasetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/crawler-settings',
        builder: (context, state) => const CrawlerSettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: NColors.bg,
      body: Center(
        child: Text('页面不存在\n${state.error}', style: const TextStyle(color: NColors.muted)),
      ),
    ),
  );
});

class NexusApp extends ConsumerWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Nexus Crawler',
      debugShowCheckedModeBanner: false,
      theme: buildNexusTheme(),
      routerConfig: router,
    );
  }
}
