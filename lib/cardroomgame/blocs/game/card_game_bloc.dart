// lib/cardroomgame/blocs/game/card_game_bloc.dart
import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/card_model.dart';
import '../../models/card_room_model.dart';
import '../../models/card_player_model.dart';
import '../../services/card_room_service.dart';

part 'card_game_event.dart';
part 'card_game_state.dart';

class CardGameBloc extends Bloc<CardGameEvent, CardGameState> {
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _membersSub;

  bool get isHost {
    final s = state;
    if (s is CardGameLoaded) return s.room.hostId == _userId;
    return false;
  }

  CardGameBloc() : super(CardGameLoading()) {
    on<CardGameInitialized>(_onInitialized);
    on<CardGameRoomUpdated>(_onRoomUpdated);
    on<CardGameMembersUpdated>(_onMembersUpdated);
    on<CardGameStartRequested>(_onStartGame);
    on<CardGameCardPlayedToTable>(_onPlayCardToTable);
    on<CardGameCardPassedToPlayer>(_onPassCardToPlayer);
    on<CardGameTableCleared>(_onClearTable);
    on<CardGameEndRequested>(_onEndGame);
    on<CardGameCancelConfirmed>(_onCancelConfirmed);
    on<CardGameCardDragStarted>(_onDragStarted);
    on<CardGameCardDragEnded>(_onDragEnded);
    on<CardGameGrabFromDeck>(_onGrabFromDeck);
    on<CardGameUndoLastMove>(_onUndoLastMove);
  }

  // ── Private helpers ────────────────────────────────────────────────────

  CardGameLoaded? get _loaded {
    final s = state;
    if (s is CardGameLoaded) return s;
    if (s is CardGameCardMoved) return s.loaded;
    if (s is CardGameShowEndDialog) return s.loaded;
    return null;
  }

  bool get _isHost => _loaded?.room.hostId == _userId;

  // ── Handlers ───────────────────────────────────────────────────────────

  Future<void> _onInitialized(
      CardGameInitialized event, Emitter<CardGameState> emit) async {
    emit(CardGameLoading());
    try {
      final results = await Future.wait([
        CardRoomService.getRoom(event.roomId),
        CardRoomService.getMyMembership(event.roomId),
        CardRoomService.getMembers(event.roomId),
      ]);

      final room = results[0] as CardRoom?;
      final myPlayer = results[1] as CardPlayer?;
      final members = results[2] as List<CardPlayer>;

      if (room == null) {
        emit(CardGameNotFound());
        return;
      }

      emit(CardGameLoaded(
        room: room,
        myPlayer: myPlayer,
        allPlayers: members,
      ));

      // Start real-time subscriptions
      _roomSub = CardRoomService.subscribeToRoom(event.roomId, (r) {
        add(CardGameRoomUpdated(r));
      });
      _membersSub = CardRoomService.subscribeToMembers(event.roomId, (m) {
        add(CardGameMembersUpdated(m));
      });
    } catch (e) {
      emit(CardGameError(e.toString()));
    }
  }

  void _onRoomUpdated(
      CardGameRoomUpdated event, Emitter<CardGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    final updated = prev.copyWith(room: event.room);

    if (event.room.isFinished) {
      emit(CardGameShowEndDialog(updated));
      emit(updated);
      return;
    }

    if (event.room.isCancelled) {
      emit(CardGameCancelled());
      return;
    }

    emit(updated);
  }

  void _onMembersUpdated(
      CardGameMembersUpdated event, Emitter<CardGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    // Keep my player in sync (cards may have changed due to pass-card)
    final myPlayer = event.members
        .cast<CardPlayer?>()
        .firstWhere((m) => m!.userId == _userId,
            orElse: () => prev.myPlayer);

    emit(prev.copyWith(allPlayers: event.members, myPlayer: myPlayer));
  }

  Future<void> _onStartGame(
      CardGameStartRequested event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    emit(prev.copyWith(isProcessing: true));
    try {
      await CardRoomService.startGame(prev.room.id);
      // Stream will update the state
    } catch (e) {
      emit(prev.copyWith(isProcessing: false));
      emit(CardGameError(e.toString()));
      emit(prev);
    }
  }

