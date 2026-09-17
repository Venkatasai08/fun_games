// lib/draftclash/screens/pnp_game_screen.dart
//
// Online Pass & Play Game Screen.
// Backed by PnPBloc which writes every action to Firestore so spectators can
// watch from the Live Arena.
//
// Layout phases controlled by PnPLoaded.phase:
//   'pass'   → _PassInterstitial: fullscreen "pass the phone" overlay
//   'play'   → _PlayView: identical to the online GameLayout
//   'result' → _PnPResultOverlay: winner + board summary
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/pass_and_play/pnp_bloc.dart';
import '../models/board_slot.dart';
import '../models/draft_card.dart';
import '../models/draft_member.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/game/game_timer_dial.dart';

// ── Palette (matches rest of DraftClash) ──────────────────────────────────────
const _ink = Color(0xFF050510);
const _bg = Color(0xFF07070F);
const _surf = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _teal = Color(0xFF00D4AA);
const _amber = Color(0xFFF4A11D);
const _green = Color(0xFF3ADE80);
const _gold = Color(0xFFFFD700);
const _red = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtSub = Color(0xFF7A78A8);
const _txtMut = Color(0xFF6A6898);

// ─────────────────────────────────────────────────────────────────────────────
// Entry widget — provides the BLoC and fires PnPInitialized
// ─────────────────────────────────────────────────────────────────────────────

class PnPGameScreen extends StatelessWidget {
  final String roomId;
  final String p1Id;
  final String p2Id;
  final String p1Name;
  final String p2Name;
  final Map<String, DraftCard> cardCache;

