part of 'rooms_bloc.dart';

abstract class RoomsEvent extends Equatable {
  const RoomsEvent();
  @override
  List<Object?> get props => [];
}

class RoomsLoadRequested extends RoomsEvent {}

class RoomsTabChanged extends RoomsEvent {
  final int tabIndex; // 0 = Ongoing, 1 = Finished
  const RoomsTabChanged(this.tabIndex);
  @override
  List<Object?> get props => [tabIndex];
}

class RoomsNavChanged extends RoomsEvent {
  final int navIndex;
  const RoomsNavChanged(this.navIndex);
  @override
  List<Object?> get props => [navIndex];
}

class RoomsJoinRequested extends RoomsEvent {
  final String roomId;
  const RoomsJoinRequested(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class RoomsPasswordVerified extends RoomsEvent {
  final String roomId;
  final String password;
  const RoomsPasswordVerified({required this.roomId, required this.password});
  @override
  List<Object?> get props => [roomId, password];
}

class RoomsSearchByCode extends RoomsEvent {
  final String code;
  const RoomsSearchByCode(this.code);
  @override
  List<Object?> get props => [code];
}

class RoomsPageChanged extends RoomsEvent {
  final int tabIndex; // 0 = ongoing, 1 = finished
  final int page;
  const RoomsPageChanged({required this.tabIndex, required this.page});
  @override
  List<Object?> get props => [tabIndex, page];
}

class RoomsFinishedFilterChanged extends RoomsEvent {
  final FinishedFilter filter;
  const RoomsFinishedFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

// Internal event — fired by the Firestore stream listener, not by UI.
class _RoomsStreamUpdated extends RoomsEvent {
  final List<Room> rooms;
  const _RoomsStreamUpdated(this.rooms);
  @override
  List<Object?> get props => [rooms];
}
