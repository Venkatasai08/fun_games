// lib/cardroomgame/screens/card_game_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/app_theme.dart';
import '../blocs/game/card_game_bloc.dart';
import '../models/card_model.dart';
import '../models/card_room_model.dart';
import '../models/card_player_model.dart';
import '../widgets/fan_hand_widget.dart';
import '../widgets/playing_card_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardGameScreen  –  STRICTLY LANDSCAPE
//
//  ┌──────────────────────────────────────────────────────────────────┐
//  │ [Header: back | name | code | LIVE | players | ⋮ ]              │
//  ├──────────────────┬──────────────────────────┬────────────────────┤
//  │  LEFT            │       CENTER             │   RIGHT            │
//  │  □ My avatar     │  Fan Hand  (large)       │   Table / Drop     │
//  │  ○ card count    │  all MY cards in fan     │   Drop zone        │
//  │  △ role          │                          │   Recent card      │
//  │  ── PASS TO ──   │                          │   (tap → dialog)   │
//  │  [opponent tiles]│                          │                    │
//  │  (DragTargets)   │                          │                    │
//  │  [👥 Players btn]│                          │                    │
//  └──────────────────┴──────────────────────────┴────────────────────┘
//
//  Opponents bar REMOVED from bottom.
//  "Players" button opens a modal bottom sheet with full player list.
// ─────────────────────────────────────────────────────────────────────────────

