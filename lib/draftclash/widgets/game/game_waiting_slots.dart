// lib/draftclash/widgets/game/game_waiting_slots.dart
import 'package:flutter/material.dart';

const _bdr = Color(0xFF1E1B38);

class GameWaitingSlots extends StatelessWidget {
  const GameWaitingSlots({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(6, (i) => Padding(
        padding: EdgeInsets.only(bottom: i < 5 ? 4 : 0),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0919),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF14122A)),
          ),
          child: const Center(child: Text('···',
              style: TextStyle(fontSize: 12, color: _bdr, letterSpacing: 4))),
        ),
      )),
    );
  }
}
