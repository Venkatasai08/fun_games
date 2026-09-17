// lib/draftclash/screens/spectator_screen.dart
//
// Read-only live view of any ongoing DraftClash game (online or P&P).
// Uses DraftGameBloc with isSpectator: true — all write events are no-ops.
// The UI is identical to the online game but all interactive elements are
// replaced with "watching" indicators.
//
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/game/draft_game_bloc.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../models/board_slot.dart';
import '../models/draft_card.dart';
import '../models/draft_member.dart';
import '../services/draft_service.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/game/game_timer_dial.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF07070F);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _teal   = Color(0xFF00D4AA);
const _amber  = Color(0xFFF4A11D);
const _gold   = Color(0xFFFFD700);
const _red    = Color(0xFFE8445A);
const _txtPri = Color(0xFFEAE8FF);
const _txtSub = Color(0xFF7A78A8);
const _txtMut = Color(0xFF6A6898);

// ─────────────────────────────────────────────────────────────────────────────
// Entry widget — creates a read-only DraftGameBloc
// ─────────────────────────────────────────────────────────────────────────────

class SpectatorScreen extends StatelessWidget {
  final String roomId;
  const SpectatorScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final catalogCards = _readCatalogCards(context);
    if (catalogCards != null) {
      return _SpectatorBlocScope(
        roomId: roomId,
        preloadedCards: catalogCards,
      );
    }

    return FutureBuilder<List<DraftCard>>(
      future: DraftService.getAllCards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: _WatchingIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Text(
                'Could not load spectator cards.',
                style: const TextStyle(color: _txtSub),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _SpectatorBlocScope(
          roomId: roomId,
          preloadedCards: snapshot.data ?? const [],
        );
      },
    );
  }

  List<DraftCard>? _readCatalogCards(BuildContext context) {
    try {
      return context.read<DraftCatalogCubit>().state.allCards;
    } catch (_) {
      return null;
    }
  }
}

class _SpectatorBlocScope extends StatelessWidget {
  final String roomId;
  final List<DraftCard> preloadedCards;