class CardGameScreen extends StatelessWidget {
  final String roomId;
  const CardGameScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CardGameBloc()..add(CardGameInitialized(roomId)),
      child: const _CardGameView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CardGameView extends StatefulWidget {
  const _CardGameView();
  @override
  State<_CardGameView> createState() => _CardGameViewState();
}

class _CardGameViewState extends State<_CardGameView> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardGameBloc, CardGameState>(
      listenWhen: (_, s) =>
          s is CardGameCancelled ||
          s is CardGameError ||
          s is CardGameShowEndDialog,
      listener: (context, state) {
        if (state is CardGameCancelled) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Room was cancelled.'),
            backgroundColor: Colors.redAccent,
          ));
        }
        if (state is CardGameError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ));
        }
        if (state is CardGameShowEndDialog) {
          _showGameOverDialog(context, state.loaded);
        }
      },
      builder: (context, state) {
        if (state is CardGameLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B1220),
            body: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFE94560))),
          );
        }
        if (state is CardGameNotFound) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B1220),
            appBar: AppBar(
                backgroundColor: const Color(0xFF0B1220),
                leading: const BackButton()),
            body: const Center(
                child: Text('Room not found.',
                    style: TextStyle(fontSize: 18))),
          );
        }
        final loaded = _resolveLoaded(state);
        if (loaded == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B1220),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildGame(context, loaded);
      },
    );
  }

  CardGameLoaded? _resolveLoaded(CardGameState s) {
    if (s is CardGameLoaded) return s;
    if (s is CardGameCardMoved) return s.loaded;
    if (s is CardGameShowEndDialog) return s.loaded;
    return null;
  }

  // ── Master layout ─────────────────────────────────────────────────────────

  Widget _buildGame(BuildContext context, CardGameLoaded state) {
    final room      = state.room;
    final myPlayer  = state.myPlayer;
    final opponents = state.opponents;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Thin header ──────────────────────────────────────
            _Header(room: room, state: state),

            // ── 2. Three-column body (full remaining height) ─────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT: my info + opponent pass-targets + Players btn
                  _MyInfoPanel(
                    myPlayer:  myPlayer,
                    room:      room,
                    amHost:    state.amHost,
                    opponents: opponents,
                    onCardPassedToPlayer: (card, targetUserId) => context
                        .read<CardGameBloc>()
                        .add(CardGameCardPassedToPlayer(
                            card: card, targetUserId: targetUserId)),
                    onShowPlayers: () =>
                        _showPlayersBottomSheet(context, state),
                  ),

                  Container(width: 1, color: AppTheme.border),

                  // CENTER: fan hand — large, takes all remaining width
                  Expanded(
                    child: _CenterHandPanel(
                      myPlayer: myPlayer,
                      state:    state,
                      room:     room,
                    ),
                  ),

                  Container(width: 1, color: AppTheme.border),

                  // RIGHT: recently played card + deck
                  _RightPanel(
                    room:    room,
                    state:   state,
                    onCardDropped: (card) => context
                        .read<CardGameBloc>()
                        .add(CardGameCardPlayedToTable(card: card)),
                    onDeckTapped: (card) =>
                        _showGrabCardSheet(context, card),
                    onUndo: () => context
                        .read<CardGameBloc>()
                        .add(CardGameUndoLastMove()),
                  ),
                ],
              ),
            ),
            // ── No bottom bar — opponents moved to bottom sheet ──────
          ],
        ),
      ),
    );
  }

  // ── Bottom sheet: deck grab reveal ─────────────────────────────────────────

  void _showGrabCardSheet(BuildContext context, PlayingCard card) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,   // force explicit choice
      enableDrag: false,
      builder: (ctx) => _GrabCardBottomSheet(
        card: card,
        onKeep: () {
          Navigator.pop(ctx);
          context
              .read<CardGameBloc>()
              .add(CardGameGrabFromDeck(card));
        },
        onThrow: () {
          Navigator.pop(ctx);
          context
              .read<CardGameBloc>()
              .add(CardGameCardPlayedToTable(card: card, faceUp: true));
        },
      ),
    );
  }

  // ── Bottom sheet: all players ─────────────────────────────────────────────

  void _showPlayersBottomSheet(BuildContext context, CardGameLoaded state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PlayersBottomSheet(
        state:  state,
        onPassCard: (card, targetUserId) => context
            .read<CardGameBloc>()
            .add(CardGameCardPassedToPlayer(
                card: card, targetUserId: targetUserId)),
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, CardGameLoaded loaded) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Column(children: [
          Text('🎴', style: TextStyle(fontSize: 48)),
          SizedBox(height: 8),
          Text('Game Over!',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'The session has ended. Thanks for playing!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.exit_to_app_rounded),
            label: const Text('Back to Lobby'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final CardRoom room;
  final CardGameLoaded state;
  const _Header({required this.room, required this.state});

  @override
  Widget build(BuildContext context) {
    final isPlaying   = room.isPlaying;
    final statusColor = isPlaying
        ? const Color(0xFF43E97B)
        : const Color(0xFFE94560);
    final statusLabel = isPlaying
        ? 'LIVE'
        : room.isWaiting
            ? 'WAITING'
            : 'ENDED';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border:
            Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.style_rounded,
              size: 16, color: Color(0xFFE94560)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(room.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.35)),
            ),
            child: Text('# ${room.roomCode}',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isPlaying) ...[
                _PulsingDot(color: statusColor),
                const SizedBox(width: 4),
              ],
              Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
            ]),
          ),
          const SizedBox(width: 8),
          Row(children: [
            const Icon(Icons.people_outline,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 3),
            Text('${state.allPlayers.length}/${room.maxPlayers}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary)),
          ]),
          if (state.amHost) ...[
            const SizedBox(width: 6),
            _HostMenuButton(room: room),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HostMenuButton
// ─────────────────────────────────────────────────────────────────────────────

class _HostMenuButton extends StatelessWidget {
  final CardRoom room;
  const _HostMenuButton({required this.room});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          color: AppTheme.textSecondary, size: 18),
      color: AppTheme.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        if (room.isPlaying)
          const PopupMenuItem<String>(
            value: 'end',
            child: Row(children: [
              Icon(Icons.flag_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 10),
              Text('End Game',
                  style: TextStyle(color: Colors.amber)),
            ]),
          ),
        const PopupMenuItem<String>(
          value: 'cancel',
          child: Row(children: [
            Icon(Icons.cancel_outlined,
                color: Colors.redAccent, size: 18),
            SizedBox(width: 10),
            Text('Cancel Room',
                style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ],
      onSelected: (value) {
        if (value == 'end') _showEndConfirm(context);
        if (value == 'cancel') _showCancelConfirm(context);
      },
    );
  }

  void _showEndConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.flag_rounded, color: Colors.amber, size: 22),
          SizedBox(width: 10),
          Text('End Game'),
        ]),
        content: const Text(
            'Mark the game as finished for all players.',
            style: TextStyle(
                color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<CardGameBloc>()
                  .add(CardGameEndRequested());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber),
            child: const Text('End Game',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cancel_outlined,
              color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('Cancel Room'),
        ]),
        content: const Text(
            'This will cancel the room for everyone.',
            style: TextStyle(
                color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<CardGameBloc>()
                  .add(CardGameCancelConfirmed());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Cancel Room'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MyInfoPanel  –  LEFT column (~120px)
//
// Top:    □ avatar  ○ card count  △ role  (MY info)
// Middle: PASS TO — compact DragTarget tiles for each opponent
// Bottom: [👥 Players] button → opens bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MyInfoPanel extends StatelessWidget {
  final CardPlayer? myPlayer;
  final CardRoom room;
  final bool amHost;
  final List<CardPlayer> opponents;
  final void Function(PlayingCard card, String targetUserId)
      onCardPassedToPlayer;
  final VoidCallback onShowPlayers;

  const _MyInfoPanel({
    required this.myPlayer,
    required this.room,
    required this.amHost,
    required this.opponents,
    required this.onCardPassedToPlayer,
    required this.onShowPlayers,
  });

  @override
  Widget build(BuildContext context) {
    final name       = myPlayer?.username ?? '—';
    final cardCount  = myPlayer?.hand.length ?? 0;
    final isSpectator = myPlayer?.isSpectator ?? false;

    return Container(
      width: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111827), Color(0xFF0B1220)],
        ),
      ),
      child: Column(
        children: [
          // ── My Info ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
            child: Column(
              children: [
                // □ Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: amHost
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFE94560),
                              Color(0xFFFF8C69)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              AppTheme.primary,
                              AppTheme.primaryLight
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (amHost
                                ? const Color(0xFFE94560)
                                : AppTheme.primary)
                            .withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Name
                Text(name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                const SizedBox(height: 5),

                // ○ Card count
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style_rounded,
                          size: 10, color: AppTheme.accent),
                      const SizedBox(width: 3),
                      Text('$cardCount',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accent,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 5),

                // △ Role
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: amHost
                        ? const Color(0xFFE94560).withOpacity(0.15)
                        : isSpectator
                            ? Colors.blue.withOpacity(0.15)
                            : AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: amHost
                          ? const Color(0xFFE94560).withOpacity(0.45)
                          : isSpectator
                              ? Colors.blue.withOpacity(0.45)
                              : AppTheme.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    amHost
                        ? 'HOST'
                        : isSpectator
                            ? 'WATCH'
                            : 'PLAYER',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: amHost
                          ? const Color(0xFFE94560)
                          : isSpectator
                              ? Colors.blue
                              : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────
          if (opponents.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              height: 1,
              color: AppTheme.border,
            ),

          // ── PASS TO — compact opponent DragTargets ───────────────
          if (opponents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(children: [
                const Icon(Icons.send_rounded,
                    size: 9, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('PASS TO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                    )),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: [
                    for (final op in opponents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _CompactOpponentTarget(
                          player: op,
                          isHost: op.userId == room.hostId,
                          onCardDropped: (card) =>
                              onCardPassedToPlayer(card, op.userId),
                        ).animate(key: ValueKey(op.userId))
                            .fadeIn(duration: 250.ms)
                            .slideX(begin: -0.1),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),

          // ── Divider + Players button ─────────────────────────────
          Container(height: 1, color: AppTheme.border),
          GestureDetector(
            onTap: onShowPlayers,
            child: Container(
              height: 40,
              color: AppTheme.bgCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_rounded,
                      size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Players',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompactOpponentTarget  –  small DragTarget in the left panel
// ─────────────────────────────────────────────────────────────────────────────

class _CompactOpponentTarget extends StatelessWidget {
  final CardPlayer player;
  final bool isHost;
  final void Function(PlayingCard card) onCardDropped;

  const _CompactOpponentTarget({
    required this.player,
    required this.isHost,
    required this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onCardDropped(d.data),
      builder: (ctx, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: isHovering
                ? AppTheme.accent.withOpacity(0.2)
                : AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovering
                  ? AppTheme.accent
                  : isHost
                      ? const Color(0xFFE94560).withOpacity(0.5)
                      : AppTheme.border,
              width: isHovering ? 1.8 : 1,
            ),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 8)
                  ]
                : null,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              // Avatar circle
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isHost
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFE94560),
                            Color(0xFFFF8C69)
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            AppTheme.primary,
                            AppTheme.primaryLight
                          ],
                        ),
                ),
                child: Center(
                  child: Text(
                    player.username.isNotEmpty
                        ? player.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player.username,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isHovering
                          ? 'Drop!'
                          : '${player.hand.length} cards',
                      style: TextStyle(
                        fontSize: 8,
                        color: isHovering
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        fontWeight: isHovering
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isHovering)
                const Icon(Icons.arrow_forward_rounded,
                    size: 12, color: AppTheme.accent),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayersBottomSheet  –  full player list in a modal bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlayersBottomSheet extends StatelessWidget {
  final CardGameLoaded state;
  final void Function(PlayingCard card, String targetUserId) onPassCard;

  const _PlayersBottomSheet({
    required this.state,
    required this.onPassCard,
  });

  @override
  Widget build(BuildContext context) {
    final allPlayers = state.allPlayers;
    final myUserId   = state.myPlayer?.userId;
    final room       = state.room;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              const Icon(Icons.people_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text('Players',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${allPlayers.length}/${room.maxPlayers}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // Player list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              itemCount: allPlayers.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (ctx, i) {
                final p      = allPlayers[i];
                final isMe   = p.userId == myUserId;
                final isHost = p.userId == room.hostId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isHost
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFE94560),
                                  Color(0xFFFF8C69)
                                ],
                              )
                            : isMe
                                ? const LinearGradient(
                                    colors: [
                                      AppTheme.primary,
                                      AppTheme.primaryLight
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      AppTheme.bgCardLight,
                                      AppTheme.bgCardLight
                                    ],
                                  ),
                        border: isMe
                            ? Border.all(
                                color: AppTheme.primary.withOpacity(0.6),
                                width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          p.username.isNotEmpty
                              ? p.username[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isMe || isHost
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(p.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? AppTheme.primary
                                      : Colors.white,
                                )),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: const Text('YOU',
                                    style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primary,
                                        letterSpacing: 0.8)),
                              ),
                            ],
                            if (isHost) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE94560)
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: const Text('HOST',
                                    style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFE94560),
                                        letterSpacing: 0.8)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.style_rounded,
                                size: 11, color: AppTheme.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${p.hand.length} card${p.hand.length == 1 ? '' : 's'} in hand',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary),
                            ),
                            if (p.isSpectator) ...[
                              const SizedBox(width: 8),
                              Row(children: [
                                const Icon(Icons.visibility_rounded,
                                    size: 10, color: Colors.blue),
                                const SizedBox(width: 3),
                                const Text('Spectating',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue)),
                              ]),
                            ],
                          ]),
                        ],
                      ),
                    ),

                    // Card count badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          '${p.hand.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),

          // Bottom padding
          SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CenterHandPanel  –  CENTER column
