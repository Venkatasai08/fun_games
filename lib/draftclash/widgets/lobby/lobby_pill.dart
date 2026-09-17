// lib/draftclash/widgets/lobby/lobby_pill.dart
import 'package:flutter/material.dart';

const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _txtMut = Color(0xFF6A6898);

class LobbyPill extends StatelessWidget {
  final String label;
  final Color color;
  const LobbyPill(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.bold,
              color: color.withOpacity(0.85), letterSpacing: 0.6)),
    );
  }
}

class LobbyInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  const LobbyInfoPill({super.key, required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? _txtMut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent != null ? c.withOpacity(0.1) : _raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent != null ? c.withOpacity(0.3) : _bdr),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}
