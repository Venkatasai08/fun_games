// lib/tambola/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/app_theme.dart';
import '../blocs/game/game_bloc.dart';
import '../models/room.dart';
import '../models/ticket_model.dart';
import '../widgets/tambola_ticket_widget.dart';
import '../widgets/number_board_widget.dart';
import 'fullscreen_ticket_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameScreen — provides the GameBloc and delegates rendering to _GameView
// ─────────────────────────────────────────────────────────────────────────────

class GameScreen extends StatelessWidget {
  final String roomId;
  const GameScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc()..add(GameInitialized(roomId)),
      child: const _GameView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GameView — StatefulWidget only for the AnimationController (vsync).
//             All state lives in GameBloc — zero setState calls.
// ─────────────────────────────────────────────────────────────────────────────

class _GameView extends StatefulWidget {
  const _GameView();

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ValueNotifiers keep the fullscreen ticket in sync without a BLoC connection
  final _calledNotifier = ValueNotifier<List<int>>([]);
  final _markedNotifier = ValueNotifier<List<int>>([]);
  final _lastCalledNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _calledNotifier.dispose();
    _markedNotifier.dispose();
    _lastCalledNotifier.dispose();
    super.dispose();
  }

  /// Keep the ValueNotifiers in sync with the latest loaded state so the
  /// fullscreen screen always shows live data.
  /// Deferred to post-frame so ValueNotifier updates never fire mid-build,
  /// which would cause a markNeedsBuild-during-build exception.
  void _syncNotifiers(GameLoaded s) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calledNotifier.value = s.room.calledNumbers;
      _markedNotifier.value = s.myMember?.markedNumbers ?? [];
      _lastCalledNotifier.value = s.room.lastCalled;
    });
  }

  // ── Side-effect helper ────────────────────────────────────────────────────

  /// Extracts the embedded GameLoaded from any side-effect state.
  GameLoaded? _extractLoaded(GameState state) {
    if (state is GameLoaded) return state;
    if (state is GameShowPausedSnackbar) return state.loaded;
    if (state is GameDismissPausedSnackbar) return state.loaded;
    if (state is GameHapticFeedback) return state.loaded;
    if (state is GameShowWinnerDialog) return state.loaded;
    if (state is GameHousieClaimed) return state.loaded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      // Only listen on side-effect states so we don't run listener on every tick
      listenWhen: (_, s) =>
          s is GameShowPausedSnackbar ||
          s is GameDismissPausedSnackbar ||
          s is GameHapticFeedback ||
          s is GameShowWinnerDialog ||
          s is GameHousieClaimed ||
          s is GameCancelled ||
          s is GameError,
      listener: (context, state) {
        if (state is GameShowPausedSnackbar) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(_pausedSnackBar());
        }
        if (state is GameDismissPausedSnackbar) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
        if (state is GameHapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        if (state is GameShowWinnerDialog) {
          _showWinnerDialog(context, state.loaded.room);
        }
        if (state is GameHousieClaimed && !state.won) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('❌ Invalid claim! Not all numbers are called.'),
            backgroundColor: Colors.red,
          ));
        }
        if (state is GameCancelled) {
          Navigator.pop(context);
        }
        if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
        }
      },
      builder: (context, state) {
        // ── Loading ──────────────────────────────────────────────────────
        if (state is GameLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.bgDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Joining game…',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          );
        }

        // ── Not found ────────────────────────────────────────────────────
        if (state is GameNotFound) {
          return Scaffold(
            backgroundColor: AppTheme.bgDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Room not found'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        // ── Loaded (or any side-effect state carrying a loaded snapshot) ──
        final loaded = _extractLoaded(state);
        if (loaded == null) return const SizedBox.shrink();

        // Keep notifiers current so FullscreenTicketScreen stays live
        _syncNotifiers(loaded);

        // Whether the current user is the host — read once for the whole build
        final isHost = context.read<GameBloc>().isHost;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, loaded),
                Expanded(
                  child: LayoutBuilder(builder: (_, constraints) {
                    return constraints.maxWidth > 800
                        ? _buildWideLayout(context, loaded, isHost)
                        : _buildNarrowLayout(context, loaded, isHost);
                  }),
                ),
                _buildNumberBoardBar(context, loaded),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Persistent snackbar for pause ─────────────────────────────────────────

  SnackBar _pausedSnackBar() => const SnackBar(
        content: Row(children: [
          Icon(Icons.pause_circle_outline, color: Colors.orange, size: 18),
          SizedBox(width: 10),
          Text('Game paused by host',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        backgroundColor: Color(0xFF2A1F00),
        duration: Duration(days: 1),
        behavior: SnackBarBehavior.floating,
      );

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, GameLoaded s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.room.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis),
              Text(
                '${s.allMembers.length} players • 1–${s.room.maxNumber}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        _StatusBadge(status: s.room.status),
        const SizedBox(width: 8),
        // Suggestion mode pill — amber when ON, muted when OFF
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: s.room.suggestionMode
                ? AppTheme.accent.withOpacity(0.15)
                : AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: s.room.suggestionMode
                  ? AppTheme.accent.withOpacity(0.6)
                  : AppTheme.border,
            ),
          ),
          child: Row(children: [
            Icon(
              s.room.suggestionMode
                  ? Icons.lightbulb_rounded
                  : Icons.lightbulb_outline,
              size: 13,
              color: s.room.suggestionMode
                  ? AppTheme.accent
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              s.room.suggestionMode ? 'Hints' : 'No Hints',
              style: TextStyle(
                color: s.room.suggestionMode
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            const Icon(Icons.people_outline,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('${s.allMembers.length}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(width: 6),
        // Per-player sound toggle button
        GestureDetector(
          onTap: () => context.read<GameBloc>().add(
                GameSoundToggled(!s.soundEnabled)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: s.soundEnabled
                  ? AppTheme.primary.withOpacity(0.15)
                  : AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: s.soundEnabled
                    ? AppTheme.primary.withOpacity(0.6)
                    : AppTheme.border,
              ),
            ),
            child: Icon(
              s.soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              size: 16,
              color: s.soundEnabled
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, GameLoaded s, bool isHost) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildLastCalledCard(s),
              if (isHost) ...[
                const SizedBox(height: 16),
                _buildHostControls(context, s),
              ],
            ]),
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildMyTicketSection(context, s),
              const SizedBox(height: 16),
              _buildPlayersList(s),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, GameLoaded s, bool isHost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _buildLastCalledCard(s),
        if (isHost) ...[
          const SizedBox(height: 14),
          _buildHostControls(context, s),
        ],
        const SizedBox(height: 14),
        _buildMyTicketSection(context, s),
        const SizedBox(height: 14),
        _buildPlayersList(s),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Last called card ──────────────────────────────────────────────────────

  Widget _buildLastCalledCard(GameLoaded s) {
    final lastNum = s.room.lastCalled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: lastNum != null
            ? const LinearGradient(
                colors: [Color(0xFF1A1040), Color(0xFF2D1F6E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: lastNum == null ? AppTheme.bgCard : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lastNum != null
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.border,
        ),
      ),
      child: Row(children: [
        if (lastNum != null)
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text('$lastNum',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
            ).animate(key: ValueKey(lastNum)).scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 600.ms,
                ),
          )
        else
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Icon(Icons.casino_outlined,
                  size: 36, color: AppTheme.textSecondary),
            ),
          ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lastNum != null ? 'LAST CALLED' : 'WAITING TO START',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                lastNum != null ? 'Number $lastNum' : 'Game not started',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.room.calledNumbers.length} of ${s.room.maxNumber} called',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.room.calledNumbers.length / s.room.maxNumber,
                  backgroundColor: AppTheme.bgDark,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Host controls ─────────────────────────────────────────────────────────

  Widget _buildHostControls(BuildContext context, GameLoaded s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.admin_panel_settings,
                size: 16, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('HOST CONTROLS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // ── Waiting: Start Game ──────────────────────────────────────
            if (s.room.isWaiting)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: s.allMembers.length >= 2
                      ? () =>
                          context.read<GameBloc>().add(GameStartRequested())
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(s.allMembers.length < 2
                      ? 'Need ${2 - s.allMembers.length} more player'
                      : 'Start Game'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              )
            // ── Playing: Pause/Resume or Manual Call ─────────────────────
            else if (s.room.isPlaying)
              Expanded(
                child: s.room.autoCall
                    ? ElevatedButton.icon(
                        onPressed: s.isAutoCallPaused
                            ? () => context
                                .read<GameBloc>()
                                .add(GameResumeRequested())
                            : () => context
                                .read<GameBloc>()
                                .add(GamePauseRequested()),
                        icon: Icon(s.isAutoCallPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded),
                        label: Text(s.isAutoCallPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s.isAutoCallPaused
                              ? AppTheme.accent
                              : AppTheme.bgCardLight,
                          foregroundColor: s.isAutoCallPaused
                              ? Colors.black
                              : AppTheme.textSecondary,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: s.isCallingNumber
                            ? null
                            : () => context
                                .read<GameBloc>()
                                .add(GameNumberCallRequested()),
                        icon: s.isCallingNumber
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.casino_rounded),
                        label: const Text('Call Next Number'),
                      ),
              )
            // ── Finished ─────────────────────────────────────────────────
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('🏆 Game Finished',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            // ── Settings edit button (host only, game in progress or waiting) ──
            if (!s.room.isFinished && !s.room.isCancelled) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showSettingsDialog(context, s),
                tooltip: 'Edit room settings',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: AppTheme.primary, size: 18),
                ),
              ),
            ],

            // ── Cancel / Delete button ────────────────────────────────────
            if (!s.room.isFinished && !s.room.isCancelled) ...[
              const SizedBox(width: 8),
              s.isCancelling
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      ),
                    )
                  : IconButton(
                      onPressed: () =>
                          _showCancelDialog(context, s.room.isPlaying),
                      tooltip:
                          s.room.isPlaying ? 'Cancel game' : 'Delete room',
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 18),
                      ),
                    ),
            ],
          ]),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, GameLoaded s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<GameBloc>(),
        child: _SettingsDialog(loaded: s),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, bool isPlaying) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(isPlaying ? 'Cancel Game?' : 'Delete Room?'),
        ]),
        content: Text(
          isPlaying
              ? 'This will end the game for all players. This cannot be undone.'
              : 'The room will be deleted. This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GameBloc>().add(GameCancelConfirmed());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isPlaying ? 'End Game' : 'Delete'),
          ),
        ],
      ),
    );
  }

  // ── Number board bottom bar ───────────────────────────────────────────────

  Widget _buildNumberBoardBar(BuildContext context, GameLoaded s) {
    final called = s.room.calledNumbers.length;
    final total = s.room.maxNumber;
    final showCountdown = s.room.autoCall &&
        s.room.isPlaying &&
        !s.isAutoCallPaused &&
        s.countdownSeconds > 0;

    return GestureDetector(
      onTap: () => _showNumberBoardDialog(context, s),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: const Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Countdown ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showCountdown)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: s.countdownSeconds / s.room.autoCallInterval,
                      strokeWidth: 3,
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        s.countdownSeconds <= 3
                            ? Colors.orange
                            : AppTheme.primary,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: s.isAutoCallPaused
                          ? Colors.orange.withOpacity(0.15)
                          : AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s.isAutoCallPaused
                            ? Colors.orange.withOpacity(0.5)
                            : AppTheme.primary.withOpacity(0.35),
                      ),
                    ),
                  ),
                if (s.isAutoCallPaused)
                  const Icon(Icons.pause_rounded,
                      color: Colors.orange, size: 22)
                else if (showCountdown)
                  Text(
                    '${s.countdownSeconds}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: s.countdownSeconds <= 3
                          ? Colors.orange
                          : AppTheme.primary,
                    ),
                  )
                else
                  const Icon(Icons.dashboard_rounded,
                      color: AppTheme.primary, size: 22),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Text('NUMBER BOARD',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text('$called / $total',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? called / total : 0,
                    backgroundColor: AppTheme.bgDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(children: [
              Icon(Icons.grid_view_rounded, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text('View',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showNumberBoardDialog(BuildContext context, GameLoaded s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(children: [
                  const Icon(Icons.dashboard_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Number Board',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.room.calledNumbers.length} / ${s.room.maxNumber}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: NumberBoardWidget(
                  maxNumber: s.room.maxNumber,
                  calledNumbers: s.room.calledNumbers,
                  lastCalled: s.room.lastCalled,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: AppTheme.border))),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                    ),
                  ),
                  child: const Text('Close',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ticket section ────────────────────────────────────────────────────────

  void _openFullscreenTicket(BuildContext context, GameLoaded s) {
    if (s.myMember == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenTicketScreen(
          ticket: s.myMember!.ticket,
          calledNumbers: _calledNotifier,
          markedNumbers: _markedNotifier,
          lastCalled: _lastCalledNotifier,
          interactive: s.room.isPlaying,
          suggestionMode: s.room.suggestionMode,
          onNumberTap: (n) =>
              context.read<GameBloc>().add(GameNumberMarked(n)),
        ),
      ),
    );
  }

  Widget _buildMyTicketSection(BuildContext context, GameLoaded s) {
    // myMember is null only briefly before Firestore membership propagates
    if (s.myMember == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
          SizedBox(width: 12),
          Text('Loading your ticket…', style: TextStyle(color: AppTheme.textSecondary)),
        ]),
      );
    }
    final canClaim = TicketGenerator.isFullHouse(
        s.myMember!.ticket, s.room.calledNumbers);

    return Column(children: [
      TambolaTicketWidget(
        ticket: s.myMember!.ticket,
        calledNumbers: s.room.calledNumbers,
        markedNumbers: s.myMember!.markedNumbers,
        onNumberTap: (n) =>
            context.read<GameBloc>().add(GameNumberMarked(n)),
        interactive: s.room.isPlaying,
        onFullscreen: () => _openFullscreenTicket(context, s),
        suggestionMode: s.room.suggestionMode,
      ),
      if (s.room.isPlaying && !s.myMember!.hasClaimedHousie) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed:
                canClaim ? () => _showHousieDialog(context) : null,
            icon: const Text('🏆', style: TextStyle(fontSize: 18)),
            label: const Text('HOUSIE!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppTheme.bgCardLight,
              disabledForegroundColor: AppTheme.textSecondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        ] else if (s.myMember!.hasClaimedHousie) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🏆'),
              SizedBox(width: 8),
              Text('You claimed Housie!',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ]);
  }

  void _showHousieDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🏆 Claim Housie?'),
        content: const Text(
          'This will verify your ticket. Make sure all numbers are called!',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GameBloc>().add(GameHousieClaimConfirmed());
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Claim Housie!'),
          ),
        ],
      ),
    );
  }

  // ── Players list ──────────────────────────────────────────────────────────

  Widget _buildPlayersList(GameLoaded s) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.people, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('PLAYERS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppTheme.textSecondary)),
            const Spacer(),
            Text('${s.allMembers.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        ...s.allMembers.map((member) {
          final isMe = member.userId == s.myMember?.userId;
          final isHost = member.userId == s.room.hostId;
          // Suggestion mode ON  → count called numbers on ticket (auto)
          // Suggestion mode OFF → count only tapped numbers (tap-driven)
          final matched = s.room.suggestionMode
              ? TicketGenerator.countMatched(member.ticket, s.room.calledNumbers)
              : TicketGenerator.countMatched(member.ticket, member.markedNumbers);
          final total = member.ticket
              .expand((r) => r)
              .where((c) => c != null)
              .length;

          return ListTile(
            dense: true,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHost
                      ? [AppTheme.primary, AppTheme.primaryLight]
                      : [AppTheme.bgCardLight, AppTheme.border],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  member.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isHost ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            title: Row(children: [
              Text(member.username,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isMe ? FontWeight.bold : FontWeight.normal,
                      color: isMe
                          ? AppTheme.primary
                          : AppTheme.textPrimary)),
              if (isHost) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('HOST',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
              if (isMe) ...[
                const SizedBox(width: 6),
                const Text('(you)',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ]),
            trailing: member.hasClaimedHousie
                ? const Text('🏆', style: TextStyle(fontSize: 14))
                : Text('$matched/$total',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
          );
        }),
      ]),
    );
  }

  // ── Winner dialog ─────────────────────────────────────────────────────────

  void _showWinnerDialog(BuildContext context, Room room) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Game Over!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                const Text('🏆 Winner',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  room.winnerUsername ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('${room.calledNumbers.length} numbers called',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Lobby'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case 'playing':
        color = AppTheme.secondary;
        label = '● LIVE';
        break;
      case 'finished':
        color = AppTheme.textSecondary;
        label = 'ENDED';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'CANCELLED';
        break;
      default:
        color = AppTheme.accent;
        label = 'WAITING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Host Live Settings Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsDialog extends StatefulWidget {
  final GameLoaded loaded;
  const _SettingsDialog({required this.loaded});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late bool _autoCall;
  late int _autoCallInterval;
  late bool _suggestionMode;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _autoCall = widget.loaded.room.autoCall;
    _autoCallInterval = widget.loaded.room.autoCallInterval;
    _suggestionMode = widget.loaded.room.suggestionMode;
    _soundEnabled = widget.loaded.room.soundEnabled;
  }

  void _save() {
    context.read<GameBloc>().add(GameSettingsUpdateRequested(
          autoCall: _autoCall,
          autoCallInterval: _autoCallInterval,
          suggestionMode: _suggestionMode,
          soundEnabled: _soundEnabled,
        ));
    Navigator.pop(context);
  }

  Widget _buildRow(String label, Widget control, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
            ],
          ),
        ),
        control,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.loaded.room;
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryLight],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(children: [
          const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Room Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ]),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto-call toggle
            _buildRow(
              'Auto-call numbers',
              Switch(
                value: _autoCall,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _autoCall = v),
              ),
            ),
            // Interval selector (only when autoCall ON)
            if (_autoCall) ...[
              const Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Row(children: [
                  const Text('Interval',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const Spacer(),
                  ...[3, 5, 10, 15, 30].map((sec) => GestureDetector(
                        onTap: () =>
                            setState(() => _autoCallInterval = sec),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _autoCallInterval == sec
                                ? AppTheme.primary
                                : AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${sec}s',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _autoCallInterval == sec
                                      ? Colors.white
                                      : AppTheme.textSecondary)),
                        ),
                      )),
                ]),
              ),
            ],
            const Divider(height: 1, color: AppTheme.border),
            // Suggestion mode
            _buildRow(
              'Hint mode',
              Switch(
                value: _suggestionMode,
                activeColor: AppTheme.accent,
                onChanged: room.isWaiting
                    ? (v) => setState(() => _suggestionMode = v)
                    : null, // lock once playing
              ),
              subtitle: room.isWaiting
                  ? 'Called numbers glow amber on tickets'
                  : 'Cannot change after game starts',
            ),
            const Divider(height: 1, color: AppTheme.border),
            // Sound enabled (default for new players)
            _buildRow(
              'Sound on by default',
              Switch(
                value: _soundEnabled,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              subtitle: 'Default sound for players who join',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
