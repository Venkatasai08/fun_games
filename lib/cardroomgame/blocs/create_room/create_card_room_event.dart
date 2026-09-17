// lib/cardroomgame/blocs/create_room/create_card_room_event.dart
part of 'create_card_room_bloc.dart';

abstract class CreateCardRoomEvent extends Equatable {
  const CreateCardRoomEvent();
  @override
  List<Object?> get props => [];
}

class CreateCardRoomNameChanged extends CreateCardRoomEvent {
  final String name;
  const CreateCardRoomNameChanged(this.name);
  @override
  List<Object?> get props => [name];
}

class CreateCardRoomMaxPlayersChanged extends CreateCardRoomEvent {
  final int value;
  const CreateCardRoomMaxPlayersChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateCardRoomCardsPerPlayerChanged extends CreateCardRoomEvent {
  final int value;
  const CreateCardRoomCardsPerPlayerChanged(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateCardRoomHostModeChanged extends CreateCardRoomEvent {
  final HostMode mode;
  const CreateCardRoomHostModeChanged(this.mode);
  @override
  List<Object?> get props => [mode];
}

/// User taps "Create Room" button
class CreateCardRoomSubmitted extends CreateCardRoomEvent {}

/// Reset form back to initial state (called after success/failure)
class CreateCardRoomReset extends CreateCardRoomEvent {}