  const _SpectatorBlocScope({
    required this.roomId,
    required this.preloadedCards,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Pass pre-loaded cards from the session catalog so the spectator's
      // DraftGameBloc never needs its own getAllCards() Firestore call.
      create: (_) => DraftGameBloc(
        isSpectator:    true,
        preloadedCards: preloadedCards,
      )..add(DraftGameInitialized(roomId)),
      child: const _SpectatorView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpectatorView
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorView extends StatelessWidget {
  const _SpectatorView();

  DraftGameLoaded? _extractLoaded(DraftGameState state) {
    if (state is DraftGameLoaded) return state;
    if (state is DraftGameHapticFeedback) return state.loaded;
    if (state is DraftGameShowResult) return state.loaded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftGameBloc, DraftGameState>(
      builder: (context, state) {
        // Loading
        if (state is DraftGameLoading) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: _WatchingIndicator()),
          );
        }
        // Error
        if (state is DraftGameError) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            ])),
          );
        }

        final loaded = _extractLoaded(state);
        if (loaded == null) return const SizedBox.shrink();

        // Finished — show read-only result
        if (state is DraftGameShowResult) {
          return Scaffold(
            backgroundColor: _bg,
            body: SafeArea(child: _SpectatorResult(loaded: loaded)),
          );
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(child: _SpectatorGame(loaded: loaded)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live spectator game layout
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorGame extends StatelessWidget {
  final DraftGameLoaded loaded;
  const _SpectatorGame({required this.loaded});

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
    final p1    = loaded.allMembers.isNotEmpty ? loaded.allMembers.first : null;
    final p2    = loaded.allMembers.length > 1 ? loaded.allMembers[1] : null;
    final p1Map = _cardMap(p1);
    final p2Map = _cardMap(p2);

    final currentPickerName = loaded.room.currentTurn != null
        ? (loaded.allMembers
            .cast<DraftMember?>()
            .firstWhere((m) => m!.userId == loaded.room.currentTurn,
                orElse: () => null)
            ?.username ?? '')
        : '';

    return Column(children: [
      _SpectatorTopBar(loaded: loaded),

      if (currentPickerName.isNotEmpty)
        _NowPickingBanner(name: currentPickerName),

      _SpectatorPlayerBar(
        member:       p1,
        score:        p1 != null ? loaded.computeScore(p1) : 0.0,
        accent:       _violet,
        isPickingNow: loaded.room.currentTurn == p1?.userId,
      ).animate().fadeIn(duration: 250.ms),

      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DraftBoardWidget(
            cardMap:    const {},
            versusMode: true,
            leftMap:    p1Map,
            rightMap:   p2Map,
            interactive: false,
            isMyTurn:    false,
          ),
        ),
      ),

      _SpectatorBottomPanel(loaded: loaded),

      _SpectatorPlayerBar(
        member:       p2,
        score:        p2 != null ? loaded.computeScore(p2) : 0.0,
        accent:       _teal,
        isPickingNow: loaded.room.currentTurn == p2?.userId,
      ).animate().fadeIn(duration: 250.ms),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectator top bar
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorTopBar extends StatelessWidget {
  final DraftGameLoaded loaded;
  const _SpectatorTopBar({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final remaining = BoardSlot.ordered.length * 2
        - loaded.allMembers.fold<int>(
            0,
            (sum, m) =>
                sum + m.board.values.where((v) => v != null).length);

    return Container(
      color: _surf,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _raised, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _txtMut, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(loaded.room.roomName ?? 'Draft Clash',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: _txtPri)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _amber.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: _amber, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('WATCHING', style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w800, color: _amber,
                        letterSpacing: 0.8)),
                  ]),
                ),
                const SizedBox(width: 6),
                Text('# ${loaded.room.code}',
                    style: const TextStyle(fontSize: 9, color: _txtMut)),
                if (loaded.room.isPassAndPlay) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _violet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _violet.withOpacity(0.3)),
                    ),
                    child: const Text('P&P', style: TextStyle(fontSize: 8,
                        fontWeight: FontWeight.w800, color: _violet)),
                  ),
                ],
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _raised, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bdr),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$remaining', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: _amber, height: 1)),
              const Text('left', style: TextStyle(fontSize: 8,
                  color: _amber, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 1 - (remaining / (BoardSlot.ordered.length * 2)),
            backgroundColor: _bdr,
            valueColor: const AlwaysStoppedAnimation<Color>(_amber),
            minHeight: 2,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Now picking" animated banner
// ─────────────────────────────────────────────────────────────────────────────

class _NowPickingBanner extends StatelessWidget {
  final String name;
  const _NowPickingBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: _amber.withOpacity(0.06),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 6, height: 6,
            decoration: const BoxDecoration(
                color: _amber, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text('$name is picking…',
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: _amber)),
      ]),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 1200.ms,
          curve: Curves.easeInOut,
          builder: (_, v, child) =>
              Opacity(opacity: 0.55 + 0.45 * v, child: child),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectator player bar
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorPlayerBar extends StatelessWidget {
  final DraftMember? member;
  final double       score;
  final Color        accent;
  final bool         isPickingNow;
  const _SpectatorPlayerBar({
    required this.member,
    required this.score,
    required this.accent,
    required this.isPickingNow,
  });

  @override
  Widget build(BuildContext context) {
    final name     = member?.username ?? 'Player';
    final scoreInt = score.toInt();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPickingNow ? accent.withOpacity(0.07) : _surf,
        border: Border(
            bottom: BorderSide(
                color: isPickingNow ? accent.withOpacity(0.35) : _bdr)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(
                color: accent.withOpacity(isPickingNow ? 0.65 : 0.25),
                width: 1.5),
          ),
          child: Center(child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: accent.withOpacity(isPickingNow ? 0.95 : 0.55)),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isPickingNow ? _txtPri : _txtMut))),
        if (isPickingNow) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text('PICKING', style: TextStyle(fontSize: 9,
                fontWeight: FontWeight.w900, color: accent, letterSpacing: 1)),
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
            Text('$scoreInt', style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w900, color: accent)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectator bottom panel
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorBottomPanel extends StatelessWidget {
  final DraftGameLoaded loaded;
  const _SpectatorBottomPanel({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final card = loaded.currentCard;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surf,
        border: const Border(
            top: BorderSide(color: _bdr), bottom: BorderSide(color: _bdr)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 60, height: 60,
          child: GameTimerDial(seconds: loaded.countdownSeconds),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: card != null
              ? _SpectatorCardPreview(card: card)
              : Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: _raised, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                  ),
                  child: const Center(child: Text('Waiting for card…',
                      style: TextStyle(fontSize: 11, color: _txtMut))),
                ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _amber.withOpacity(0.3)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_rounded, size: 18, color: _amber),
              SizedBox(height: 3),
              Text('LIVE', style: TextStyle(fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8, color: _amber)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SpectatorCardPreview extends StatelessWidget {
  final DraftCard card;
  const _SpectatorCardPreview({required this.card});

  Color get _glow {
    if (card.level >= 9) return const Color(0xFFFFAA00);
    if (card.level >= 7) return const Color(0xFFBB6CFF);
    if (card.level >= 4) return const Color(0xFF38C7FF);
    return const Color(0xFF3ADE80);
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glow;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: glow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glow.withOpacity(0.35)),
      ),
      child: Row(children: [
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
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CURRENT CARD', style: TextStyle(fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: glow.withOpacity(0.55), letterSpacing: 1.2)),
            const SizedBox(height: 3),
            Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: _txtPri)),
            if (card.franchiseName.isNotEmpty)
              Text(card.franchiseName.toUpperCase(),
                  style: TextStyle(fontSize: 9,
                      color: glow.withOpacity(0.5),
                      letterSpacing: 0.6, fontWeight: FontWeight.w600)),
          ],
        )),
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: glow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glow.withOpacity(0.4)),
          ),
          child: Center(child: Text('${card.level.toInt()}',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900, color: glow))),
        ),
      ]),
    ).animate()
        .scaleXY(begin: 0.94, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 180.ms);
  }

  Widget _initial(Color glow) => Container(
      color: glow.withOpacity(0.08),
      child: Center(child: Text(
          card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: glow.withOpacity(0.25)))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Finished game — read-only result view for spectators
// ─────────────────────────────────────────────────────────────────────────────

class _SpectatorResult extends StatelessWidget {
  final DraftGameLoaded loaded;
  const _SpectatorResult({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final room    = loaded.room;
    final p1      = loaded.allMembers.isNotEmpty ? loaded.allMembers.first : null;
    final p2      = loaded.allMembers.length > 1 ? loaded.allMembers[1] : null;
    final p1Score = p1 != null ? loaded.computeScore(p1) : 0.0;
    final p2Score = p2 != null ? loaded.computeScore(p2) : 0.0;
    final isDraw  = room.winnerId == null;
    final winColor = isDraw ? _amber
        : room.winnerId == p1?.userId ? _violet : _teal;
    final headline = isDraw ? "It's a Draw!"
        : '${room.winnerUsername ?? "Winner"} Wins!';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _raised, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _txtMut, size: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _amber.withOpacity(0.35)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.visibility_rounded, size: 12, color: _amber),
            SizedBox(width: 5),
            Text('You were spectating',
                style: TextStyle(fontSize: 11, color: _amber,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 20),
        Text(isDraw ? '🤝' : '🏆',
            style: const TextStyle(fontSize: 60))
            .animate().scale(begin: const Offset(0.4, 0.4),
                duration: 580.ms, curve: Curves.elasticOut),
        const SizedBox(height: 10),
        Text(headline,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                color: winColor, decoration: TextDecoration.none))
            .animate().fadeIn(delay: 180.ms),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _SpectatorScoreCard(
            name:     p1?.username ?? '—',
            score:    p1Score,
            color:    _violet,
            isWinner: room.winnerId == p1?.userId,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SpectatorScoreCard(
            name:     p2?.username ?? '—',
            score:    p2Score,
            color:    _teal,
            isWinner: room.winnerId == p2?.userId,
          )),
        ]).animate().fadeIn(delay: 280.ms).slideY(begin: 0.08),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home_rounded, size: 17),
          label: const Text('Back to Lobby',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: winColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ]),
    );
  }
}

class _SpectatorScoreCard extends StatelessWidget {
  final String name;
  final double score;
  final Color color;
  final bool isWinner;
  const _SpectatorScoreCard({
    required this.name, required this.score,
    required this.color, required this.isWinner,
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
        Text(name, style: const TextStyle(fontSize: 12, color: _txtSub,
            decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(score.toStringAsFixed(1), style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900,
            color: color, decoration: TextDecoration.none)),
        const Text('pts', style: TextStyle(fontSize: 11, color: _txtSub,
            decoration: TextDecoration.none)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading indicator
// ─────────────────────────────────────────────────────────────────────────────

class _WatchingIndicator extends StatelessWidget {
  const _WatchingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _amber.withOpacity(0.1),
          border: Border.all(color: _amber.withOpacity(0.4)),
        ),
        child: const Icon(Icons.visibility_rounded, color: _amber, size: 28),
      ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),
      const Text('Loading game…',
          style: TextStyle(color: _txtSub, fontSize: 13)),
      const SizedBox(height: 12),
      const SizedBox(width: 140,
          child: LinearProgressIndicator(
            color: _amber,
            backgroundColor: _bdr,
            minHeight: 2,
          )),
    ]);
  }
}
