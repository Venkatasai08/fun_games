part of 'draft_lobby_bloc.dart';

abstract class DraftLobbyState extends Equatable {
  const DraftLobbyState();
  @override
  List<Object?> get props => [];
}

class DraftLobbyInitial extends DraftLobbyState {}

class DraftLobbyLoading extends DraftLobbyState {}

/// Main loaded state — drives both Home and Create tabs.
class DraftLobbyLoaded extends DraftLobbyState {
  final List<DraftRoom> rooms;
  final int navIndex; // 0=Home 1=Search 2=Create
  final int tabIndex; // 0=Ongoing 1=Finished (Home sub-tab)
  final List<String> franchises;
  final List<SlotRole> slots;

  // Create tab form state
  final List<String>? selectedFranchises; // null/empty = all series
  final bool hasPassword;
  final bool obscurePassword;
  final bool soundEnabled;

  const DraftLobbyLoaded({
    required this.rooms,
    this.navIndex = 0,
    this.tabIndex = 0,
    this.franchises = const [],
    this.slots = const [],
    this.selectedFranchises,
    this.hasPassword = false,
    this.obscurePassword = true,
    this.soundEnabled = true,
  });

  List<DraftRoom> get ongoingRooms =>
      rooms.where((r) => r.isWaiting || r.isDrafting).toList();

  List<DraftRoom> get finishedRooms =>
      rooms.where((r) => r.isFinished).toList();

  DraftLobbyLoaded copyWith({
    List<DraftRoom>? rooms,
    int? navIndex,
    int? tabIndex,
    List<String>? franchises,
    List<SlotRole>? slots,
    List<String>? selectedFranchises,
    bool clearFranchises = false,
    bool? hasPassword,
    bool? obscurePassword,
    bool? soundEnabled,
  }) {
    return DraftLobbyLoaded(
      rooms: rooms ?? this.rooms,
      navIndex: navIndex ?? this.navIndex,
      tabIndex: tabIndex ?? this.tabIndex,
      franchises: franchises ?? this.franchises,
      slots: slots ?? this.slots,
      selectedFranchises: clearFranchises
          ? null
          : (selectedFranchises ?? this.selectedFranchises),
      hasPassword: hasPassword ?? this.hasPassword,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  List<Object?> get props => [
        rooms,
        navIndex,
        tabIndex,
        franchises,
        slots,
        selectedFranchises,
        hasPassword,
        obscurePassword,
        soundEnabled,
      ];
}

/// Room created — show waiting screen with code.
class DraftLobbyWaiting extends DraftLobbyState {
  final String roomId;
  final String code;
  final String roomName;
  const DraftLobbyWaiting(
      {required this.roomId, required this.code, required this.roomName});
  @override
  List<Object?> get props => [roomId, code, roomName];
}

/// Both players in — navigate to game.
class DraftLobbyReady extends DraftLobbyState {
  final String roomId;
  const DraftLobbyReady(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

/// Searching by code.
class DraftLobbySearchLoading extends DraftLobbyState {}

/// Search result.
class DraftLobbySearchResult extends DraftLobbyState {
  final DraftRoom? room;
  final String? error;
  const DraftLobbySearchResult({this.room, this.error});
  @override
  List<Object?> get props => [room, error];
}

/// Password needed.
class DraftLobbyPasswordRequired extends DraftLobbyState {
  final String roomId;
  final String roomName;
  const DraftLobbyPasswordRequired(
      {required this.roomId, required this.roomName});
  @override
  List<Object?> get props => [roomId, roomName];
}

class DraftLobbyPasswordWrong extends DraftLobbyState {}

/// Joining in progress.
class DraftLobbyJoinLoading extends DraftLobbyState {
  final List<DraftRoom> rooms;
  final int navIndex;
  const DraftLobbyJoinLoading({required this.rooms, required this.navIndex});
  @override
  List<Object?> get props => [rooms, navIndex];
}

class DraftLobbyJoinFailure extends DraftLobbyState {
  final String message;
  const DraftLobbyJoinFailure(this.message);
  @override
  List<Object?> get props => [message];
}

/// Creating room.
class DraftLobbyCreateLoading extends DraftLobbyState {}

class DraftLobbyError extends DraftLobbyState {
  final String message;
  const DraftLobbyError(this.message);
  @override
  List<Object?> get props => [message];
}