  Future<void> _onPlayCardToTable(
      CardGameCardPlayedToTable event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || prev.myPlayer == null) return;

    // Optimistic: remove from hand immediately
    final newHand =
        prev.myPlayer!.hand.where((c) => c.id != event.card.id).toList();
    final optimistic = prev.copyWith(
      myPlayer: prev.myPlayer!.copyWith(hand: newHand),
    );
    emit(CardGameCardMoved(optimistic));
    emit(optimistic);

    try {
      await CardRoomService.playCardToTable(
        prev.room.id,
        event.card,
        faceUp: event.faceUp,
      );
    } catch (e) {
      // Rollback on failure
      emit(prev);
      emit(CardGameError('Failed to play card: ${e.toString()}'));
    }
  }

  Future<void> _onPassCardToPlayer(
      CardGameCardPassedToPlayer event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || prev.myPlayer == null) return;

    final newHand =
        prev.myPlayer!.hand.where((c) => c.id != event.card.id).toList();
    final optimistic = prev.copyWith(
      myPlayer: prev.myPlayer!.copyWith(hand: newHand),
    );
    emit(CardGameCardMoved(optimistic));
    emit(optimistic);

    try {
      await CardRoomService.passCardToPlayer(
        prev.room.id,
        event.card,
        event.targetUserId,
      );
    } catch (e) {
      emit(prev);
      emit(CardGameError('Failed to pass card: ${e.toString()}'));
    }
  }

  Future<void> _onClearTable(
      CardGameTableCleared event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    try {
      await CardRoomService.clearTable(prev.room.id);
    } catch (e) {
      emit(CardGameError(e.toString()));
      emit(prev);
    }
  }

  Future<void> _onEndGame(
      CardGameEndRequested event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    emit(prev.copyWith(isProcessing: true));
    try {
      await CardRoomService.endGame(prev.room.id);
    } catch (e) {
      emit(prev.copyWith(isProcessing: false));
      emit(CardGameError(e.toString()));
    }
  }

  Future<void> _onCancelConfirmed(
      CardGameCancelConfirmed event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    emit(prev.copyWith(isProcessing: true));
    try {
      await CardRoomService.deleteRoom(prev.room.id);
      emit(CardGameCancelled());
    } catch (e) {
      emit(prev.copyWith(isProcessing: false));
      emit(CardGameError(e.toString()));
    }
  }

  void _onDragStarted(
      CardGameCardDragStarted event, Emitter<CardGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(draggingCardId: event.cardId));
  }

  void _onDragEnded(
      CardGameCardDragEnded event, Emitter<CardGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(draggingCardId: null));
  }

  Future<void> _onGrabFromDeck(
      CardGameGrabFromDeck event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || prev.myPlayer == null) return;

    // Optimistic: add the grabbed card to my hand immediately
    final newHand = [...prev.myPlayer!.hand, event.card];
    final optimistic = prev.copyWith(
      myPlayer: prev.myPlayer!.copyWith(hand: newHand),
    );
    emit(CardGameCardMoved(optimistic));
    emit(optimistic);

    try {
      await CardRoomService.grabCardFromDeck(
        prev.room.id,
        event.card,
      );
    } catch (e) {
      // Rollback on failure
      emit(prev);
      emit(CardGameError('Failed to grab card: ${e.toString()}'));
    }
  }

  Future<void> _onUndoLastMove(
      CardGameUndoLastMove event, Emitter<CardGameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    if (prev.room.tableCards.isEmpty) return;

    // Optimistic: pop the last table card
    final updatedTableCards = [...prev.room.tableCards]
      ..removeLast();
    final optimistic = prev.copyWith(
      room: prev.room.copyWith(tableCards: updatedTableCards),
    );
    emit(optimistic);

    try {
      await CardRoomService.undoLastTableCard(prev.room.id);
    } catch (e) {
      emit(prev);
      emit(CardGameError('Undo failed: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    return super.close();
  }
}
