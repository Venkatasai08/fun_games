part of 'rooms_bloc.dart';

abstract class RoomsState extends Equatable {
  const RoomsState();
  @override
  List<Object?> get props => [];
}

class RoomsInitial extends RoomsState {}

class RoomsLoading extends RoomsState {}

/// Filter options for the Finished tab.
enum FinishedFilter { all, mine, winner, cancelled }

class RoomsLoaded extends RoomsState {
  final List<Room> rooms;
  final int tabIndex;
  final int navIndex;
  final int ongoingPage;
  final int finishedPage;
  final FinishedFilter finishedFilter;

  static const int pageSize = 6;

  const RoomsLoaded({
    required this.rooms,
    this.tabIndex = 0,
    this.navIndex = 0,
    this.ongoingPage = 0,
    this.finishedPage = 0,
    this.finishedFilter = FinishedFilter.all,
  }) : _myUserId = null;

  List<Room> get _allOngoing =>
      rooms.where((r) => r.status == 'waiting' || r.status == 'playing').toList();

  List<Room> get _allFinished {
    final finished = rooms
        .where((r) => r.status == 'finished' || r.status == 'cancelled')
        .toList();
    switch (finishedFilter) {
      case FinishedFilter.mine:
        return finished.where((r) => r.hostId == _myUserId).toList();
      case FinishedFilter.winner:
        // Games that completed with a winner (not cancelled)
        return finished.where((r) => r.status == 'finished' && r.winnerUsername != null).toList();
      case FinishedFilter.cancelled:
        return finished.where((r) => r.status == 'cancelled').toList();
      case FinishedFilter.all:
        return finished;
    }
  }

  // Set by the bloc when the filter is 'mine'; null means show all.
  // Exposed as a getter so the bloc can read it back without breaking encapsulation.
  final String? _myUserId;
  String? get myUserId => _myUserId;

  const RoomsLoaded._internal({
    required this.rooms,
    required this.tabIndex,
    required this.navIndex,
    required this.ongoingPage,
    required this.finishedPage,
    required this.finishedFilter,
    required String? myUserId,
  }) : _myUserId = myUserId;

  // Paginated slices
  List<Room> get ongoingRooms {
    final all = _allOngoing;
    final start = ongoingPage * pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + pageSize).clamp(0, all.length));
  }

  List<Room> get finishedRooms {
    final all = _allFinished;
    final start = finishedPage * pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + pageSize).clamp(0, all.length));
  }

  // Total page counts
  int get ongoingPageCount => (_allOngoing.length / pageSize).ceil().clamp(1, 999);
  int get finishedPageCount => (_allFinished.length / pageSize).ceil().clamp(1, 999);

  // Whether each tab has more than one page
  bool get ongoingHasPages => _allOngoing.length > pageSize;
  bool get finishedHasPages => _allFinished.length > pageSize;

  RoomsLoaded copyWith({
    List<Room>? rooms,
    int? tabIndex,
    int? navIndex,
    int? ongoingPage,
    int? finishedPage,
    FinishedFilter? finishedFilter,
    String? myUserId,
  }) =>
      RoomsLoaded._internal(
        rooms: rooms ?? this.rooms,
        tabIndex: tabIndex ?? this.tabIndex,
        navIndex: navIndex ?? this.navIndex,
        ongoingPage: ongoingPage ?? this.ongoingPage,
        finishedPage: finishedPage ?? this.finishedPage,
        finishedFilter: finishedFilter ?? this.finishedFilter,
        myUserId: myUserId ?? this._myUserId,
      );

  @override
  List<Object?> get props =>
      [rooms, tabIndex, navIndex, ongoingPage, finishedPage, finishedFilter, _myUserId];
}

class RoomsError extends RoomsState {
  final String message;
  const RoomsError(this.message);
  @override
  List<Object?> get props => [message];
}

// Joining states
class RoomsJoinLoading extends RoomsState {
  final List<Room> rooms;
  final int tabIndex;
  final int navIndex;
  const RoomsJoinLoading({
    required this.rooms,
    required this.tabIndex,
    required this.navIndex,
  });
  @override
  List<Object?> get props => [rooms, tabIndex, navIndex];
}

class RoomsPasswordRequired extends RoomsState {
  final String roomId;
  final String roomName;
  const RoomsPasswordRequired({required this.roomId, required this.roomName});
  @override
  List<Object?> get props => [roomId, roomName];
}

class RoomsJoinSuccess extends RoomsState {
  final String roomId;
  const RoomsJoinSuccess(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class RoomsJoinFailure extends RoomsState {
  final String message;
  const RoomsJoinFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class RoomsPasswordWrong extends RoomsState {}

// Search states
class RoomsSearchLoading extends RoomsState {}

class RoomsSearchResult extends RoomsState {
  final Room? room;
  final String? error;
  const RoomsSearchResult({this.room, this.error});
  @override
  List<Object?> get props => [room, error];
}
