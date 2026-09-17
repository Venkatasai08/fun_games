// lib/draftclash/widgets/game/game_top_bar.dart
import 'package:flutter/material.dart';
import '../../blocs/game/draft_game_bloc.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _ink    = Color(0xFF050510);
const _surf   = Color(0xFF0D0C1E);
const _raised = Color(0xFF14122A);
const _rim    = Color(0xFF1C1A35);
const _bdr    = Color(0xFF1E1B38);
const _violet = Color(0xFF7B5CFA);
const _amber  = Color(0xFFF4A11D);
const _teal   = Color(0xFF00D4AA);
const _txtPri = Color(0xFFEAE8FF);
const _txtSub = Color(0xFF7A78A8);
const _txtMut = Color(0xFF6A6898);

class GameTopBar extends StatelessWidget {
  final DraftGameLoaded loaded;
  const GameTopBar({super.key, required this.loaded});

  int _filledSlots(Map<String, String?> board) =>
      loaded.slots.where((s) => board[s.key] != null).length;

  @override
  Widget build(BuildContext context) {
    final roomName   = loaded.room.roomName ?? 'Draft Clash';
    final code       = loaded.room.code;
    final franchise  = loaded.room.franchise;

    final totalSlots = loaded.slots.length * 2;
    final myFilled   = loaded.myMember != null
        ? _filledSlots(loaded.myMember!.board) : 0;
    final oppFilled  = loaded.opponentMember != null
        ? _filledSlots(loaded.opponentMember!.board) : 0;
    final filled     = myFilled + oppFilled;
    final remaining  = totalSlots - filled;
    final progress   = filled / totalSlots;

    return Container(
      decoration: const BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _bdr, width: 0.8)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // ── Back ──────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
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

                  // ── Identity block ────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Room name
                        Text(
                          roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _txtPri,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Code + franchise row
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _violet.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: _violet.withOpacity(0.3), width: 0.8),
                            ),
                            child: Text(
                              '# $code',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _violet,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (franchise != null) ...[
                            const SizedBox(width: 6),
                            const _Dot(),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                franchise,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _txtSub,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Picks counter ──────────────────────────────────────
                  _PicksCounter(
                    remaining: remaining,
                    total: totalSlots,
                    progress: progress,
                  ),
                ],
              ),
            ),

            // ── Progress bar ───────────────────────────────────────────
            _DraftProgressBar(progress: progress, filled: filled, total: totalSlots),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Picks counter badge
// ─────────────────────────────────────────────────────────────────────────────

class _PicksCounter extends StatelessWidget {
  final int remaining;
  final int total;
  final double progress;

  const _PicksCounter({
    required this.remaining,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Colour shifts from teal → amber → violet as draft progresses
    final Color accent;
    if (progress < 0.4) {
      accent = _teal;
    } else if (progress < 0.75) {
      accent = _amber;
    } else {
      accent = _violet;
    }

    final bool almostDone = remaining <= 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withOpacity(almostDone ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: accent.withOpacity(almostDone ? 0.60 : 0.30),
          width: almostDone ? 1.5 : 1,
        ),
        boxShadow: almostDone
            ? [BoxShadow(color: accent.withOpacity(0.25),
                blurRadius: 10, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$remaining',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'left',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: accent.withOpacity(0.65),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin animated progress bar at the bottom of the header
// ─────────────────────────────────────────────────────────────────────────────

class _DraftProgressBar extends StatelessWidget {
  final double progress;
  final int filled;
  final int total;

  const _DraftProgressBar({
    required this.progress,
    required this.filled,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // Gradient shifts from teal → amber → violet
    const gradientColors = [_teal, _amber, _violet];

    return Stack(
      children: [
        // Track
        Container(
          height: 2.5,
          color: _rim,
        ),
        // Fill
        AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small dot separator
// ─────────────────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
    width: 3, height: 3,
    decoration: const BoxDecoration(
      color: _txtMut, shape: BoxShape.circle),
  );
}