  const PnPGameScreen({
    super.key,
    required this.roomId,
    required this.p1Id,
    required this.p2Id,
    required this.p1Name,
    required this.p2Name,
    required this.cardCache,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PnPBloc(
        p1Id: p1Id,
        p2Id: p2Id,
        p1Name: p1Name,
        p2Name: p2Name,
        cardCache: cardCache,
      )..add(PnPInitialized(roomId)),
      child: const _PnPView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PnPView — listens for side-effects, delegates rendering by phase
// ─────────────────────────────────────────────────────────────────────────────

class _PnPView extends StatelessWidget {
  const _PnPView();

  PnPLoaded? _extractLoaded(PnPState state) {
    if (state is PnPLoaded) return state;
    if (state is PnPHapticFeedback) return state.loaded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PnPBloc, PnPState>(
      listenWhen: (_, s) => s is PnPHapticFeedback,
      listener: (_, state) {
        if (state is PnPHapticFeedback) HapticFeedback.mediumImpact();
      },
      builder: (context, state) {
        // Loading
        if (state is PnPLoading) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: CircularProgressIndicator(color: _violet, strokeWidth: 2),
            ),
          );
        }
        // Error
        if (state is PnPError) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: _red, size: 40),
                const SizedBox(height: 12),
                Text(state.message,
                    style: const TextStyle(color: _txtSub),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back', style: TextStyle(color: _violet)),
                ),
              ]),
            ),
          );
        }

        final loaded = _extractLoaded(state);
        if (loaded == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: switch (loaded.phase) {
                'pass' => _PassInterstitial(
                    loaded: loaded,
                    key: ValueKey('pass_${loaded.currentPlayerId}')),
                'result' => _PnPResultOverlay(
                    loaded: loaded, key: const ValueKey('result')),
                _ => _PlayView(loaded: loaded, key: const ValueKey('play')),
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 1 — Pass the phone interstitial
// ─────────────────────────────────────────────────────────────────────────────

class _PassInterstitial extends StatelessWidget {
  final PnPLoaded loaded;
  const _PassInterstitial({required this.loaded, super.key});

  Color get _playerColor => loaded.isP1Turn ? _violet : _teal;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Room code chip at top
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _raised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _bdr),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility_rounded, size: 12, color: _txtMut),
                const SizedBox(width: 5),
                Text(
                  'Spectators watching • #${loaded.room.code}',
                  style: const TextStyle(fontSize: 10, color: _txtMut),
                ),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _raised,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _bdr),
                ),
                child:
                    const Icon(Icons.close_rounded, color: _txtMut, size: 16),
              ),
            ),
          ]),
        ),

        const Spacer(),

        // Phone icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _playerColor.withOpacity(0.1),
            border: Border.all(color: _playerColor.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: _playerColor.withOpacity(0.3), blurRadius: 32)
            ],
          ),
          child: Icon(Icons.smartphone_rounded, color: _playerColor, size: 46),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),
        const Text('Pass to',
                style: TextStyle(
                    fontSize: 15,
                    color: _txtSub,
                    decoration: TextDecoration.none))
            .animate()
            .fadeIn(delay: 150.ms),
        const SizedBox(height: 8),
        Text(
          loaded.currentName,
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _playerColor,
              decoration: TextDecoration.none),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),
        const SizedBox(height: 10),
        const Text("Hand the phone over, then tap Ready",
                style: TextStyle(
                    fontSize: 13,
                    color: _txtSub,
                    decoration: TextDecoration.none))
            .animate()
            .fadeIn(delay: 300.ms),

        const Spacer(),

        // Scores summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(children: [
            _ScorePill(
                name: loaded.p1Name,
                score: loaded.p1Score,
                color: _violet),
            const Spacer(),
            const Text('vs', style: TextStyle(color: _txtMut, fontSize: 12)),
            const Spacer(),
            _ScorePill(
                name: loaded.p2Name,
                score: loaded.p2Score,
                color: _teal,
                alignRight: true),
          ]),
        ).animate().fadeIn(delay: 350.ms),

        const SizedBox(height: 28),

        // Ready button
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => context.read<PnPBloc>().add(PnPPassConfirmed()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _playerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("I'm Ready — Show my turn",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ).animate().fadeIn(delay: 420.ms),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 2 — Active play view (identical layout to online GameLayout)
// ─────────────────────────────────────────────────────────────────────────────

class _PlayView extends StatelessWidget {
  final PnPLoaded loaded;
  const _PlayView({required this.loaded, super.key});

  Map<String, DraftCard?> _cardMap(DraftMember? member) {
    if (member == null) return {};
    return {
      for (final slot in BoardSlot.ordered)
        if (member.board[slot.key] != null)
          slot.key: loaded.cardCache[member.board[slot.key]!],
    };
  }

  @override
  Widget build(BuildContext context) {
    final myMap = _cardMap(loaded.currentMember);
    final oppMap = _cardMap(loaded.opponentMember);

    return Column(
      children: [
        // ── Top bar ────────────────────────────────────────────────────
        _PnPTopBar(loaded: loaded),

        // ── Opponent player bar ────────────────────────────────────────
        _PnPPlayerBar(
          name: loaded.opponentName,
          score: loaded.opponentScore.toInt(),
          accent: loaded.isP1Turn ? _teal : _violet,
          isActive: false,
          isOpponent: true,
        ).animate().fadeIn(duration: 250.ms),

        // ── Versus board ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: DraftBoardWidget(
              cardMap: const {},
              versusMode: true,
              leftMap: oppMap,
              rightMap: myMap,
              interactive: loaded.currentCard != null && !loaded.isAssigning,
              isMyTurn: true,
              onSlotTapped: (slot) =>
                  context.read<PnPBloc>().add(PnPCardAssigned(slot)),
            ),
          ),
        ),

        // ── Bottom panel ───────────────────────────────────────────────
        _PnPBottomPanel(loaded: loaded),

        // ── My player bar ──────────────────────────────────────────────
        _PnPPlayerBar(
          name: loaded.currentName,
          score: loaded.currentScore.toInt(),
          accent: loaded.isP1Turn ? _violet : _teal,
          isActive: true,
          isOpponent: false,
        ).animate().fadeIn(duration: 250.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _PnPTopBar extends StatelessWidget {
  final PnPLoaded loaded;
  const _PnPTopBar({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final remaining = BoardSlot.ordered.length * 2 -
        (loaded.p1Member?.board.values.where((v) => v != null).length ?? 0) -
        (loaded.p2Member?.board.values.where((v) => v != null).length ?? 0);

    return Container(
      color: _surf,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _txtMut, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loaded.room.roomName ?? 'Pass & Play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _txtPri)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _violet.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _violet.withOpacity(0.3)),
                      ),
                      child: Text('# ${loaded.room.code}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _violet)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.visibility_rounded,
                        size: 10, color: _txtMut),
                    const SizedBox(width: 3),
                    const Text('Spectatable',
                        style: TextStyle(fontSize: 9, color: _txtMut)),
                  ]),
                ]),
          ),
          // Picks remaining badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _amber.withOpacity(0.35)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$remaining',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _amber,
                      height: 1)),
              const Text('left',
                  style: TextStyle(
                      fontSize: 8, color: _amber, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 1 - (remaining / (BoardSlot.ordered.length * 2)),
            backgroundColor: _bdr,
            valueColor: const AlwaysStoppedAnimation<Color>(_violet),
            minHeight: 2,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player bar
// ─────────────────────────────────────────────────────────────────────────────

class _PnPPlayerBar extends StatelessWidget {
  final String name;
  final int score;
  final Color accent;
  final bool isActive;
  final bool isOpponent;
  const _PnPPlayerBar({
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
          top: isOpponent
              ? BorderSide.none
              : BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr),
          bottom: isOpponent
              ? BorderSide(color: isActive ? accent.withOpacity(0.35) : _bdr)
              : BorderSide.none,
        ),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(
                color: accent.withOpacity(isActive ? 0.65 : 0.25), width: 1.5),
            boxShadow: isActive
                ? [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8)]
                : null,
          ),
          child: Center(
              child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accent.withOpacity(isActive ? 0.95 : 0.55)),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _txtPri : _txtMut))),
        if (isActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text('YOUR TURN',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 10),
        ],
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
            Text('$score',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: accent)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel — timer + card preview + skip button
