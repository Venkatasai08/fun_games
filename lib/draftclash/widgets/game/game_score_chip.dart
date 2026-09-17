// lib/draftclash/widgets/game/game_score_chip.dart
import 'package:flutter/material.dart';

const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class GameScoreChip extends StatelessWidget {
  final String name;
  final double score;
  final Color accent;
  final bool isLeading;
  const GameScoreChip({
    super.key,
    required this.name,
    required this.score,
    required this.accent,
    required this.isLeading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isLeading ? accent.withOpacity(0.08) : _raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isLeading ? accent.withOpacity(0.4) : _bdr),
        ),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15), shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                  color: accent, height: 1),
            )),
          ),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                      color: _txtPri)),
              Text('$score pts', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: isLeading ? accent : _txtMut, height: 1.1)),
            ],
          )),
        ]),
      ),
    );
  }
}
