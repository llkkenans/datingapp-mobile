import 'package:flutter/material.dart';

class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF6C63FF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.12) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: primary, size: 20),
          ],
        ),
      ),
    );
  }
}
