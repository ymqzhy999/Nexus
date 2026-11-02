import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/discover_page.dart';
import 'features/document_page.dart';
import 'features/feed_page.dart';
import 'features/library_page.dart';
import 'features/reader_page.dart';
import 'features/settings_page.dart';
import 'features/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/feed',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (context, state) => const FeedPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/discover', builder: (context, state) => const DiscoverPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (context, state) => const LibraryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
          ]),
        ],
      ),
      GoRoute(
        path: '/doc/:id',
        builder: (context, state) => DocumentPage(
          documentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/reader',
        builder: (context, state) => ReaderPage(
          url: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'] ?? '',
        ),
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
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildNexusTheme(),
      routerConfig: router,
    );
  }
}
