// lib/cardroomgame/blocs/rooms/card_rooms_state.dart
part of 'card_rooms_bloc.dart';

abstract class CardRoomsState extends Equatable {
  const CardRoomsState();
  @override
  List<Object?> get props => [];
}

class CardRoomsLoading extends CardRoomsState {}

class CardRoomsLoaded extends CardRoomsState {
  final List<CardRoom> rooms;
  final int tabIndex;   // 0 = Ongoing, 1 = Finished
  final int navIndex;   // 0 = Home, 1 = Search, 2 = Create

  const CardRoomsLoaded({
    required this.rooms,
    this.tabIndex = 0,
    this.navIndex = 0,
  });

  List<CardRoom> get ongoingRooms =>
      rooms.where((r) => r.isWaiting || r.isPlaying).toList();

  List<CardRoom> get finishedRooms =>
      rooms.where((r) => r.isFinished || r.isCancelled).toList();

  CardRoomsLoaded copyWith({
    List<CardRoom>? rooms,
    int? tabIndex,
    int? navIndex,
  }) =>
      CardRoomsLoaded(
        rooms: rooms ?? this.rooms,
        tabIndex: tabIndex ?? this.tabIndex,
        navIndex: navIndex ?? this.navIndex,
      );

  @override
  List<Object?> get props => [rooms, tabIndex, navIndex];
}

class CardRoomsJoinLoading extends CardRoomsState {
  final List<CardRoom> rooms;
  final int tabIndex;
  final int navIndex;
  final String joiningRoomId;

  const CardRoomsJoinLoading({
    required this.rooms,
    required this.tabIndex,
    required this.navIndex,
    required this.joiningRoomId,
  });

  @override
  List<Object?> get props => [rooms, tabIndex, navIndex, joiningRoomId];
}

class CardRoomsJoinSuccess extends CardRoomsState {
  final String roomId;
  const CardRoomsJoinSuccess({required this.roomId});
  @override
  List<Object?> get props => [roomId];
}

class CardRoomsJoinFailure extends CardRoomsState {
  final String message;
  const CardRoomsJoinFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class CardRoomsSearchLoading extends CardRoomsState {
  final int navIndex;
  final int tabIndex;
  const CardRoomsSearchLoading({required this.navIndex, required this.tabIndex});
  @override
  List<Object?> get props => [navIndex, tabIndex];
}

class CardRoomsSearchResult extends CardRoomsState {
  final int navIndex;
  final int tabIndex;
  final List<CardRoom> rooms;
  final CardRoom? room;
  final String? error;

  const CardRoomsSearchResult({
    required this.navIndex,
    required this.tabIndex,
    required this.rooms,
    this.room,
    this.error,
  });

  @override
  List<Object?> get props => [navIndex, tabIndex, rooms, room, error];
}

class CardRoomsError extends CardRoomsState {
  final String message;
  const CardRoomsError(this.message);
  @override
  List<Object?> get props => [message];
}