// ─────────────────────────────────────────────────────────────────────────────

class _CenterHandPanel extends StatelessWidget {
  final CardPlayer? myPlayer;
  final CardGameLoaded state;
  final CardRoom room;

  const _CenterHandPanel({
    required this.myPlayer,
    required this.state,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1525), Color(0xFF0B1220)],
        ),
      ),
      child: Expanded(
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (myPlayer?.isSpectator == true) {
      return _buildSpectatorCenter(context);
    }
    if (room.isWaiting) {
      return _buildWaitingCenter(context);
    }
    if (myPlayer == null || myPlayer!.hand.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.style_outlined,
              size: 44,
              color: AppTheme.textSecondary.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text('No cards in hand',
              style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 13)),
        ]),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_rounded,
                    size: 11, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Drag  →  table    |    Drag  ←  opponent',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary.withOpacity(0.55),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          FanHandWidget(
            hand: myPlayer!.hand,
            maxWidth: constraints.maxWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCenter(BuildContext context) {
    final canStart =
        state.allPlayers.where((p) => !p.isSpectator).length >= 2;

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE94560).withOpacity(0.12),
            border: Border.all(
                color: const Color(0xFFE94560).withOpacity(0.4)),
          ),
          child: const Icon(Icons.hourglass_top_rounded,
              size: 28, color: Color(0xFFE94560)),
        ),
        const SizedBox(height: 14),
        Text(
          canStart
              ? '${state.allPlayers.length}/${state.room.maxPlayers} joined — ready to deal!'
              : 'Waiting for players…\n(${state.allPlayers.length}/${state.room.maxPlayers} joined)',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
        if (state.amHost) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (canStart && !state.isProcessing)
                ? () => context
                    .read<CardGameBloc>()
                    .add(CardGameStartRequested())
                : null,
            icon: state.isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Deal Cards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43E97B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSpectatorCenter(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
            border: Border.all(color: Colors.blue.withOpacity(0.35)),
          ),
          child: const Icon(Icons.visibility_rounded,
              size: 26, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        const Text('You are spectating',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        if (state.amHost && state.room.isWaiting) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context
                .read<CardGameBloc>()
                .add(CardGameStartRequested()),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Deal Cards'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43E97B)),
          ),
        ],
        if (state.amHost && state.room.isPlaying) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context
                .read<CardGameBloc>()
                .add(CardGameTableCleared()),
            icon: const Icon(Icons.clear_all_rounded,
                size: 16, color: Colors.amber),
            label: const Text('Clear Table',
                style: TextStyle(color: Colors.amber)),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RightPanel  –  RIGHT column (140px)
//
//  Sections (top → bottom):
//   1. [UNDO] button — always visible for host, hidden for others
//   2. Recently Played card — the last card placed on the table
//   3. Deck — face-down stack; tap to grab a random card
// ─────────────────────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final CardRoom room;
  final CardGameLoaded state;
  final void Function(PlayingCard card) onCardDropped;
  final void Function(PlayingCard card) onDeckTapped;
  final VoidCallback onUndo;

  const _RightPanel({
    required this.room,
    required this.state,
    required this.onCardDropped,
    required this.onDeckTapped,
    required this.onUndo,
  });

  TableCard? get _recentCard =>
      room.tableCards.isNotEmpty ? room.tableCards.last : null;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (_) => room.isPlaying,
      onAcceptWithDetails: (d) => onCardDropped(d.data),
      builder: (ctx, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 130,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isHovering
                  ? [
                      AppTheme.accent.withOpacity(0.14),
                      AppTheme.accent.withOpacity(0.06),
                    ]
                  : [
                      const Color(0xFF111827),
                      const Color(0xFF0B1220),
                    ],
            ),
            border: isHovering
                ? Border.all(
                    color: AppTheme.accent.withOpacity(0.5), width: 1.5)
                : null,
          ),
          child: Column(
            children: [
              // ── 1. Undo button (host always, others hidden) ──────────────
              _buildUndoBar(context),

              // ── Divider ──────────────────────────────────────────────────
              Container(height: 1, color: AppTheme.border),

              // ── 2. Recently played card ──────────────────────────────────
              Expanded(
                child: _buildRecentSection(context, isHovering),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Container(height: 1, color: AppTheme.border),

              // ── 3. Deck ──────────────────────────────────────────────────
              _buildDeckSection(context),
            ],
          ),
        );
      },
    );
  }

  // ── Undo bar ──────────────────────────────────────────────────────────────

  Widget _buildUndoBar(BuildContext context) {
    final canUndo = room.tableCards.isNotEmpty;

    // Always rendered — visible for host, collapsed (0-height) for non-host
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: state.amHost ? 36 : 0,
        child: state.amHost
            ? GestureDetector(
                onTap: canUndo ? onUndo : null,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.undo_rounded,
                        size: 14,
                        color: canUndo
                            ? Colors.amber
                            : AppTheme.textSecondary.withOpacity(0.35),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'UNDO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: canUndo
                              ? Colors.amber
                              : AppTheme.textSecondary.withOpacity(0.35),
                        ),
                      ),
                      if (canUndo) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${room.tableCards.length}',
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Recently played card section ──────────────────────────────────────────

  Widget _buildRecentSection(BuildContext context, bool isHovering) {
    if (isHovering) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.file_download_rounded,
              size: 28, color: AppTheme.accent),
          const SizedBox(height: 6),
          Text('Drop here!',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Section label
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: Color(0xFF43E97B), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text(
              'LAST PLAYED',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppTheme.textSecondary,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Card or empty state
          Expanded(
            child: _recentCard == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.layers_outlined,
                          size: 26,
                          color:
                              AppTheme.textSecondary.withOpacity(0.25)),
                      const SizedBox(height: 6),
                      Text(
                        'No cards\nplayed yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textSecondary.withOpacity(0.4)),
                      ),
                    ]),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlayingCardWidget(
                        key: ValueKey(_recentCard!.card.id),
                        card: _recentCard!.card.copyWith(faceUp: true),
                        width: 56,
                        height: 80,
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 280.ms,
                              curve: Curves.easeOutBack)
                          .fadeIn(duration: 180.ms),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          _recentCard!.placedByUsername,
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Deck section ──────────────────────────────────────────────────────────

  Widget _buildDeckSection(BuildContext context) {
    final deck = room.remainingDeck;
    final deckCount = deck.length;
    final canGrab = deckCount > 0 && room.isPlaying;

    return GestureDetector(
      onTap: canGrab
          ? () {
              final random = Random();
              final picked = deck[random.nextInt(deck.length)];
              onDeckTapped(picked);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          children: [
            // Section label
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.style_rounded,
                  size: 9,
                  color: canGrab
                      ? AppTheme.accent
                      : AppTheme.textSecondary.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text(
                'DECK',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: canGrab
                      ? AppTheme.accent
                      : AppTheme.textSecondary.withOpacity(0.4),
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // Stacked card visual
            if (deckCount > 0)
              _DeckStack(count: deckCount, canGrab: canGrab)
            else
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.do_not_disturb_outlined,
                    size: 24,
                    color: AppTheme.textSecondary.withOpacity(0.25)),
                const SizedBox(height: 4),
                Text(
                  'Deck empty',
                  style: TextStyle(
                      fontSize: 8,
                      color: AppTheme.textSecondary.withOpacity(0.4)),
                ),
              ]),

            if (canGrab) ...[
              const SizedBox(height: 6),
              Text(
                'TAP TO GRAB',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppTheme.accent.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeckStack  –  visual stack of face-down cards showing remaining count
// ─────────────────────────────────────────────────────────────────────────────

class _DeckStack extends StatelessWidget {
  final int count;
  final bool canGrab;

  const _DeckStack({required this.count, required this.canGrab});

  @override
  Widget build(BuildContext context) {
    const cardW = 52.0;
    const cardH = 74.0;
    // Show up to 4 ghost cards behind the top card
    final shadowLayers = (count - 1).clamp(0, 4);

    return SizedBox(
      width: cardW + 6,
      height: cardH + shadowLayers * 2.0 + 4,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Ghost layers (face-down offset cards)
          for (int i = shadowLayers; i >= 1; i--)
            Positioned(
              top: (shadowLayers - i) * 2.0,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2540),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: AppTheme.border.withOpacity(0.5), width: 1),
                ),
              ),
            ),

          // Top (grabbable) card
          Positioned(
            top: shadowLayers * 2.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: canGrab
                    ? const LinearGradient(
                        colors: [Color(0xFF1F3060), Color(0xFF162248)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF1A2540), Color(0xFF141E36)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(
                  color: canGrab
                      ? AppTheme.accent.withOpacity(0.55)
                      : AppTheme.border,
                  width: canGrab ? 1.5 : 1,
                ),
                boxShadow: canGrab
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.question_mark_rounded,
                    size: 18,
                    color: canGrab
                        ? AppTheme.accent
                        : AppTheme.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: canGrab
                          ? AppTheme.accent
                          : AppTheme.textSecondary.withOpacity(0.45),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GrabCardBottomSheet
//
//  Shown when a player taps the deck. Reveals the drawn card with a flip
//  animation, then offers two explicit choices:
//   ✓ Keep It  →  card goes into the player’s hand
//   ✗ Throw It →  card is placed face-up on the table (becomes Last Played)
// ─────────────────────────────────────────────────────────────────────────────

class _GrabCardBottomSheet extends StatefulWidget {
  final PlayingCard card;
  final VoidCallback onKeep;
  final VoidCallback onThrow;

  const _GrabCardBottomSheet({
    required this.card,
    required this.onKeep,
    required this.onThrow,
  });

  @override
  State<_GrabCardBottomSheet> createState() => _GrabCardBottomSheetState();
}

class _GrabCardBottomSheetState extends State<_GrabCardBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipCtrl,
      curve: Curves.easeInOut,
    );
    // Brief pause before the flip so the user sees the card back first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _flipCtrl.forward();
        setState(() => _revealed = true);
      }
    });
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title badge ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE94560).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFE94560).withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.style_rounded,
                  color: Color(0xFFE94560), size: 14),
              const SizedBox(width: 7),
              const Text(
                'YOUR DRAW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: Color(0xFFE94560),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Card flip reveal ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _flipAnim,
            builder: (ctx, _) {
              final v = _flipAnim.value;
              // First half  (v: 0→0.5): back rotates from 0→pi/2 (folds away)
              // Second half (v: 0.5→1): front rotates from pi/2→0 (unfolds in)
              final isFront = v >= 0.5;
              final angle = isFront
                  ? (1.0 - v) * pi   // pi/2 → 0
                  : v * pi;           // 0    → pi/2
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(angle),
                child: isFront
                    ? PlayingCardWidget(
                        card: widget.card.copyWith(faceUp: true),
                        width: 110,
                        height: 158,
                      )
                    : PlayingCardWidget(
                        card: widget.card.copyWith(faceUp: false),
                        width: 110,
                        height: 158,
                      ),
              );
            },
          ),
          const SizedBox(height: 22),

          // ── Status text ──────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(_revealed),
              _revealed ? 'What will you do with it?' : 'Drawing from deck…',
              style: TextStyle(
                fontSize: 13,
                color: _revealed
                    ? AppTheme.textSecondary
                    : AppTheme.textSecondary.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Action buttons (fade in after reveal) ───────────────────────
          AnimatedOpacity(
            opacity: _revealed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            child: IgnorePointer(
              ignoring: !_revealed,
              child: Row(children: [
                // ─ Keep It ─
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onKeep,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Keep It',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43E97B),
                      foregroundColor: Colors.black87,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ─ Throw It ─
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onThrow,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Throw It',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PulsingDot
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
            color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
