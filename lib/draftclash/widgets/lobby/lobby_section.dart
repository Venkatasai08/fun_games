// lib/draftclash/widgets/lobby/lobby_section.dart
import 'package:flutter/material.dart';

const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _txtPri = Color(0xFFEAE8FF);

class LobbySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const LobbySection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surf, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(icon, size: 17, color: _violet),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: _txtPri)),
          ]),
        ),
        Divider(height: 1, color: _bdr),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ]),
    );
  }
}
