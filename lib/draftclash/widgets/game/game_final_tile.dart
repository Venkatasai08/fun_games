// lib/draftclash/widgets/game/game_final_tile.dart
import 'package:flutter/material.dart';

const _txtMut = Color(0xFF6A6898);

class GameFinalTile extends StatelessWidget {
  final String name;
  final double score;
  final bool isWinner;
  final Color color;
  const GameFinalTile({
    super.key,
    required this.name,
    required this.score,
    required this.isWinner,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(isWinner ? '👑' : '  ',
          style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: isWinner ? color : _txtMut)),
      const SizedBox(height: 5),
      Text('$score', style: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w900,
          color: isWinner ? color : _txtMut, height: 1)),
      Text('pts', style: TextStyle(
          fontSize: 9, color: _txtMut.withOpacity(0.5))),
    ]);
  }
}
