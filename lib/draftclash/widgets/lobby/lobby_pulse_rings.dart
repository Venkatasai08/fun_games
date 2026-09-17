// lib/draftclash/widgets/lobby/lobby_pulse_rings.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _amber  = Color(0xFFF4A11D);

class LobbyPulseRings extends StatelessWidget {
  const LobbyPulseRings({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110, height: 110,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _amber.withOpacity(0.1), width: 1.5),
          ),
        ).animate(onPlay: (c) => c.repeat()).scaleXY(
            begin: 0.88, end: 1.0, duration: 1400.ms, curve: Curves.easeInOut),
        Container(
          width: 82, height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _amber.withOpacity(0.18), width: 1.5),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
            begin: 0.94, end: 1.0, duration: 900.ms, curve: Curves.easeInOut),
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFFBF40), _amber]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _amber.withOpacity(0.5), blurRadius: 20)],
          ),
          child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 28),
        ),
      ]),
    );
  }
}
