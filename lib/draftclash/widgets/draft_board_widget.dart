// lib/draftclash/widgets/draft_board_widget.dart
//
// Redesigned to match the reference image:
// A 3-column layout per row:  [Left card image] | [Slot label] | [Right card image]
// Left  = opponent board (or my board when flipped)
// Centre = slot name
// Right = my board (or opponent board when flipped)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fun_games/draftclash/models/board_slot.dart';
import '../models/draft_card.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg    = Color(0xFF0A0A14);
const _card  = Color(0xFF111120);
const _bdr   = Color(0xFF1E1B38);
const _txtPri= Color(0xFFEAE8FF);
const _txtMut= Color(0xFF6A6898);

// ─── Tier colours ─────────────────────────────────────────────────────────────
Color _tierGlow(double level) {
  if (level >= 9) return const Color(0xFFFFAA00);
  if (level >= 7) return const Color(0xFFBB6CFF);
  if (level >= 4) return const Color(0xFF38C7FF);
  return const Color(0xFF3ADE80);
}

// ─── Slot meta ────────────────────────────────────────────────────────────────
Color _slotAccent(BoardSlot slot) {
  switch (slot) {
    case BoardSlot.captain:     return const Color(0xFFFFD700);
    case BoardSlot.viceCaptain: return const Color(0xFFE0E0E0);
    case BoardSlot.tank:        return const Color(0xFF5EC8FF);
    case BoardSlot.duelist:     return const Color(0xFFFF6B6B);
    case BoardSlot.support:     return const Color(0xFF67E48B);
    case BoardSlot.traitor:     return const Color(0xFFBB6CFF);
  }
}

