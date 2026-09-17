// lib/draftclash/widgets/lobby/lobby_franchise_chip.dart
import 'package:flutter/material.dart';

class LobbyFranchiseChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const LobbyFranchiseChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  // Deterministic accent color from franchise name
  Color _accentColor() {
    if (label == 'All Series') return const Color(0xFF9C70FF);
    final hash = label.codeUnits.fold(0, (acc, b) => acc ^ (b * 31));
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.70, 0.58).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final accent = isSelected ? const Color(0xFF6E44FF) : _accentColor();
    final initial = label == 'All Series' ? '★' : (label.isNotEmpty ? label[0].toUpperCase() : '?');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6E44FF), Color(0xFF9C70FF)],
                )
              : null,
          color: isSelected ? null : const Color(0xFF13112A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF6E44FF) : accent.withOpacity(0.30),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6E44FF).withOpacity(0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Initial avatar ─────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          Colors.white.withOpacity(0.28),
                          Colors.white.withOpacity(0.08),
                        ]
                      : [
                          accent.withOpacity(0.28),
                          accent.withOpacity(0.07),
                        ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withOpacity(0.30)
                      : accent.withOpacity(0.38),
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: label == 'All Series' ? 13 : 12,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : accent,
                    height: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Label ──────────────────────────────────────────────────
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFB0AECF),
                letterSpacing: -0.1,
              ),
            ),

            // ── Check badge (selected only) ────────────────────────────
            if (isSelected) ...[
              const SizedBox(width: 7),
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
