part of 'draft_lobby_bloc.dart';

abstract class DraftLobbyEvent extends Equatable {
  const DraftLobbyEvent();
  @override
  List<Object?> get props => [];
}

/// Boot / refresh.
class DraftLobbyLoadRequested extends DraftLobbyEvent {}

/// Bottom-nav tab change (0=Home, 1=Search, 2=Create).
class DraftLobbyNavChanged extends DraftLobbyEvent {
  final int index;
  const DraftLobbyNavChanged(this.index);
  @override List<Object?> get props => [index];
}

/// Home sub-tab change (0=Ongoing, 1=Finished).
class DraftLobbyTabChanged extends DraftLobbyEvent {
  final int index;
  const DraftLobbyTabChanged(this.index);
  @override List<Object?> get props => [index];
}

/// Search by code (Search tab).
class DraftLobbySearchByCode extends DraftLobbyEvent {
  final String code;
  const DraftLobbySearchByCode(this.code);
  @override List<Object?> get props => [code];
}

/// Attempt to join a room (Home or Search tab).
class DraftLobbyJoinRequested extends DraftLobbyEvent {
  final String roomId;
  const DraftLobbyJoinRequested(this.roomId);
  @override List<Object?> get props => [roomId];
}

/// Password submitted after DraftLobbyPasswordRequired.
class DraftLobbyPasswordVerified extends DraftLobbyEvent {
  final String roomId;
  final String password;
  const DraftLobbyPasswordVerified({required this.roomId, required this.password});
  @override List<Object?> get props => [roomId, password];
}

/// Create tab: franchise selection changed (multi-select).
class DraftLobbyFranchiseSelected extends DraftLobbyEvent {
  final List<String>? franchises; // null / empty = All franchises
  const DraftLobbyFranchiseSelected(this.franchises);
  @override List<Object?> get props => [franchises];
}

/// Create tab: password toggle.
class DraftLobbyPasswordToggled extends DraftLobbyEvent {
  final bool enabled;
  const DraftLobbyPasswordToggled(this.enabled);
  @override List<Object?> get props => [enabled];
}

/// Create tab: password visibility toggle.
class DraftLobbyPasswordVisibilityToggled extends DraftLobbyEvent {}

/// Create tab: sound toggle.
class DraftLobbySoundToggled extends DraftLobbyEvent {
  final bool enabled;
  const DraftLobbySoundToggled(this.enabled);
  @override List<Object?> get props => [enabled];
}

/// Create tab: submit form.
class DraftLobbyCreateSubmitted extends DraftLobbyEvent {
  final String roomName;
  final List<String>? franchises; // null / empty = all series
  final String? password;
  final List<SlotRole>? slots;
  const DraftLobbyCreateSubmitted({
    required this.roomName,
    this.franchises,
    this.password,
    this.slots,
  });
  @override List<Object?> get props => [roomName, franchises, password, slots];
}

/// Quick-match: join any open public room instantly.
class DraftLobbyQuickMatchRequested extends DraftLobbyEvent {
  final List<String>? franchises;
  const DraftLobbyQuickMatchRequested({this.franchises});
  @override List<Object?> get props => [franchises];
}

/// Cancel waiting / return to idle.
class DraftLobbyCancel extends DraftLobbyEvent {}

// ── Internal events ────────────────────────────────────────────────────────

class _DraftLobbyRoomsUpdated extends DraftLobbyEvent {
  final List<DraftRoom> rooms;
  const _DraftLobbyRoomsUpdated(this.rooms);
  @override List<Object?> get props => [rooms];
}

class _DraftLobbyOpponentJoined extends DraftLobbyEvent {
  final String roomId;
  const _DraftLobbyOpponentJoined(this.roomId);
  @override List<Object?> get props => [roomId];
}

/// Fired when DraftCatalogCubit finishes loading for the first time.
/// Triggers _franchises sync without a redundant Firebase call.
class _DraftCatalogReady extends DraftLobbyEvent {
  const _DraftCatalogReady();
}
