// lib/draftclash/widgets/lobby/lobby_empty_state.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class LobbyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const LobbyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const SizedBox(height: 80),
      Column(children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: _surf, borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _bdr),
          ),
          child: Icon(icon, size: 44, color: _txtMut),
        ).animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: _txtPri)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: _txtMut, fontSize: 13)),
      ]),
    ]);
  }
}
