// lib/draftclash/widgets/game/game_layout.dart
//
// Portrait-first game screen layout matching the reference image:
//
//  ┌──────────────────────────────────────┐
//  │  Opponent username + score           │
//  ├──────────────────────────────────────┤
//  │                                      │
//  │  3-column versus board               │
//  │  [opp image] | SLOT LABEL | [my img] │
//  │  …6 rows…                            │
//  │                                      │
//  ├──────────────────────────────────────┤
//  │  Timer  │  Current card  │  Skip     │
//  ├──────────────────────────────────────┤
//  │  My username + score                 │
//  └──────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/game/draft_game_bloc.dart';
import '../../models/draft_card.dart';
import '../../models/draft_member.dart';
import '../../models/slot_role.dart';
import '../../services/draft_sound_service.dart';
import 'game_skip_button.dart';
import 'game_timer_dial.dart';
import 'game_waiting_slots.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF6E44FF);
const _amber  = Color(0xFFF4A11D);
const _green  = Color(0xFF43E97B);
const _txtPri = Color(0xFFEAE8FF);
const _txtMut = Color(0xFF6A6898);

class GameLayout extends StatelessWidget {
  final DraftGameLoaded loaded;
  const GameLayout({super.key, required this.loaded});

  Map<String, DraftCard?> _cardMap(DraftMember? member) {
    if (member == null) return {};
    return {
      for (final slot in loaded.slots)
        if (member.board[slot.key] != null)
          slot.key: loaded.cardCache[member.board[slot.key]!] ??
              DraftCard(
                id: member.board[slot.key]!,
                franchiseIds: [],
                franchiseName: '',
                name: member.board[slot.key]!
                    .substring(0, math.min(4, member.board[slot.key]!.length))
                    .toUpperCase(),
                description: '',
                level: 5,
                imageUrl: '',
              ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final myMap    = _cardMap(loaded.myMember);
    final oppMap   = _cardMap(loaded.opponentMember);
    final isMyTurn = loaded.isMyTurn;
    final hasOpp   = loaded.opponentMember != null;

    final myName  = loaded.myMember?.username ?? 'You';
    final oppName = loaded.opponentMember?.username ?? 'Opponent';
    // Scores computed from board + cardCache — never stored in Firestore
    final myScore  = loaded.myScore;
    final oppScore = loaded.opponentScore;

    return Column(
      children: [
        // ── Opponent header bar ────────────────────────────────────────
        _PlayerBar(
          name: oppName,
          score: oppScore.toInt(),
          accent: _violet,
          isActive: !isMyTurn && hasOpp,
          isOpponent: true,
        ).animate().fadeIn(duration: 300.ms),

        // ── Versus board ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: hasOpp
                ? _DynamicVersusBoard(
                    slots: loaded.slots,
                    leftMap: oppMap,
                    rightMap: myMap,
                    interactive: isMyTurn,
                    onSlotTapped: (slot) {
                      DraftSoundService.tapSound();
                      context
                          .read<DraftGameBloc>()
                          .add(DraftGameCardAssigned(slot));
                    },
                  )
                : const GameWaitingSlots(),
          ),
        ),

        // ── Bottom panel: timer + card + skip ──────────────────────────
        _BottomPanel(loaded: loaded),

        // ── My header bar ──────────────────────────────────────────────
        _PlayerBar(
          name: myName,
          score: myScore.toInt(),
          accent: _amber,
          isActive: isMyTurn,
          isOpponent: false,
        ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player bar (top = opponent, bottom = me)
// ─────────────────────────────────────────────────────────────────────────────

class _DynamicVersusBoard extends StatelessWidget {
  final List<SlotRole> slots;
  final Map<String, DraftCard?> leftMap;
  final Map<String, DraftCard?> rightMap;
  final bool interactive;
  final void Function(SlotRole slot) onSlotTapped;

  const _DynamicVersusBoard({
    required this.slots,
    required this.leftMap,
    required this.rightMap,
    required this.interactive,
    required this.onSlotTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final slot in slots) ...[
          _DynamicSlotRow(
            slot: slot,
            leftCard: leftMap[slot.key],
            rightCard: rightMap[slot.key],
            canTap: interactive && rightMap[slot.key] == null,
            onTap: () => onSlotTapped(slot),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DynamicSlotRow extends StatelessWidget {
  final SlotRole slot;
  final DraftCard? leftCard;
  final DraftCard? rightCard;
  final bool canTap;
  final VoidCallback onTap;

  const _DynamicSlotRow({
    required this.slot,
    required this.leftCard,
    required this.rightCard,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _slotAccent(slot);
    return Row(
      children: [
        Expanded(child: _SlotCard(card: leftCard, accent: _violet)),
        const SizedBox(width: 8),
        Container(
          width: 92,
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: canTap ? accent.withOpacity(0.13) : _raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canTap ? accent.withOpacity(0.55) : _bdr,
              width: canTap ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_slotIcon(slot), size: 17, color: accent),
              const SizedBox(height: 5),
              Text(
                slot.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _txtPri,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canTap ? onTap : null,
            child: Stack(
              children: [
                _SlotCard(card: rightCard, accent: _amber),
                if (canTap)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent, width: 1.5),
                      ),
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.6)),
                          ),
                          child: Icon(Icons.add_rounded,
                              color: accent, size: 20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final DraftCard? card;
  final Color accent;

  const _SlotCard({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: card == null ? _surf : accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: card == null ? _bdr : accent.withOpacity(0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: card == null
          ? Center(
              child: Icon(Icons.grid_view_rounded,
                  size: 18, color: _txtMut.withOpacity(0.35)),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (card!.imageUrl.isNotEmpty)
                  Image.network(
                    card!.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialCard(card: card!, accent: accent),
                  )
                else
                  _InitialCard(card: card!, accent: accent),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    color: Colors.black.withOpacity(0.62),
                    child: Text(
                      card!.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InitialCard extends StatelessWidget {
  final DraftCard card;
  final Color accent;

  const _InitialCard({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withOpacity(0.08),
      child: Center(
        child: Text(
          card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: accent.withOpacity(0.55),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

Color _slotAccent(SlotRole slot) =>
    slot.isDecrement ? const Color(0xFFE8445A) : _violet;

IconData _slotIcon(SlotRole slot) {
  switch (SlotRole.iconKeyFor(slot.name)) {
    case 'captain':
      return Icons.star_rounded;
    case 'vice_captain':
      return Icons.star_half_rounded;
    case 'tank':
      return Icons.shield_rounded;
    case 'duelist':
      return Icons.flash_on_rounded;
    case 'support':
      return Icons.favorite_rounded;
    case 'traitor':
      return Icons.dangerous_rounded;
    default:
      return slot.isDecrement
          ? Icons.trending_down_rounded
          : Icons.grid_view_rounded;
  }
}

class _PlayerBar extends StatelessWidget {
  final String name;
  final int    score;
  final Color  accent;
  final bool   isActive;
  final bool   isOpponent;

  const _PlayerBar({
    required this.name,
    required this.score,
    required this.accent,
    required this.isActive,
    required this.isOpponent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? accent.withOpacity(0.07) : _surf,
        border: Border(
          top:    isOpponent ? BorderSide.none : BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr),
          bottom: isOpponent ? BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr) : BorderSide.none,
        ),
      ),
      child: Row(children: [
        // Avatar circle
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(color: accent.withOpacity(isActive ? 0.6 : 0.25), width: 1.5),
            boxShadow: isActive
                ? [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8)]
                : null,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: accent.withOpacity(isActive ? 0.95 : 0.55),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isActive ? _txtPri : _txtMut,
            ),
          ),
        ),
        // Turn indicator
        if (isActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text(
              isOpponent ? 'PICKING' : 'YOUR TURN',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900,
                color: accent, letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded, size: 11, color: accent),
            const SizedBox(width: 4),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: accent),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel: timer ring + current card preview + skip button
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final DraftGameLoaded loaded;
  const _BottomPanel({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = loaded.isMyTurn;
    final card     = loaded.currentCard;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surf,
        border: const Border(
          top:    BorderSide(color: _bdr),
          bottom: BorderSide(color: _bdr),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Timer ring ───────────────────────────────────────────────
          SizedBox(
            width: 60, height: 60,
            child: GameTimerDial(seconds: loaded.countdownSeconds),
          ),

          const SizedBox(width: 12),

          // ── Current card preview ─────────────────────────────────────
          Expanded(
            child: card != null
                ? _CardPreview(card: card, isMyTurn: isMyTurn)
                : Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _bdr),
                    ),
                    child: Center(
                      child: Text('Waiting for card…',
                          style: TextStyle(
                            fontSize: 11, color: _txtMut.withOpacity(0.55))),
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          // ── Skip button or "wait" placeholder ────────────────────────
          SizedBox(
            width: 60,
            child: isMyTurn
                ? GameSkipButton(loaded: loaded)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty_rounded,
                          size: 18, color: _txtMut.withOpacity(0.4)),
                      const SizedBox(height: 4),
                      Text('WAIT',
                          style: TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: _txtMut.withOpacity(0.35), letterSpacing: 1,
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card preview strip (inside bottom panel)
// ─────────────────────────────────────────────────────────────────────────────

Color _tierGlow(double level) {
  if (level >= 9) return const Color(0xFFFFAA00);
  if (level >= 7) return const Color(0xFFBB6CFF);
  if (level >= 4) return const Color(0xFF38C7FF);
  return const Color(0xFF3ADE80);
}

class _CardPreview extends StatelessWidget {
  final DraftCard card;
  final bool isMyTurn;

  const _CardPreview({required this.card, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    final glow = _tierGlow(card.level);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        color: glow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glow.withOpacity(isMyTurn ? 0.6 : 0.25),
          width: isMyTurn ? 1.5 : 1,
        ),
        boxShadow: isMyTurn
            ? [BoxShadow(color: glow.withOpacity(0.25), blurRadius: 14)]
            : null,
      ),
      child: Row(children: [
        // Thumbnail
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
          child: SizedBox(
            width: 60, height: 60,
            child: card.imageUrl.isNotEmpty
                ? Image.network(card.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(glow))
                : _initial(glow),
          ),
        ),
        const SizedBox(width: 10),
        // Name + franchise
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMyTurn ? 'ON TABLE' : 'CURRENT CARD',
              style: TextStyle(
                fontSize: 8.5, fontWeight: FontWeight.w700,
                color: glow.withOpacity(0.55), letterSpacing: 1.2),
            ),
            const SizedBox(height: 3),
            Text(card.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _txtPri)),
            if (card.franchiseName.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(card.franchiseName.toUpperCase(),
                style: TextStyle(fontSize: 9, color: glow.withOpacity(0.5),
                  letterSpacing: 0.6, fontWeight: FontWeight.w600)),
            ],
          ],
        )),
        // Level badge
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: glow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glow.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: glow.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Center(child: Text(
            '${card.level.toInt()}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: glow),
          )),
        ),
      ]),
    ).animate().scaleXY(begin: 0.94, duration: 280.ms, curve: Curves.easeOutCubic).fadeIn(duration: 180.ms);
  }

  Widget _initial(Color glow) => Container(
    color: glow.withOpacity(0.08),
    child: Center(child: Text(
      card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
        color: glow.withOpacity(0.25)))));
}
