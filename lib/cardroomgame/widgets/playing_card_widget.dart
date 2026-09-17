// lib/cardroomgame/widgets/playing_card_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/card_model.dart';
import '../../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayingCardWidget  –  renders a single card face or back
// ─────────────────────────────────────────────────────────────────────────────

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;
  final bool isDragging;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.width = 60,
    this.height = 90,
    this.isDragging = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: card.faceUp ? Colors.white : const Color(0xFF1B2A5C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDragging
                ? AppTheme.accent
                : isHighlighted
                    ? AppTheme.primary
                    : Colors.black26,
            width: isDragging || isHighlighted ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDragging
                  ? AppTheme.accent.withOpacity(0.45)
                  : Colors.black.withOpacity(0.35),
              blurRadius: isDragging ? 18 : 6,
              offset: isDragging ? const Offset(0, 6) : const Offset(0, 3),
            ),
          ],
        ),
        child: card.faceUp ? _buildFace() : _buildBack(),
      ),
    );
  }

  Widget _buildFace() {
    final color = card.isRed ? const Color(0xFFCC2200) : const Color(0xFF111111);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          // Top-left rank + suit
          Positioned(
            top: 0,
            left: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.rankLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0)),
                Text(card.suitSymbol,
                    style: TextStyle(fontSize: 11, color: color, height: 1.0)),
              ],
            ),
          ),
          // Center suit symbol
          Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                fontSize: width * 0.42,
                color: color.withOpacity(0.18),
              ),
            ),
          ),
          // Bottom-right rank + suit (rotated)
          Positioned(
            bottom: 0,
            right: 2,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(card.rankLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: color,
                          height: 1.0)),
                  Text(card.suitSymbol,
                      style:
                          TextStyle(fontSize: 11, color: color, height: 1.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A5C), Color(0xFF0F1C45)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.style_rounded,
          size: width * 0.45,
          color: Colors.white.withOpacity(0.25),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DraggableCardWidget  –  wraps PlayingCardWidget with Draggable
// ─────────────────────────────────────────────────────────────────────────────

class DraggableCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;
  final bool isDragging;
  final bool isHighlighted;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  const DraggableCardWidget({
    super.key,
    required this.card,
    this.width = 60,
    this.height = 90,
    this.isDragging = false,
    this.isHighlighted = false,
    this.onDragStarted,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<PlayingCard>(
      data: card,
      onDragStarted: onDragStarted,
      onDraggableCanceled: (_, __) => onDragEnd?.call(),
      onDragCompleted: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.15,
          child: PlayingCardWidget(
            card: card.copyWith(faceUp: true),
            width: width,
            height: height,
            isDragging: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: PlayingCardWidget(
          card: card,
          width: width,
          height: height,
        ),
      ),
      child: PlayingCardWidget(
        card: card.copyWith(faceUp: true),
        width: width,
        height: height,
        isDragging: isDragging,
        isHighlighted: isHighlighted,
      )
          .animate()
          .scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            duration: 220.ms,
            curve: Curves.elasticOut,
          ),
    );
  }
}
