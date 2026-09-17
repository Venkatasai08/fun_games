// lib/draftclash/screens/draft_lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/lobby/draft_lobby_bloc.dart';
import '../blocs/game/draft_game_bloc.dart';
import '../cubit/draft_catalog_cubit.dart';
import '../services/draft_sound_service.dart';
import '../widgets/game/game_layout.dart';
import '../widgets/game/game_top_bar.dart';
import '../widgets/game/game_result_overlay.dart';
import '../widgets/game/game_error_view.dart';
import '../widgets/game/game_loading_view.dart';
import '../widgets/lobby/lobby_password_dialog.dart';
import '../widgets/lobby/lobby_waiting_screen.dart';
import '../widgets/lobby/lobby_shell.dart';

const _txtPri = Color(0xFFEAE8FF);

class DraftLobbyScreen extends StatelessWidget {
  const DraftLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // DraftCatalogCubit is already in the tree (provided by GamesLobbyScreen).
      // Pass it into DraftLobbyBloc so the bloc reads franchises from the
      // session cache instead of making its own Firebase call.
      create: (ctx) =>
          DraftLobbyBloc(catalog: ctx.read<DraftCatalogCubit>()),
      child: BlocConsumer<DraftLobbyBloc, DraftLobbyState>(
        listenWhen: (_, s) =>
            s is DraftLobbyReady ||
            s is DraftLobbyPasswordRequired ||
            s is DraftLobbyPasswordWrong ||
            s is DraftLobbyJoinFailure,
        listener: (context, state) async {
          if (state is DraftLobbyReady) {
            DraftSoundService.gameStarting();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _OnlineGameScreen(roomId: state.roomId),
              ),
            );
            if (context.mounted) {
              context.read<DraftLobbyBloc>().add(DraftLobbyLoadRequested());
            }
          }
          if (state is DraftLobbyPasswordRequired) {
            _showPasswordDialog(context, state.roomId, state.roomName);
          }
          if (state is DraftLobbyPasswordWrong) {
            _snack(context, 'Incorrect password!', isError: true);
          }
          if (state is DraftLobbyJoinFailure) {
            _snack(context, state.message, isError: true);
          }
        },
        builder: (context, state) {
          if (state is DraftLobbyWaiting) {
            return LobbyWaitingScreen(state: state);
          }
          return const DraftClashLobbyShell();
        },
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _txtPri)),
      backgroundColor: isError ? const Color(0xFF2A0A1E) : const Color(0xFF0A1E12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showPasswordDialog(BuildContext context, String roomId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<DraftLobbyBloc>(),
        child: LobbyPasswordDialog(roomId: roomId, roomName: name),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full online game screen
// ─────────────────────────────────────────────────────────────────────────────

class _OnlineGameScreen extends StatelessWidget {
  final String roomId;
  const _OnlineGameScreen({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Pass pre-loaded cards from the session catalog so DraftGameBloc
      // never needs its own getAllCards() Firestore read.
      create: (ctx) => DraftGameBloc(
        preloadedCards: ctx.read<DraftCatalogCubit>().state.allCards,
      )..add(DraftGameInitialized(roomId)),
      child: BlocConsumer<DraftGameBloc, DraftGameState>(
        listenWhen: (_, s) =>
            s is DraftGameHapticFeedback || s is DraftGameShowResult,
        listener: (context, state) {
          if (state is DraftGameHapticFeedback) {
            // Haptic feedback handled inside the bloc via HapticFeedback.selectionClick()
          }
        },
        builder: (context, state) {
          final loaded = _extractLoaded(state);

          if (state is DraftGameLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFF07070F),
              body: GameLoadingView(),
            );
          }
          if (state is DraftGameError) {
            return Scaffold(
              backgroundColor: const Color(0xFF07070F),
              body: GameErrorView(message: state.message),
            );
          }
          if (loaded == null) return const SizedBox.shrink();

          return Scaffold(
            backgroundColor: const Color(0xFF07070F),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      GameTopBar(loaded: loaded),
                      Expanded(child: GameLayout(loaded: loaded)),
                    ],
                  ),
                  if (state is DraftGameShowResult)
                    GameResultOverlay(loaded: loaded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  DraftGameLoaded? _extractLoaded(DraftGameState state) {
    if (state is DraftGameLoaded)         return state;
    if (state is DraftGameHapticFeedback) return state.loaded;
    if (state is DraftGameShowResult)     return state.loaded;
    return null;
  }
}
