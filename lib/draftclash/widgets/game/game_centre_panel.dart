// lib/draftclash/widgets/game/game_centre_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/game/draft_game_bloc.dart';
import '../../services/draft_sound_service.dart';
import '../draft_card_widget.dart';
import 'game_skip_button.dart';
import 'game_timer_dial.dart';

const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _amber  = Color(0xFFF4A11D);
const _txtMut = Color(0xFF6A6898);

class GameCentrePanel extends StatelessWidget {
  final DraftGameLoaded loaded;
  const GameCentrePanel({super.key, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = loaded.isMyTurn;
    final card = loaded.currentCard;

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isMyTurn ? _amber.withOpacity(0.1) : _surf,
          border: Border(
            bottom: BorderSide(
                color: isMyTurn ? _amber.withOpacity(0.3) : _bdr),
          ),
        ),
        child: Column(children: [
          Icon(
            isMyTurn ? Icons.touch_app_rounded : Icons.hourglass_empty_rounded,
            size: 14, color: isMyTurn ? _amber : _txtMut,
          ),
          const SizedBox(height: 3),
          Text(
            isMyTurn ? 'YOUR\nTURN' : 'WAIT',
            style: TextStyle(
              fontSize: 8, fontWeight: FontWeight.w900,
              color: isMyTurn ? _amber : _txtMut,
              letterSpacing: 1, height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
        child: GameTimerDial(seconds: loaded.countdownSeconds),
      ),
      const SizedBox(height: 14),
      Container(height: 1, color: _bdr,
          margin: const EdgeInsets.symmetric(horizontal: 8)),
      const SizedBox(height: 14),
      Text('ON TABLE', style: TextStyle(
        fontSize: 7.5, fontWeight: FontWeight.w700,
        color: _txtMut.withOpacity(0.5), letterSpacing: 1.5,
      )),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: card != null
            ? DraftCardWidget(card: card, glowing: isMyTurn)
            : Container(
                height: 110,
                decoration: BoxDecoration(
                  color: _raised, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bdr),
                ),
                child: Center(child: Text('No card',
                    style: TextStyle(fontSize: 10,
                        color: _txtMut.withOpacity(0.5)))),
              ),
      ),
      const SizedBox(height: 12),
      if (isMyTurn)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GameSkipButton(loaded: loaded),
        ),
      const Spacer(),
    ]);
  }
}
