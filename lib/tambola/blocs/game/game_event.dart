part of 'game_bloc.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameInitialized extends GameEvent {
  final String roomId;
  const GameInitialized(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class GameRoomUpdated extends GameEvent {
  final Room room;
  const GameRoomUpdated(this.room);
  @override
  List<Object?> get props => [room];
}

class GameMembersUpdated extends GameEvent {
  final List<RoomMember> members;
  const GameMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

class GameCountdownTicked extends GameEvent {
  final int seconds;
  const GameCountdownTicked(this.seconds);
  @override
  List<Object?> get props => [seconds];
}

/// Host taps "Start Game"
class GameStartRequested extends GameEvent {}

/// Host manually calls next number (non-auto-call mode)
class GameNumberCallRequested extends GameEvent {}

class GamePauseRequested extends GameEvent {}

class GameResumeRequested extends GameEvent {}

/// Host confirms cancel/delete in dialog
class GameCancelConfirmed extends GameEvent {}

class GameNumberMarked extends GameEvent {
  final int number;
  const GameNumberMarked(this.number);
  @override
  List<Object?> get props => [number];
}

/// Player confirms housie claim in dialog
class GameHousieClaimConfirmed extends GameEvent {}

/// Per-player local sound toggle (not persisted to Firestore)
class GameSoundToggled extends GameEvent {
  final bool value;
  const GameSoundToggled(this.value);
  @override
  List<Object?> get props => [value];
}

/// Host submits live settings changes from the edit dialog
class GameSettingsUpdateRequested extends GameEvent {
  final bool autoCall;
  final int autoCallInterval;
  final bool suggestionMode;
  final bool soundEnabled;
  const GameSettingsUpdateRequested({
    required this.autoCall,
    required this.autoCallInterval,
    required this.suggestionMode,
    required this.soundEnabled,
  });
  @override
  List<Object?> get props => [autoCall, autoCallInterval, suggestionMode, soundEnabled];
}


