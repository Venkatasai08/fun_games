// lib/cardroomgame/blocs/game/card_game_event.dart
part of 'card_game_bloc.dart';

abstract class CardGameEvent extends Equatable {
  const CardGameEvent();
  @override
  List<Object?> get props => [];
}

class CardGameInitialized extends CardGameEvent {
  final String roomId;
  const CardGameInitialized(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class CardGameRoomUpdated extends CardGameEvent {
  final CardRoom room;
  const CardGameRoomUpdated(this.room);
  @override
  List<Object?> get props => [room];
}

class CardGameMembersUpdated extends CardGameEvent {
  final List<CardPlayer> members;
  const CardGameMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

/// Host taps "Start Game" — shuffles deck and deals cards
class CardGameStartRequested extends CardGameEvent {}

/// Player drags a card onto the shared table area
class CardGameCardPlayedToTable extends CardGameEvent {
  final PlayingCard card;
  final bool faceUp;
  const CardGameCardPlayedToTable({required this.card, this.faceUp = true});
  @override
  List<Object?> get props => [card, faceUp];
}

/// Player drags a card directly onto another player's avatar
class CardGameCardPassedToPlayer extends CardGameEvent {
  final PlayingCard card;
  final String targetUserId;
  const CardGameCardPassedToPlayer(
      {required this.card, required this.targetUserId});
  @override
  List<Object?> get props => [card, targetUserId];
}

/// Host taps "Clear Table"
class CardGameTableCleared extends CardGameEvent {}

/// Host taps "End Game" (status → finished)
class CardGameEndRequested extends CardGameEvent {}

/// Host confirms cancel/delete in dialog
class CardGameCancelConfirmed extends CardGameEvent {}

/// User starts dragging a card (for local UI highlight)
class CardGameCardDragStarted extends CardGameEvent {
  final String cardId;
  const CardGameCardDragStarted(this.cardId);
  @override
  List<Object?> get props => [cardId];
}

/// Drag ended (dropped or cancelled)
class CardGameCardDragEnded extends CardGameEvent {}

/// Any player taps the deck to grab a random remaining card into their hand
class CardGameGrabFromDeck extends CardGameEvent {
  final PlayingCard card;
  const CardGameGrabFromDeck(this.card);
  @override
  List<Object?> get props => [card];
}

/// Host undoes the last card that was placed on the table
class CardGameUndoLastMove extends CardGameEvent {}
