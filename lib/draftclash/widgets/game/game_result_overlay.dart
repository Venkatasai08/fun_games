// lib/draftclash/widgets/game/game_result_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../blocs/game/draft_game_bloc.dart';
import 'game_final_tile.dart';

const _surf   = Color(0xFF0D0C1E);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _red    = Color(0xFFE8445A);
const _gold   = Color(0xFFFFD700);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class GameResultOverlay extends StatelessWidget {
  final DraftGameLoaded loaded;
  const GameResultOverlay({super.key, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final room   = loaded.room;
    final my     = loaded.myMember;
    final opp    = loaded.opponentMember;
    final iWon   = room.winnerId != null && room.winnerId == my?.userId;
    final isDraw = room.winnerId == null;

    final headline = isDraw ? "It's a Draw!" : iWon ? 'Victory!' : 'Defeat';
    final emoji    = isDraw ? '🤝' : iWon ? '🏆' : '💀';
    final headlineColor = isDraw ? _txtPri : iWon ? _gold : _red;

    return Container(
      color: const Color(0xEE07070F),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 68))
                    .animate()
                    .scale(begin: const Offset(0.4, 0.4),
                        duration: 580.ms, curve: Curves.elasticOut),
                const SizedBox(height: 14),
                Text(headline, style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: headlineColor))
                    .animate().fadeIn(delay: 200.ms),
                if (!iWon && !isDraw)
                  Text('${room.winnerUsername ?? "Opponent"} wins',
                      style: const TextStyle(color: _txtMut, fontSize: 13))
                      .animate().fadeIn(delay: 280.ms),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: _surf, borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _bdr),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Expanded(child: GameFinalTile(
                        name: my?.username ?? 'You',
                        score: loaded.myScore,
                        isWinner: iWon, color: _amber)),
                    Container(width: 1, height: 55, color: _bdr,
                        margin: const EdgeInsets.symmetric(horizontal: 14)),
                    Expanded(child: GameFinalTile(
                        name: opp?.username ?? 'Opponent',
                        score: loaded.opponentScore,
                        isWinner: !iWon && !isDraw, color: _violet)),
                  ]),
                ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.08),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_rounded, size: 17),
                    label: const Text('Back to Lobby',
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iWon ? _gold : _violet,
                      foregroundColor:
                          iWon ? const Color(0xFF1A1000) : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                      elevation: 0,
                    ),
                  ),
                ).animate().fadeIn(delay: 560.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


