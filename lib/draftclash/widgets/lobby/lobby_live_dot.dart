// lib/draftclash/widgets/lobby/lobby_live_dot.dart
import 'package:flutter/material.dart';

class LobbyLiveDot extends StatefulWidget {
  final Color color;
  const LobbyLiveDot({super.key, required this.color});

  @override
  State<LobbyLiveDot> createState() => _LobbyLiveDotState();
}

class _LobbyLiveDotState extends State<LobbyLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
