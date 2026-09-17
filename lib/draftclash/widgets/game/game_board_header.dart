// lib/draftclash/widgets/game/game_board_header.dart
import 'package:flutter/material.dart';

const _raised  = Color(0xFF14122A);
const _bdr     = Color(0xFF1E1B38);
const _txtPri  = Color(0xFFEAE8FF);
const _txtMut  = Color(0xFF6A6898);

class GameBoardHeader extends StatelessWidget {
  final String label;
  final int filled;
  final Color accent;
  final bool isActive;
  const GameBoardHeader({
    super.key,
    required this.label,
    required this.filled,
    required this.accent,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 12,
        decoration: BoxDecoration(
          color: isActive ? accent : accent.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5, fontWeight: FontWeight.w800,
            color: isActive ? _txtPri : _txtMut,
            letterSpacing: 0.6,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: _raised, borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _bdr),
        ),
        child: Text('$filled/6',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                color: _txtMut)),
      ),
    ]);
  }
}
