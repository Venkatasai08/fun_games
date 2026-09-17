part of 'game_bloc.dart';

abstract class GameState extends Equatable {
  const GameState();
  @override
  List<Object?> get props => [];
}

class GameLoading extends GameState {}

class GameNotFound extends GameState {}

class GameLoaded extends GameState {
  final Room room;
  final RoomMember? myMember;
  final List<RoomMember> allMembers;
  final bool isAutoCallPaused;
  final int countdownSeconds;
  final bool isCallingNumber;
  final bool isCancelling;
  /// Per-player runtime sound toggle — seeded from room.soundEnabled,
  /// but each player can flip it locally without a Firestore write.
  final bool soundEnabled;

  const GameLoaded({
    required this.room,
    required this.myMember,
    required this.allMembers,
    this.isAutoCallPaused = false,
    this.countdownSeconds = 0,
    this.isCallingNumber = false,
    this.isCancelling = false,
    this.soundEnabled = false,
  });

  GameLoaded copyWith({
    Room? room,
    RoomMember? myMember,
    List<RoomMember>? allMembers,
    bool? isAutoCallPaused,
    int? countdownSeconds,
    bool? isCallingNumber,
    bool? isCancelling,
    bool? soundEnabled,
  }) =>
      GameLoaded(
        room: room ?? this.room,
        myMember: myMember ?? this.myMember,
        allMembers: allMembers ?? this.allMembers,
        isAutoCallPaused: isAutoCallPaused ?? this.isAutoCallPaused,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
        isCallingNumber: isCallingNumber ?? this.isCallingNumber,
        isCancelling: isCancelling ?? this.isCancelling,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  @override
  List<Object?> get props => [
        room,
        myMember,
        allMembers,
        isAutoCallPaused,
        countdownSeconds,
        isCallingNumber,
        isCancelling,
        soundEnabled,
      ];
}

// Side-effect states (emitted then immediately restored to GameLoaded)
class GameShowPausedSnackbar extends GameState {
  final GameLoaded loaded;
  const GameShowPausedSnackbar(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class GameDismissPausedSnackbar extends GameState {
  final GameLoaded loaded;
  const GameDismissPausedSnackbar(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class GameHapticFeedback extends GameState {
  final GameLoaded loaded;
  const GameHapticFeedback(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class GameShowWinnerDialog extends GameState {
  final GameLoaded loaded;
  const GameShowWinnerDialog(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class GameHousieClaimed extends GameState {
  final GameLoaded loaded;
  final bool won;
  const GameHousieClaimed(this.loaded, {required this.won});
  @override
  List<Object?> get props => [loaded, won];
}

class GameCancelled extends GameState {}

class GameError extends GameState {
  final String message;
  const GameError(this.message);
  @override
  List<Object?> get props => [message];
}
