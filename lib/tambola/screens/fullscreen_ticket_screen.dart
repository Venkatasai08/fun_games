// lib/tambola/screens/fullscreen_ticket_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../models/room.dart';
import '../models/ticket_model.dart';
import '../widgets/tambola_ticket_widget.dart';

/// A fullscreen landscape view of the player's Tambola ticket.
/// Receives live data via ValueNotifier so it always reflects the
/// latest called/marked numbers without needing a BLoC connection.
class FullscreenTicketScreen extends StatefulWidget {
  final List<List<int?>> ticket;
  final ValueNotifier<List<int>> calledNumbers;
  final ValueNotifier<List<int>> markedNumbers;
  final ValueNotifier<int?> lastCalled;
  final bool interactive;
  final bool suggestionMode;
  final void Function(int number)? onNumberTap;

  const FullscreenTicketScreen({
    super.key,
    required this.ticket,
    required this.calledNumbers,
    required this.markedNumbers,
    required this.lastCalled,
    this.interactive = true,
    this.suggestionMode = false,
    this.onNumberTap,
  });

  @override
  State<FullscreenTicketScreen> createState() => _FullscreenTicketScreenState();
}

class _FullscreenTicketScreenState extends State<FullscreenTicketScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;

  // ── Entry animation stages ────────────────────────────────────────────────
  // 1. Fade in the dark background immediately (0→200ms)
  late final Animation<double> _bgFade;
  // 2. Rotate from -90° → 0° (portrait-to-landscape feel) (0→500ms)
  late final Animation<double> _rotation;
  // 3. Scale from 0.55 → 1.0 with elastic overshoot (150→700ms)
  late final Animation<double> _scale;
  // 4. Fade the content in (100→400ms)
  late final Animation<double> _contentFade;
  // 5. Sidebar slides in from the left (200→600ms)
  late final Animation<Offset> _sidebarSlide;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Background starts fully opaque so the game screen never bleeds through
    // during the orientation change before the animation kicks in.
    _bgFade = Tween<double>(begin: 1, end: 1).animate(_enterCtrl);

    _rotation = Tween<double>(begin: -0.22, end: 0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.15, 1.0, curve: Curves.elasticOut),
      ),
    );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
      ),
    );

    _sidebarSlide = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Switch to landscape immediately
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Start the entry animation only after the first frame is painted.
    // This ensures the animation plays in the correctly-sized landscape
    // frame and never flashes a portrait-sized layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterCtrl.forward();
    });
  }

  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _restoreOrientation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _restoreOrientation();
      },
      child: Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: ValueListenableBuilder<List<int>>(
        valueListenable: widget.calledNumbers,
        builder: (context, called, _) {
          return ValueListenableBuilder<List<int>>(
            valueListenable: widget.markedNumbers,
            builder: (context, marked, _) {
              return ValueListenableBuilder<int?>(
                valueListenable: widget.lastCalled,
                builder: (context, lastNum, _) {
                  final matched = TicketGenerator.countMatched(
                      widget.ticket, marked);
                  final total = widget.ticket
                      .expand((r) => r)
                      .where((c) => c != null)
                      .length;

                  // ── Animated build ──────────────────────────────────
                  return AnimatedBuilder(
                    animation: _enterCtrl,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          // 1. Background fades in first
                          FadeTransition(
                            opacity: _bgFade,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0F0E1A),
                                    Color(0xFF1A1040),
                                    Color(0xFF0F0E1A),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 2. Full content fades + rotates + scales in
                          FadeTransition(
                            opacity: _contentFade,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(_rotation.value)
                                ..scale(_scale.value),
                              child: SafeArea(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // ── Sidebar slides in from left ────────
                                    SlideTransition(
                                      position: _sidebarSlide,
                                      child: Container(
                                        width: 110,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                              child: Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.bgCard,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10),
                                                  border: Border.all(
                                                      color:
                                                          AppTheme.border),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .fullscreen_exit_rounded,
                                                  color: AppTheme
                                                      .textSecondary,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                gradient: lastNum != null
                                                    ? const LinearGradient(
                                                        colors: [
                                                          AppTheme.primary,
                                                          AppTheme
                                                              .primaryLight,
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      )
                                                    : null,
                                                color: lastNum == null
                                                    ? AppTheme.bgCard
                                                    : null,
                                                shape: BoxShape.circle,
                                                boxShadow: lastNum != null
                                                    ? [
                                                        BoxShadow(
                                                          color: AppTheme
                                                              .primary
                                                              .withOpacity(
                                                                  0.5),
                                                          blurRadius: 18,
                                                          spreadRadius: 2,
                                                        ),
                                                      ]
                                                    : null,
                                                border: Border.all(
                                                  color: lastNum != null
                                                      ? AppTheme.primaryLight
                                                          .withOpacity(0.5)
                                                      : AppTheme.border,
                                                ),
                                              ),
                                              child: Center(
                                                child: lastNum != null
                                                    ? Text(
                                                        '$lastNum',
                                                        style: const TextStyle(
                                                          fontSize: 26,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.casino_outlined,
                                                        size: 28,
                                                        color: AppTheme
                                                            .textSecondary,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'LAST\nCALLED',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 9,
                                                letterSpacing: 1.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            const Divider(
                                                color: AppTheme.border),
                                            const SizedBox(height: 12),
                                            Text(
                                              '$matched',
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.accent,
                                              ),
                                            ),
                                            Text(
                                              'of $total',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'MATCHED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                letterSpacing: 1.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              '${called.length}',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            const Text(
                                              'CALLED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                letterSpacing: 1.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Vertical divider
                                    Container(
                                        width: 1,
                                        color: AppTheme.border),

                                    // ── Ticket scales + rotates in ─────────
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        child: Center(
                                          child: _LandscapeTicket(
                                            ticket: widget.ticket,
                                            calledNumbers: called,
                                            markedNumbers: marked,
                                            interactive: widget.interactive,
                                            suggestionMode: widget.suggestionMode,
                                            onNumberTap: widget.onNumberTap,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 60,)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape-optimised ticket — larger cells, wider layout
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeTicket extends StatelessWidget {
  final List<List<int?>> ticket;
  final List<int> calledNumbers;
  final List<int> markedNumbers;
  final bool interactive;
  final bool suggestionMode;
  final void Function(int)? onNumberTap;

  const _LandscapeTicket({
    required this.ticket,
    required this.calledNumbers,
    required this.markedNumbers,
    required this.interactive,
    this.suggestionMode = false,
    this.onNumberTap,
  });

  @override
  Widget build(BuildContext context) {
    final matched = suggestionMode
        ? TicketGenerator.countMatched(ticket, calledNumbers)
        : TicketGenerator.countMatched(ticket, markedNumbers);
    final total =
        ticket.expand((r) => r).where((c) => c != null).length;
    final progress = total > 0 ? matched / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(children: [
              const Icon(Icons.grid_on, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'YOUR TICKET',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$matched / $total matched',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ]),
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

          // Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Column headers
                Row(
                  children: List.generate(
                    10,
                    (col) => Expanded(
                      child: Center(
                        child: Text(
                          '${col + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ...List.generate(
                  ticket.length,
                  (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                  children: List.generate(10, (col) {
                  final num = ticket[row][col];
                  final isCalled = num != null && calledNumbers.contains(num);
                  final isMarked = num != null && markedNumbers.contains(num);
                  final isSuggested = suggestionMode && isCalled && !isMarked;
                  return Expanded(
                  child: _LandscapeCell(
                  number: num,
                  isCalled: isCalled,
                  isMarked: isMarked,
                  isSuggested: isSuggested,
                  suggestionMode: suggestionMode,
                  onTap: (num != null && interactive && isCalled)
                      ? () => onNumberTap?.call(num)
                      : null,
                  ),
                  );
                  }),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeCell extends StatelessWidget {
  final int? number;
  final bool isCalled;
  final bool isMarked;
  final bool isSuggested;
  final bool suggestionMode;
  final VoidCallback? onTap;

  const _LandscapeCell({
    required this.number,
    required this.isCalled,
    required this.isMarked,
    this.isSuggested = false,
    this.suggestionMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              // Only show called-styling when suggestion mode is ON
              color: isMarked
                  ? AppTheme.primary
                  : isSuggested
                      ? AppTheme.accent.withOpacity(0.25)
                      : (suggestionMode && isCalled)
                          ? AppTheme.primary.withOpacity(0.2)
                          : number != null
                              ? AppTheme.bgCardLight
                              : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMarked
                    ? AppTheme.primaryLight
                    : isSuggested
                        ? AppTheme.accent.withOpacity(0.9)
                        : (suggestionMode && isCalled)
                            ? AppTheme.primary.withOpacity(0.5)
                            : number != null
                                ? AppTheme.border
                                : Colors.transparent,
                width: isMarked || isSuggested ? 2 : 1,
              ),
              boxShadow: isMarked
                  ? [
                      BoxShadow(
                          color: AppTheme.primary.withOpacity(0.45),
                          blurRadius: 8)
                    ]
                  : isSuggested
                      ? [
                          BoxShadow(
                              color: AppTheme.accent.withOpacity(0.4),
                              blurRadius: 10)
                        ]
                      : null,
            ),
            child: Center(
              child: number != null
                  ? Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isMarked || isSuggested
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isMarked
                            ? Colors.white
                            : isSuggested
                                ? AppTheme.accent
                                : (suggestionMode && isCalled)
                                    ? AppTheme.primaryLight
                                    : AppTheme.textSecondary,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
