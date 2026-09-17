// lib/draftclash/widgets/lobby/lobby_status_badge.dart
import 'package:flutter/material.dart';
import '../../models/draft_room.dart';
import 'lobby_live_dot.dart';

const _amber = Color(0xFFF4A11D);
const _green = Color(0xFF3ADE80);

class LobbyStatusBadge extends StatelessWidget {
  final DraftRoom room;
  const LobbyStatusBadge({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    bool live = false;

    if (room.isFinished) {
      label = 'ENDED';
      color = const Color(0xFFFFD700);
    } else if (room.isDrafting) {
      label = 'LIVE';
      color = _amber;
      live = true;
    } else {
      label = 'OPEN';
      color = _green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (live) ...[
          LobbyLiveDot(color: color),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(
          color: color, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.2,
        )),
      ]),
    );
  }
}
