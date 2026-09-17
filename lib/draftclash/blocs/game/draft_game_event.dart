part of 'draft_game_bloc.dart';

abstract class DraftGameEvent extends Equatable {
  const DraftGameEvent();
  @override
  List<Object?> get props => [];
}

class DraftGameInitialized extends DraftGameEvent {
  final String roomId;
  const DraftGameInitialized(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class DraftGameRoomUpdated extends DraftGameEvent {
  final DraftRoom room;
  const DraftGameRoomUpdated(this.room);
  @override
  // React whenever turn advances or game ends; turnNumber drives card changes.
  List<Object?> get props => [room.id, room.status, room.turnNumber, room.currentTurn];
}

class DraftGameMembersUpdated extends DraftGameEvent {
  final List<DraftMember> members;
  const DraftGameMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

class DraftGameCountdownTicked extends DraftGameEvent {
  final int seconds;
  const DraftGameCountdownTicked(this.seconds);
  @override
  List<Object?> get props => [seconds];
}

/// Player taps a slot to assign the current card there.
class DraftGameCardAssigned extends DraftGameEvent {
  final SlotRole slot;
  const DraftGameCardAssigned(this.slot);
  @override
  List<Object?> get props => [slot];
}

/// Player taps Skip (one-time use per match).
class DraftGameSkipRequested extends DraftGameEvent {}

/// Timer expired — auto-assign to first empty slot.
class DraftGameAutoAssign extends DraftGameEvent {}
