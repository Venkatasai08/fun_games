// lib/tambola/widgets/tambola_ticket_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../models/ticket_model.dart';

class TambolaTicketWidget extends StatelessWidget {
  final List<List<int?>> ticket;
  final List<int> calledNumbers;
  final List<int> markedNumbers;
  final Function(int)? onNumberTap;
  final bool interactive;
  final VoidCallback? onFullscreen;
  final bool suggestionMode;

  const TambolaTicketWidget({
    super.key,
    required this.ticket,
    required this.calledNumbers,
    required this.markedNumbers,
    this.onNumberTap,
    this.interactive = true,
    this.onFullscreen,
    this.suggestionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Suggestion mode ON  → count = called numbers that are on the ticket
    //                         (auto-increments; amber glow hints also shown)
    // Suggestion mode OFF → count = numbers the player has actually tapped
    //                         (tap-driven; no amber glow shown)
    final matched = suggestionMode
        ? TicketGenerator.countMatched(ticket, calledNumbers)
        : TicketGenerator.countMatched(ticket, markedNumbers);
    final total = ticket.expand((r) => r).where((c) => c != null).length;
    final progress = total > 0 ? matched / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ticket header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_on, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'YOUR TICKET',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    letterSpacing: 2, color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '$matched/$total matched',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (onFullscreen != null) ...[
                  const SizedBox(width: 8),
                  _FullscreenButton(onTap: onFullscreen!),
                ],
              ],
            ),
          ),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.bgDark,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? AppTheme.accent : AppTheme.primary,
            ),
            minHeight: 3,
          ),

          // Ticket grid
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                // Column headers (1-10)
                Row(
                  children: List.generate(10, (col) => Expanded(
                    child: Center(
                      child: Text(
                        '${col + 1}',
                        style: const TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 4),
                ...List.generate(ticket.length, (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: List.generate(10, (col) {
                      final num = ticket[row][col];
                      final isCalled = num != null && calledNumbers.contains(num);
                      final isMarked = num != null && markedNumbers.contains(num);
                      // Suggest tap only when suggestionMode is on,
                      // the number is called but not yet marked by the user
                      final isSuggested = suggestionMode && isCalled && !isMarked;
                      return Expanded(child: _TicketCell(
                        number: num,
                        isCalled: isCalled,
                        isMarked: isMarked,
                        isSuggested: isSuggested,
                        suggestionMode: suggestionMode,
                        // Suggestion ON : only tappable when called (glow guides the tap)
                        // Suggestion OFF: only tappable when called (player must find it first,
                        //                 but the number still has to be announced to mark it)
                        onTap: (num != null && interactive && isCalled)
                            ? () => onNumberTap?.call(num)
                            : null,
                      ));
                    }),
                  ),
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
// Fullscreen button — animates scale+glow on press before navigating
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FullscreenButton({required this.onTap});

  @override
  State<_FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<_FullscreenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Navigate immediately — no pre-nav delay so no weird portrait flash.
    // The button animation plays as a purely cosmetic overlay; the
    // fullscreen screen's own entry animation handles the visual transition.
    widget.onTap();
    // Play the press burst after navigation (user may still see it briefly)
    _ctrl.forward().then((_) => _ctrl.reset());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15 + _glow.value * 0.25),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(_glow.value * 0.7),
                  blurRadius: _glow.value * 14,
                  spreadRadius: _glow.value * 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.fullscreen_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCell extends StatefulWidget {
  final int? number;
  final bool isCalled;
  final bool isMarked;
  final bool isSuggested;
  final bool suggestionMode;
  final VoidCallback? onTap;

  const _TicketCell({
    required this.number,
    required this.isCalled,
    required this.isMarked,
    this.isSuggested = false,
    this.suggestionMode = false,
    this.onTap,
  });

  @override
  State<_TicketCell> createState() => _TicketCellState();
}

class _TicketCellState extends State<_TicketCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isSuggested) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_TicketCell old) {
    super.didUpdateWidget(old);
    if (widget.isSuggested && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isSuggested && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              // When suggestion mode is OFF, called-but-not-tapped cells
              // must look exactly like normal cells — no highlight at all.
              final showCalledStyle = widget.suggestionMode && widget.isCalled && !widget.isMarked;

              return AnimatedContainer(
                duration: 300.ms,
                decoration: BoxDecoration(
                  color: widget.isMarked
                      ? AppTheme.primary
                      : widget.isSuggested
                          ? AppTheme.accent.withOpacity(0.15 + _pulse.value * 0.2)
                          : showCalledStyle
                              ? AppTheme.primary.withOpacity(0.2)
                              : widget.number != null
                                  ? AppTheme.bgCardLight
                                  : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isMarked
                        ? AppTheme.primaryLight
                        : widget.isSuggested
                            ? AppTheme.accent.withOpacity(0.4 + _pulse.value * 0.6)
                            : showCalledStyle
                                ? AppTheme.primary.withOpacity(0.5)
                                : widget.number != null
                                    ? AppTheme.border
                                    : Colors.transparent,
                    width: widget.isMarked || widget.isSuggested ? 2 : 1,
                  ),
                  boxShadow: widget.isMarked
                      ? [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 6)]
                      : widget.isSuggested
                          ? [BoxShadow(
                              color: AppTheme.accent.withOpacity(_pulse.value * 0.5),
                              blurRadius: 8 * _pulse.value,
                              spreadRadius: 1,
                            )]
                          : null,
                ),
                child: Center(
                  child: widget.number != null
                      ? Text(
                          '${widget.number}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: widget.isMarked || widget.isSuggested
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: widget.isMarked
                                ? Colors.white
                                : widget.isSuggested
                                    ? AppTheme.accent
                                    : showCalledStyle
                                        ? AppTheme.primaryLight
                                        : AppTheme.textSecondary,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
