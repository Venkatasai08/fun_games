// lib/cardroomgame/blocs/rooms/card_rooms_event.dart
part of 'card_rooms_bloc.dart';

abstract class CardRoomsEvent extends Equatable {
  const CardRoomsEvent();
  @override
  List<Object?> get props => [];
}

class CardRoomsLoadRequested extends CardRoomsEvent {}

class CardRoomsUpdated extends CardRoomsEvent {
  final List<CardRoom> rooms;
  const CardRoomsUpdated(this.rooms);
  @override
  List<Object?> get props => [rooms];
}

class CardRoomsNavChanged extends CardRoomsEvent {
  final int index;
  const CardRoomsNavChanged(this.index);
  @override
  List<Object?> get props => [index];
}

class CardRoomsTabChanged extends CardRoomsEvent {
  final int index;
  const CardRoomsTabChanged(this.index);
  @override
  List<Object?> get props => [index];
}

class CardRoomsJoinRequested extends CardRoomsEvent {
  final String roomId;
  const CardRoomsJoinRequested(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class CardRoomsSearchByCode extends CardRoomsEvent {
  final String code;
  const CardRoomsSearchByCode(this.code);
  @override
  List<Object?> get props => [code];
}