// ─────────────────────────────────────────────────────────────────────────────

class _PnPBottomPanel extends StatelessWidget {
  final PnPLoaded loaded;
  const _PnPBottomPanel({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final card = loaded.currentCard;
    final skipUsed = loaded.currentSkipUsed;
    final canSkip = !skipUsed && card != null;
    final accentColor = loaded.isP1Turn ? _violet : _teal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surf,
        border: const Border(
            top: BorderSide(color: _bdr), bottom: BorderSide(color: _bdr)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Timer dial
        SizedBox(
          width: 60,
          height: 60,
          child: GameTimerDial(seconds: loaded.countdownSeconds),
        ),
        const SizedBox(width: 12),
        // Card preview
        Expanded(
          child: card != null
              ? _CardPreview(card: card, accent: accentColor)
              : Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: _raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                  ),
                  child: const Center(
                      child: Text('No card',
                          style: TextStyle(fontSize: 11, color: _txtMut))),
                ),
        ),
        const SizedBox(width: 12),
        // Skip button
        GestureDetector(
          onTap: canSkip
              ? () => context.read<PnPBloc>().add(PnPSkipRequested())
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: canSkip ? _amber.withOpacity(0.10) : _raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canSkip ? _amber.withOpacity(0.45) : _bdr,
                width: canSkip ? 1.5 : 1,
              ),
              boxShadow: canSkip
                  ? [BoxShadow(color: _amber.withOpacity(0.18), blurRadius: 10)]
                  : null,
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                skipUsed ? Icons.block_rounded : Icons.skip_next_rounded,
                size: 18,
                color: canSkip ? _amber : _txtMut.withOpacity(0.35),
              ),
              const SizedBox(height: 3),
              Text(
                skipUsed ? 'USED' : 'SKIP',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: canSkip ? _amber : _txtMut.withOpacity(0.35)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card preview strip
// ─────────────────────────────────────────────────────────────────────────────

Color _tierGlow(double level) {
  if (level >= 9) return const Color(0xFFFFAA00);
  if (level >= 7) return const Color(0xFFBB6CFF);
  if (level >= 4) return const Color(0xFF38C7FF);
  return const Color(0xFF3ADE80);
}

class _CardPreview extends StatelessWidget {
  final DraftCard card;
  final Color accent;
  const _CardPreview({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    final glow = _tierGlow(card.level);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        color: glow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glow.withOpacity(0.6), width: 1.5),
        boxShadow: [BoxShadow(color: glow.withOpacity(0.25), blurRadius: 14)],
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
          child: SizedBox(
            width: 60,
            height: 60,
            child: card.imageUrl.isNotEmpty
                ? Image.network(card.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(glow))
                : _initial(glow),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ON TABLE',
                style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: glow.withOpacity(0.55),
                    letterSpacing: 1.2)),
            const SizedBox(height: 3),
            Text(card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _txtPri)),
            if (card.franchiseName.isNotEmpty)
              Text(card.franchiseName.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      color: glow.withOpacity(0.5),
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600)),
          ],
        )),
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: glow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glow.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: glow.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Center(
              child: Text('${card.level.toInt()}',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: glow))),
        ),
      ]),
    )
        .animate()
        .scaleXY(begin: 0.94, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 180.ms);
  }

  Widget _initial(Color glow) => Container(
      color: glow.withOpacity(0.08),
      child: Center(
          child: Text(card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: glow.withOpacity(0.25)))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 3 — Result overlay
// ─────────────────────────────────────────────────────────────────────────────

class _PnPResultOverlay extends StatelessWidget {
  final PnPLoaded loaded;
  const _PnPResultOverlay({required this.loaded, super.key});

  @override
  Widget build(BuildContext context) {
    final room = loaded.room;
    final p1 = loaded.p1Member;
    final p2 = loaded.p2Member;
    final p1Won = room.winnerId == loaded.p1Id;
    final p2Won = room.winnerId == loaded.p2Id;
    final isDraw = room.winnerId == null;

    final winColor = isDraw
        ? _amber
        : p1Won
            ? _violet
            : _teal;
    final headline = isDraw
        ? "It's a Draw!"
        : p1Won
            ? '${loaded.p1Name} Wins!'
            : '${loaded.p2Name} Wins!';

    return Container(
      color: const Color(0xEE07070F),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(children: [
            // Headline
            Text(isDraw ? '🤝' : '🏆', style: const TextStyle(fontSize: 64))
                .animate()
                .scale(
                    begin: const Offset(0.4, 0.4),
                    duration: 580.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 12),
            Text(headline,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: winColor,
                        decoration: TextDecoration.none))
                .animate()
                .fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // Score cards — computed from board + cardCache
            Row(children: [
              Expanded(
                  child: _FinalScoreCard(
                name: loaded.p1Name,
                score: loaded.p1Score,
                color: _violet,
                isWinner: p1Won,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _FinalScoreCard(
                name: loaded.p2Name,
                score: loaded.p2Score,
                color: _teal,
                isWinner: p2Won,
              )),
            ]).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 16),

            // Board comparison
            _BoardComparison(
              p1Name: loaded.p1Name,
              p2Name: loaded.p2Name,
              p1Member: p1,
              p2Member: p2,
              cardCache: loaded.cardCache,
            ).animate().fadeIn(delay: 420.ms),

            const SizedBox(height: 28),

            // Back to lobby
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_rounded, size: 17),
                label: const Text('Back to Lobby',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: winColor,
                  foregroundColor:
                      isDraw || p2Won ? Colors.white : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ).animate().fadeIn(delay: 540.ms),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Final score card
// ─────────────────────────────────────────────────────────────────────────────

class _FinalScoreCard extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool isWinner;
  const _FinalScoreCard({
    required this.name,
    required this.score,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? color.withOpacity(0.1) : _surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? color.withOpacity(0.5) : _bdr,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        if (isWinner)
          const Icon(Icons.emoji_events_rounded, color: _gold, size: 20),
        Text(name,
            style: const TextStyle(
                fontSize: 12, color: _txtSub, decoration: TextDecoration.none),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(score.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
                decoration: TextDecoration.none)),
        const Text('pts',
            style: TextStyle(
                fontSize: 11, color: _txtSub, decoration: TextDecoration.none)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Board comparison table
// ─────────────────────────────────────────────────────────────────────────────

class _BoardComparison extends StatelessWidget {
  final String p1Name;
  final String p2Name;
  final DraftMember? p1Member;
  final DraftMember? p2Member;
  final Map<String, DraftCard> cardCache;
  const _BoardComparison({
    required this.p1Name,
    required this.p2Name,
    required this.p1Member,
    required this.p2Member,
    required this.cardCache,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _bdr))),
            child: Row(children: [
              Expanded(
                  child: Text(p1Name,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _violet,
                          decoration: TextDecoration.none),
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 44),
              Expanded(
                  child: Text(p2Name,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                          decoration: TextDecoration.none),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
          // Slot rows
          ...BoardSlot.ordered.asMap().entries.map((e) {
            final isLast = e.key == BoardSlot.ordered.length - 1;
            final slot = e.value;
            final p1Card = p1Member?.board[slot.key] != null
                ? cardCache[p1Member!.board[slot.key]!]
                : null;
            final p2Card = p2Member?.board[slot.key] != null
                ? cardCache[p2Member!.board[slot.key]!]
                : null;

            return Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: _bdr, width: 0.5)),
              ),
              child: IntrinsicHeight(
                child: Row(children: [
                  Expanded(
                      child: _CompactCardCell(
                          card: p1Card, color: _violet, isLeft: true)),
                  Container(
                    width: 44,
                    decoration: const BoxDecoration(
                        border: Border.symmetric(
                            vertical: BorderSide(color: _bdr, width: 0.5))),
                    child: Center(
                        child: Text(
                      slot.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 6.5,
                          fontWeight: FontWeight.w700,
                          color: _txtMut,
                          height: 1.3,
                          decoration: TextDecoration.none),
                    )),
                  ),
                  Expanded(
                      child: _CompactCardCell(
                          card: p2Card, color: _teal, isLeft: false)),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }
}

class _CompactCardCell extends StatelessWidget {
  final DraftCard? card;
  final Color color;
  final bool isLeft;
  const _CompactCardCell(
      {required this.card, required this.color, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Text('—',
              style: TextStyle(
                  fontSize: 12,
                  color: _txtMut.withOpacity(0.4),
                  decoration: TextDecoration.none)),
        ),
      );
    }
    final glow = _tierGlow(card!.level);
    final thumb = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: glow.withOpacity(0.12),
        border: Border.all(color: glow.withOpacity(0.3)),
      ),
      child: card!.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(card!.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                      child: Text(card!.name.isNotEmpty ? card!.name[0] : '?',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: glow.withOpacity(0.7),
                              decoration: TextDecoration.none)))))
          : Center(
              child: Text(card!.name.isNotEmpty ? card!.name[0] : '?',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: glow.withOpacity(0.7),
                      decoration: TextDecoration.none))),
    );

    final nameLevel = Expanded(
        child: Column(
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(card!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: _txtPri,
                decoration: TextDecoration.none)),
        Text('Lv ${card!.level.toInt()}',
            style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: glow,
                decoration: TextDecoration.none)),
      ],
    ));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
          children: isLeft
              ? [thumb, const SizedBox(width: 6), nameLevel]
              : [nameLevel, const SizedBox(width: 6), thumb]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper
// ─────────────────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool alignRight;
  const _ScorePill(
      {required this.name,
      required this.score,
      required this.color,
      this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 10, color: _txtSub, decoration: TextDecoration.none),
            overflow: TextOverflow.ellipsis),
        Text(score.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
                decoration: TextDecoration.none)),
      ],
    );
  }
}
