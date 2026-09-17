// lib/cardroomgame/widgets/fan_hand_widget.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/game/card_game_bloc.dart';
import '../models/card_model.dart';
import 'playing_card_widget.dart';
import '../../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FanHandWidget  –  semi-circular fan of cards
//
// Card sizes increased:  W=82  H=122  (was 62×92)
// Fan height increased:  180px       (was 120px)
// ─────────────────────────────────────────────────────────────────────────────

class FanHandWidget extends StatefulWidget {
  final List<PlayingCard> hand;
  final double maxWidth;

  const FanHandWidget({
    super.key,
    required this.hand,
    required this.maxWidth,
  });

  @override
  State<FanHandWidget> createState() => _FanHandWidgetState();
}

class _FanHandWidgetState extends State<FanHandWidget>
    with SingleTickerProviderStateMixin {
  int? _hoveredIndex;
  late AnimationController _dealController;

  // Per-card curved animations — rebuilt whenever hand size changes.
  final List<Animation<double>> _cardAnims = [];

  // ── Card dimensions (increased) ────────────────────────────────────────
  static const double _cardW = 82.0;
  static const double _cardH = 122.0;

  // ── Fan geometry ───────────────────────────────────────────────────────
  static const double _spreadAngleDeg = 38.0; // total fan angle
  static const double _pivotOffset    = 680.0; // virtual pivot below screen

  @override
  void initState() {
    super.initState();
    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _buildCardAnimations();
    _dealController.forward();
  }

  @override
  void dispose() {
    _dealController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FanHandWidget old) {
    super.didUpdateWidget(old);
    if (old.hand.length != widget.hand.length) {
      _buildCardAnimations();
      _dealController
        ..reset()
        ..forward();
    }
  }

  // ── Animation setup ────────────────────────────────────────────────────
  // Uses Curves.easeOut — stays within [0, 1], safe for Opacity.

  void _buildCardAnimations() {
    _cardAnims.clear();
    final total = widget.hand.length;
    if (total == 0) return;

    for (int i = 0; i < total; i++) {
      final start = (i / total).clamp(0.0, 0.7);
      _cardAnims.add(
        CurvedAnimation(
          parent: _dealController,
          curve: Interval(start, 1.0, curve: Curves.easeOut),
        ),
      );
    }
  }

  // ── Layout math ────────────────────────────────────────────────────────

  double _angleForIndex(int i, int total) {
    if (total <= 1) return 0;
    const spreadRad = _spreadAngleDeg * pi / 180;
    final step = spreadRad / (total - 1);
    return -spreadRad / 2 + step * i;
  }

  Offset _positionForAngle(double angle) {
    final x = _pivotOffset * sin(angle);
    final y = _pivotOffset * (1 - cos(angle));
    return Offset(x, -y);
  }

  double _verticalLiftForIndex(int i, int total) {
    if (total <= 1) return 0;
    final mid   = (total - 1) / 2;
    final dist  = (i - mid).abs() / mid;
    return -(1 - dist) * 18; // center cards lifted more
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hand = widget.hand;
    if (hand.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No cards in hand',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final draggingId = context.select<CardGameBloc, String?>((b) {
      final s = b.state;
      if (s is CardGameLoaded) return s.draggingCardId;
      return null;
    });

    final centerX = widget.maxWidth / 2;

    return SizedBox(
      // Height = card height + headroom for rotation + hover lift
      height: 185,
      width: widget.maxWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (int i = 0; i < hand.length; i++)
            if (i < _cardAnims.length)
              _buildCard(
                context,
                index: i,
                total: hand.length,
                centerX: centerX,
                card: hand[i],
                draggingId: draggingId,
              ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required int index,
    required int total,
    required double centerX,
    required PlayingCard card,
    required String? draggingId,
  }) {
    final angle     = _angleForIndex(index, total);
    final offset    = _positionForAngle(angle);
    final lift      = _verticalLiftForIndex(index, total);
    final isHovered = _hoveredIndex == index;
    final isDragging = draggingId == card.id;
    final anim      = _cardAnims[index];

    return AnimatedBuilder(
      animation: anim,
      builder: (ctx, child) {
        // Clamped — Curves.easeOut is bounded, but defensive against future changes
        final t = anim.value.clamp(0.0, 1.0);

        return Positioned(
          bottom: offset.dy + lift + (isHovered ? 22 : 0),
          left:   centerX + offset.dx - _cardW / 2,
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1.0 - t) * 70.0),
              child: child,
            ),
          ),
        );
      },
      child: Transform.rotate(
        angle: angle,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit:  (_) => setState(() => _hoveredIndex = null),
          child: DraggableCardWidget(
            card:          card,
            width:         _cardW,
            height:        _cardH,
            isDragging:    isDragging,
            isHighlighted: isHovered,
            onDragStarted: () => context
                .read<CardGameBloc>()
                .add(CardGameCardDragStarted(card.id)),
            onDragEnd: () =>
                context.read<CardGameBloc>().add(CardGameCardDragEnded()),
          ),
        ),
      ),
    );
  }
}