String _slotDisplayName(BoardSlot slot) {
  switch (slot) {
    case BoardSlot.captain:     return 'CAPTAIN';
    case BoardSlot.viceCaptain: return 'VICE\nCAPTAIN';
    case BoardSlot.tank:        return 'TANK';
    case BoardSlot.duelist:     return 'DUELIST';
    case BoardSlot.support:     return 'SUPPORT';
    case BoardSlot.traitor:     return 'TRAITOR';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DraftBoardWidget — 3-column versus layout matching the reference image
//
// leftMap  = cards for the left column  (opponent)
// rightMap = cards for the right column (you)
// If only cardMap is provided (legacy single-player use), it fills rightMap
// and leftMap stays empty.
// ─────────────────────────────────────────────────────────────────────────────

class DraftBoardWidget extends StatelessWidget {
  // Legacy single-side usage
  final Map<String, DraftCard?> cardMap;
  final bool interactive;
  final bool isMyTurn;
  final bool compact;
  final void Function(BoardSlot slot)? onSlotTapped;

  // Versus layout (used by GameLayout)
  final Map<String, DraftCard?> leftMap;
  final Map<String, DraftCard?> rightMap;
  final bool versusMode;

  const DraftBoardWidget({
    super.key,
    required this.cardMap,
    this.interactive = false,
    this.isMyTurn = false,
    this.compact = false,
    this.onSlotTapped,
    this.leftMap = const {},
    this.rightMap = const {},
    this.versusMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (versusMode) {
      return _VersusBoard(
        leftMap: leftMap,
        rightMap: rightMap,
        interactive: interactive,
        isMyTurn: isMyTurn,
        onSlotTapped: onSlotTapped,
      );
    }
    // Legacy: single-column compact strip list
    return Column(
      children: [
        for (int i = 0; i < BoardSlot.ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _LegacySlotStrip(
            slot: BoardSlot.ordered[i],
            card: cardMap[BoardSlot.ordered[i].key],
            interactive: interactive &&
                isMyTurn &&
                cardMap[BoardSlot.ordered[i].key] == null,
            compact: compact,
            onTap: () => onSlotTapped?.call(BoardSlot.ordered[i]),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERSUS BOARD — the new 3-column layout matching the reference image
// ═══════════════════════════════════════════════════════════════════════════════

class _VersusBoard extends StatelessWidget {
  final Map<String, DraftCard?> leftMap;
  final Map<String, DraftCard?> rightMap;
  final bool interactive;
  final bool isMyTurn;
  final void Function(BoardSlot slot)? onSlotTapped;

  const _VersusBoard({
    required this.leftMap,
    required this.rightMap,
    required this.interactive,
    required this.isMyTurn,
    required this.onSlotTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          for (int i = 0; i < BoardSlot.ordered.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: _bdr.withOpacity(0.45)),
            _VersusRow(
              slot: BoardSlot.ordered[i],
              leftCard: leftMap[BoardSlot.ordered[i].key],
              rightCard: rightMap[BoardSlot.ordered[i].key],
              interactive: interactive &&
                  isMyTurn &&
                  rightMap[BoardSlot.ordered[i].key] == null,
              onTap: () => onSlotTapped?.call(BoardSlot.ordered[i]),
              index: i,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Single versus row ────────────────────────────────────────────────────────

class _VersusRow extends StatelessWidget {
  final BoardSlot slot;
  final DraftCard? leftCard;
  final DraftCard? rightCard;
  final bool interactive;
  final VoidCallback onTap;
  final int index;

  const _VersusRow({
    required this.slot,
    required this.leftCard,
    required this.rightCard,
    required this.interactive,
    required this.onTap,
    required this.index,
  });

  static const double _rowH = 68.0;
  static const double _imgW = 68.0;

  @override
  Widget build(BuildContext context) {
    final accent = _slotAccent(slot);

    return GestureDetector(
      onTap: interactive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _rowH,
        decoration: BoxDecoration(
          color: interactive
              ? accent.withOpacity(0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // ── LEFT card image ────────────────────────────────────────
            _CardThumb(
              card: leftCard,
              width: _imgW,
              height: _rowH,
              roundLeft: index == 0,
              roundRight: false,
              align: Alignment.centerRight,
            ),

            // ── Centre label ──────────────────────────────────────────
            Expanded(
              child: Container(
                height: _rowH,
                color: _card,
                child: Center(
                  child: interactive
                      ? _InteractiveCentreLabel(accent: accent, slot: slot)
                      : _StaticCentreLabel(slot: slot, accent: accent),
                ),
              ),
            ),

            // ── RIGHT card image ───────────────────────────────────────
            _CardThumb(
              card: rightCard,
              width: _imgW,
              height: _rowH,
              roundLeft: false,
              roundRight: index == BoardSlot.ordered.length - 1,
              align: Alignment.centerLeft,
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: index * 40))
          .fadeIn(duration: 220.ms)
          .slideY(begin: 0.05, end: 0, duration: 220.ms, curve: Curves.easeOut),
    );
  }
}

// ─── Card thumbnail (left or right) ──────────────────────────────────────────

class _CardThumb extends StatelessWidget {
  final DraftCard? card;
  final double width;
  final double height;
  final bool roundLeft;
  final bool roundRight;
  final Alignment align;

  const _CardThumb({
    required this.card,
    required this.width,
    required this.height,
    required this.roundLeft,
    required this.roundRight,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft:     Radius.circular(roundLeft ? 15 : 0),
      bottomLeft:  Radius.circular(roundLeft ? 15 : 0),
      topRight:    Radius.circular(roundRight ? 15 : 0),
      bottomRight: Radius.circular(roundRight ? 15 : 0),
    );

    if (card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0C1E),
          borderRadius: radius,
        ),
        child: Center(
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1830),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr),
            ),
          ),
        ),
      );
    }

    final glow = _tierGlow(card!.level);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0C1E),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or initial
            if (card!.imageUrl.isNotEmpty)
              Image.network(
                card!.imageUrl,
                fit: BoxFit.cover,
                alignment: align,
                errorBuilder: (_, __, ___) => _initial(glow),
              )
            else
              _initial(glow),

            // Gradient overlay to make border fade toward centre label
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: align == Alignment.centerRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: align == Alignment.centerRight
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0A0A14).withOpacity(0.55),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Level badge bottom corner
            Positioned(
              bottom: 4,
              left: align == Alignment.centerRight ? null : 4,
              right: align == Alignment.centerRight ? 4 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: glow.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: glow.withOpacity(0.5)),
                ),
                child: Text(
                  '${card!.level.toInt()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: glow,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .scaleXY(begin: 0.92, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 200.ms);
  }

  Widget _initial(Color glow) => Container(
    color: const Color(0xFF0D0C1E),
    child: Center(
      child: Text(
        card!.name.isNotEmpty ? card!.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: glow.withOpacity(0.18),
        ),
      ),
    ),
  );
}

// ─── Centre label — static ────────────────────────────────────────────────────

class _StaticCentreLabel extends StatelessWidget {
  final BoardSlot slot;
  final Color accent;
  const _StaticCentreLabel({required this.slot, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        _slotDisplayName(slot),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: _txtPri,
          letterSpacing: 0.5,
          height: 1.25,
        ),
      ),
    );
  }
}

// ─── Centre label — interactive (pulsing tap hint) ────────────────────────────

class _InteractiveCentreLabel extends StatelessWidget {
  final Color accent;
  final BoardSlot slot;
  const _InteractiveCentreLabel({required this.accent, required this.slot});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _slotDisplayName(slot),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: accent,
            letterSpacing: 0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.45)),
          ),
          child: Text(
            'TAP',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 900.ms,
          curve: Curves.easeInOut,
          builder: (_, v, child) =>
              Opacity(opacity: 0.65 + 0.35 * v, child: child),
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEGACY SINGLE-COLUMN STRIP (kept for backward compat)
// ═══════════════════════════════════════════════════════════════════════════════

class _LegacySlotStrip extends StatelessWidget {
  final BoardSlot slot;
  final DraftCard? card;
  final bool interactive;
  final bool compact;
  final VoidCallback onTap;

  const _LegacySlotStrip({
    required this.slot,
    required this.card,
    required this.interactive,
    required this.compact,
    required this.onTap,
  });

  double get _height => compact ? 42.0 : 58.0;

  @override
  Widget build(BuildContext context) {
    if (card != null) return _filledStrip();
    if (interactive) return _interactiveStrip();
    return _emptyStrip();
  }

  Widget _emptyStrip() {
    final accent = _slotAccent(slot);
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1B38)),
      ),
      child: Row(children: [
        Container(width: 3, height: _height,
          decoration: BoxDecoration(color: accent.withOpacity(0.3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)))),
        const SizedBox(width: 12),
        Text(slot.label.toUpperCase(),
          style: TextStyle(fontSize: compact ? 10 : 13, fontWeight: FontWeight.w800,
            color: const Color(0xFF2E2B50), letterSpacing: 1.5)),
        const Spacer(),
      ]),
    );
  }

  Widget _interactiveStrip() {
    const violet = Color(0xFF6E44FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: violet.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: violet.withOpacity(0.5), width: 1.5),
        ),
        child: Row(children: [
          Container(width: 3, height: _height,
            decoration: const BoxDecoration(color: violet,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8)))),
          const SizedBox(width: 12),
          Text(slot.label.toUpperCase(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: violet, letterSpacing: 1.5)),
          const Spacer(),
          const Text('TAP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
            color: violet, letterSpacing: 1)),
          const SizedBox(width: 14),
        ]),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .custom(duration: 1100.ms, curve: Curves.easeInOut,
            builder: (_, v, child) => Opacity(opacity: 0.72 + 0.28 * v, child: child)),
    );
  }

  Widget _filledStrip() {
    final c = card!;
    final glow = _tierGlow(c.level);
    final dark = c.level >= 9
        ? const Color(0xFF1A0E00)
        : c.level >= 7
            ? const Color(0xFF110820)
            : c.level >= 4
                ? const Color(0xFF041220)
                : const Color(0xFF041208);

    return Container(
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [glow.withOpacity(0.18), dark, const Color(0xFF07070F)],
          stops: const [0.0, 0.45, 1.0]),
        border: Border.all(color: glow.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(children: [
          SizedBox(
            width: _height, height: _height,
            child: c.imageUrl.isNotEmpty
                ? Stack(fit: StackFit.expand, children: [
                    Image.network(c.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(glow, dark)),
                    Positioned.fill(child: DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                        colors: [Colors.transparent, dark])))),
                  ])
                : _thumbFallback(glow, dark),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 11 : 14, fontWeight: FontWeight.w800,
              color: const Color(0xFFEAE8FF)))),
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: glow.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: glow.withOpacity(0.4))),
            child: Text('${c.level}',
              style: TextStyle(fontSize: compact ? 13 : 18, fontWeight: FontWeight.w900, color: glow)),
          ),
        ]),
      ),
    ).animate().slideX(begin: -0.08, duration: 280.ms, curve: Curves.easeOutCubic).fadeIn(duration: 200.ms);
  }

  Widget _thumbFallback(Color glow, Color dark) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [glow.withOpacity(0.25), dark])),
    child: Center(child: Text(card!.name.isNotEmpty ? card!.name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: compact ? 18 : 24, fontWeight: FontWeight.w900,
        color: glow.withOpacity(0.5)))));
}
