import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _items = [
    (Icons.radar, '信息流'),
    (Icons.explore_outlined, '发现'),
    (Icons.hub_outlined, '知识库'),
    (Icons.tune, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: NColors.bg,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom + 8 : 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220).withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final active = navigationShell.currentIndex == i;
                  final item = _items[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: active
                              ? LinearGradient(colors: [
                                  NColors.cyan.withValues(alpha: 0.16),
                                  NColors.violet.withValues(alpha: 0.1),
                                ])
                              : null,
                          border: active
                              ? Border.all(color: NColors.cyan.withValues(alpha: 0.22))
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.$1,
                              size: 20,
                              color: active ? NColors.cyan : NColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$2,
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 0.4,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? NColors.cyan : NColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
