// lib/draftclash/widgets/game/game_loading_view.dart
import 'package:flutter/material.dart';

const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _txtMut = Color(0xFF6A6898);

class GameLoadingView extends StatelessWidget {
  const GameLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: _surf, shape: BoxShape.circle,
            border: Border.all(color: _bdr),
          ),
          child: const Center(child: SizedBox(
            width: 26, height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_violet)),
          )),
        ),
        const SizedBox(height: 14),
        const Text('Loading match…',
            style: TextStyle(color: _txtMut, fontSize: 12)),
      ]),
    );
  }
}
