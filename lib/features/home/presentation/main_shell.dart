import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _icons = [
    (outline: Icons.explore_outlined, filled: Icons.explore),
    (outline: Icons.favorite_outline, filled: Icons.favorite),
    (outline: Icons.chat_bubble_outline, filled: Icons.chat_bubble),
    (outline: Icons.person_outline, filled: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_icons.length, (index) {
                  final selected = navigationShell.currentIndex == index;
                  return GestureDetector(
                    onTap: () => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withValues(alpha: 0.18)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selected
                              ? _icons[index].filled
                              : _icons[index].outline,
                          color: selected
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          size: 24,
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
