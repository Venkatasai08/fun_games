part of 'create_room_bloc.dart';

abstract class CreateRoomEvent extends Equatable {
  const CreateRoomEvent();
  @override
  List<Object?> get props => [];
}

class CreateRoomAutoCallToggled extends CreateRoomEvent {
  final bool value;
  const CreateRoomAutoCallToggled(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateRoomAutoCallIntervalChanged extends CreateRoomEvent {
  final int seconds;
  const CreateRoomAutoCallIntervalChanged(this.seconds);
  @override
  List<Object?> get props => [seconds];
}

class CreateRoomPasswordToggled extends CreateRoomEvent {
  final bool value;
  const CreateRoomPasswordToggled(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateRoomPasswordVisibilityToggled extends CreateRoomEvent {}

class CreateRoomMaxNumberChanged extends CreateRoomEvent {
  final int maxNumber;
  const CreateRoomMaxNumberChanged(this.maxNumber);
  @override
  List<Object?> get props => [maxNumber];
}

class CreateRoomSubmitted extends CreateRoomEvent {
  final String name;
  final String? password;
  const CreateRoomSubmitted({required this.name, this.password});
  @override
  List<Object?> get props => [name, password];
}

class CreateRoomSuggestionModeToggled extends CreateRoomEvent {
  final bool value;
  const CreateRoomSuggestionModeToggled(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateRoomSoundToggled extends CreateRoomEvent {
  final bool value;
  const CreateRoomSoundToggled(this.value);
  @override
  List<Object?> get props => [value];
}

class CreateRoomReset extends CreateRoomEvent {}
