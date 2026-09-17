part of 'pnp_bloc.dart';

abstract class PnPEvent extends Equatable {
  const PnPEvent();
  @override
  List<Object?> get props => [];
}

/// Boot — called right after the BLoC is created with the Firestore roomId.
class PnPInitialized extends PnPEvent {
  final String roomId;
  const PnPInitialized(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

/// Active player tapped "I'm Ready" on the pass-the-phone interstitial.
class PnPPassConfirmed extends PnPEvent {}

/// Active player tapped a board slot to place the current card there.
class PnPCardAssigned extends PnPEvent {
  final BoardSlot slot;
  const PnPCardAssigned(this.slot);
  @override
  List<Object?> get props => [slot];
}

/// Active player tapped SKIP (one-time per player per game).
class PnPSkipRequested extends PnPEvent {}

/// Turn timer expired — auto-place the card in the first empty slot.
class PnPAutoAssign extends PnPEvent {}

// ── Internal (Firestore stream callbacks) ─────────────────────────────────────

class _PnPRoomUpdated extends PnPEvent {
  final DraftRoom room;
  const _PnPRoomUpdated(this.room);
  @override
  List<Object?> get props => [room];
}

class _PnPMembersUpdated extends PnPEvent {
  final List<DraftMember> members;
  const _PnPMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

class _PnPCountdownTicked extends PnPEvent {
  final int seconds;
  const _PnPCountdownTicked(this.seconds);
  @override
  List<Object?> get props => [seconds];
}
