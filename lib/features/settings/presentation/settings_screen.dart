import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeNotifierProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Settings',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _SectionLabel('Appearance'),
          const SizedBox(height: 12),
          _SettingsRow(
            label: 'Theme',
            child: _ThemeSegment(
              current: themeMode,
              onChanged: (mode) =>
                  ref.read(themeNotifierProvider.notifier).setThemeMode(mode),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Settings row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: cs.onSurface, fontSize: 15)),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── Theme segment control ────────────────────────────────────────────────────

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({required this.current, required this.onChanged});
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (label: 'System', mode: ThemeMode.system),
    (label: 'Light', mode: ThemeMode.light),
    (label: 'Dark', mode: ThemeMode.dark),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: _options.map((opt) {
        final selected = current == opt.mode;
        return GestureDetector(
          onTap: () => onChanged(opt.mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? cs.primary : cs.outline,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
