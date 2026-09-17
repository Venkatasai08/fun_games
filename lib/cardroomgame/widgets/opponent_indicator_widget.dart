// lib/cardroomgame/widgets/opponent_indicator_widget.dart
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/card_player_model.dart';
import '../../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OpponentIndicatorWidget
//
// Shows a compact "player slot" for every opponent along the top of the screen.
// Acts as a DragTarget — dragging a card onto a player's slot passes it to them.
// ─────────────────────────────────────────────────────────────────────────────

class OpponentIndicatorWidget extends StatelessWidget {
  final CardPlayer player;
  final bool isHost;
  final void Function(PlayingCard card, String targetUserId)? onCardDropped;

  const OpponentIndicatorWidget({
    super.key,
    required this.player,
    required this.isHost,
    this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          onCardDropped?.call(details.data, player.userId),
      builder: (ctx, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isHovering
                ? AppTheme.accent.withOpacity(0.18)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovering
                  ? AppTheme.accent
                  : isHost
                      ? AppTheme.primary.withOpacity(0.55)
                      : AppTheme.border,
              width: isHovering ? 2 : 1,
            ),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 12)
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isHost
                        ? [AppTheme.primary, AppTheme.primaryLight]
                        : [AppTheme.bgCardLight, AppTheme.bgCardLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isHost
                        ? AppTheme.primary.withOpacity(0.6)
                        : AppTheme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    player.username.isNotEmpty
                        ? player.username[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isHost ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // Username
              Text(
                player.username,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),

              // Card count pill
              _buildCardCountPill(player.hand.length),

              // Host badge
              if (isHost) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        letterSpacing: 0.8),
                  ),
                ),
              ],

              // Drop hint
              if (isHovering) ...[
                const SizedBox(height: 4),
                const Text(
                  'Pass card',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardCountPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0
            ? AppTheme.accent.withOpacity(0.15)
            : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: count > 0
              ? AppTheme.accent.withOpacity(0.4)
              : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_rounded,
              size: 9,
              color: count > 0 ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: count > 0 ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
