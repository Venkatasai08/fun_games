// lib/cardroomgame/blocs/game/card_game_state.dart
part of 'card_game_bloc.dart';

abstract class CardGameState extends Equatable {
  const CardGameState();
  @override
  List<Object?> get props => [];
}

class CardGameLoading extends CardGameState {}

class CardGameNotFound extends CardGameState {}

// ── Primary loaded state ─────────────────────────────────────────────────

class CardGameLoaded extends CardGameState {
  final CardRoom room;
  final CardPlayer? myPlayer;
  final List<CardPlayer> allPlayers;
  final bool isProcessing;
  final String? draggingCardId; // id of card currently being dragged

  const CardGameLoaded({
    required this.room,
    required this.myPlayer,
    required this.allPlayers,
    this.isProcessing = false,
    this.draggingCardId,
  });

  /// True if I am the host
  bool get amHost => myPlayer?.userId != null
      ? room.hostId == myPlayer!.userId
      : false;

  /// Players excluding self  (for opponent indicators)
  List<CardPlayer> get opponents =>
      allPlayers.where((p) => p.userId != myPlayer?.userId).toList();

  CardGameLoaded copyWith({
    CardRoom? room,
    CardPlayer? myPlayer,
    List<CardPlayer>? allPlayers,
    bool? isProcessing,
    String? draggingCardId,
    bool clearDragging = false,
  }) =>
      CardGameLoaded(
        room: room ?? this.room,
        myPlayer: myPlayer ?? this.myPlayer,
        allPlayers: allPlayers ?? this.allPlayers,
        isProcessing: isProcessing ?? this.isProcessing,
        draggingCardId:
            clearDragging ? null : (draggingCardId ?? this.draggingCardId),
      );

  @override
  List<Object?> get props =>
      [room, myPlayer, allPlayers, isProcessing, draggingCardId];
}

// ── Side-effect / one-shot states ────────────────────────────────────────

/// Emitted right after a card move so widgets can play a brief animation,
/// then immediately replaced by the updated CardGameLoaded.
class CardGameCardMoved extends CardGameState {
  final CardGameLoaded loaded;
  const CardGameCardMoved(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

/// Host pressed "End Game" — show confirmation dialog.
class CardGameShowEndDialog extends CardGameState {
  final CardGameLoaded loaded;
  const CardGameShowEndDialog(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class CardGameCancelled extends CardGameState {}

class CardGameError extends CardGameState {
  final String message;
  const CardGameError(this.message);
  @override
  List<Object?> get props => [message];
}
