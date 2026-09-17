import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';

part 'rooms_event.dart';
part 'rooms_state.dart';

class RoomsBloc extends Bloc<RoomsEvent, RoomsState> {
  StreamSubscription<List<Room>>? _roomsSub;

  List<Room> _rooms = [];
  int _tabIndex = 0;
  int _navIndex = 0;

  RoomsBloc() : super(RoomsInitial()) {
    on<_RoomsStreamUpdated>(_onStreamUpdated);
    on<RoomsLoadRequested>(_onLoad);
    on<RoomsTabChanged>(_onTabChanged);
    on<RoomsNavChanged>(_onNavChanged);
    on<RoomsJoinRequested>(_onJoinRequested);
    on<RoomsPasswordVerified>(_onPasswordVerified);
    on<RoomsSearchByCode>(_onSearchByCode);
    on<RoomsPageChanged>(_onPageChanged);
    on<RoomsFinishedFilterChanged>(_onFinishedFilterChanged);

    // Kick off the live stream immediately
    add(RoomsLoadRequested());
  }

  // ── Stream subscription ──────────────────────────────────────────────────

  Future<void> _onLoad(
      RoomsLoadRequested event, Emitter<RoomsState> emit) async {
    // Cancel any existing subscription first (handles pull-to-refresh)
    await _roomsSub?.cancel();

    emit(RoomsLoading());

    _roomsSub = RoomService.watchRooms().listen(
      (rooms) => add(_RoomsStreamUpdated(rooms)),
      onError: (e) => emit(RoomsError(e.toString())),
    );
  }

  void _onStreamUpdated(
      _RoomsStreamUpdated event, Emitter<RoomsState> emit) {
    _rooms = event.rooms;
    final current = state is RoomsLoaded ? state as RoomsLoaded : null;
    emit(RoomsLoaded._internal(
      rooms: _rooms,
      tabIndex: _tabIndex,
      navIndex: _navIndex,
      ongoingPage: 0,
      finishedPage: 0,
      finishedFilter: current?.finishedFilter ?? FinishedFilter.all,
      myUserId: current?.myUserId,
    ));
  }

  // ── Tab / nav ─────────────────────────────────────────────────────────────

  void _onTabChanged(RoomsTabChanged event, Emitter<RoomsState> emit) {
    _tabIndex = event.tabIndex;
    _emitLoaded(emit);
  }

  void _onNavChanged(RoomsNavChanged event, Emitter<RoomsState> emit) {
    _navIndex = event.navIndex;
    _emitLoaded(emit);
  }

  // ── Join ──────────────────────────────────────────────────────────────────

  Future<void> _onJoinRequested(
      RoomsJoinRequested event, Emitter<RoomsState> emit) async {
    Room? room = _rooms.cast<Room?>().firstWhere(
      (r) => r!.id == event.roomId,
      orElse: () => null,
    );
    room ??= await RoomService.getRoom(event.roomId);

    if (room == null) {
      emit(const RoomsJoinFailure('Room not found'));
      _emitLoaded(emit);
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (room.hasPassword && room.hostId != currentUid) {
      emit(RoomsPasswordRequired(roomId: room.id, roomName: room.name));
      _emitLoaded(emit);
      return;
    }

    await _proceedJoin(event.roomId, emit);
  }

  Future<void> _onPasswordVerified(
      RoomsPasswordVerified event, Emitter<RoomsState> emit) async {
    final isValid =
        await RoomService.verifyPassword(event.roomId, event.password);
    if (!isValid) {
      emit(RoomsPasswordWrong());
      _emitLoaded(emit);
      return;
    }
    await _proceedJoin(event.roomId, emit);
  }

  Future<void> _proceedJoin(String roomId, Emitter<RoomsState> emit) async {
    emit(RoomsJoinLoading(
        rooms: _rooms, tabIndex: _tabIndex, navIndex: _navIndex));
    try {
      await RoomService.joinRoom(roomId);
      emit(RoomsJoinSuccess(roomId));
    } catch (e) {
      emit(RoomsJoinFailure(e.toString()));
    }
    _emitLoaded(emit);
  }

  // ── Filter / page ─────────────────────────────────────────────────────────

  void _onFinishedFilterChanged(
      RoomsFinishedFilterChanged event, Emitter<RoomsState> emit) {
    final current = _currentLoaded;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    emit(current.copyWith(
      finishedFilter: event.filter,
      myUserId: uid,
      finishedPage: 0,
    ));
  }

  void _onPageChanged(RoomsPageChanged event, Emitter<RoomsState> emit) {
    final current = _currentLoaded;
    if (event.tabIndex == 0) {
      emit(current.copyWith(ongoingPage: event.page));
    } else {
      emit(current.copyWith(finishedPage: event.page));
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _onSearchByCode(
      RoomsSearchByCode event, Emitter<RoomsState> emit) async {
    if (event.code.length != 6) {
      emit(const RoomsSearchResult(
          error: 'Please enter a valid 6-digit room code'));
      return;
    }
    emit(RoomsSearchLoading());
    try {
      final room = await RoomService.getRoomByCode(event.code);
      emit(RoomsSearchResult(
          room: room,
          error: room == null ? 'No room found with that code' : null));
    } catch (e) {
      emit(RoomsSearchResult(error: e.toString()));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  RoomsLoaded get _currentLoaded => state is RoomsLoaded
      ? state as RoomsLoaded
      : RoomsLoaded._internal(
          rooms: _rooms,
          tabIndex: _tabIndex,
          navIndex: _navIndex,
          ongoingPage: 0,
          finishedPage: 0,
          finishedFilter: FinishedFilter.all,
          myUserId: null,
        );

  void _emitLoaded(Emitter<RoomsState> emit) {
    final current = state is RoomsLoaded ? state as RoomsLoaded : null;
    emit(RoomsLoaded._internal(
      rooms: _rooms,
      tabIndex: _tabIndex,
      navIndex: _navIndex,
      ongoingPage: current?.ongoingPage ?? 0,
      finishedPage: current?.finishedPage ?? 0,
      finishedFilter: current?.finishedFilter ?? FinishedFilter.all,
      myUserId: current?.myUserId,
    ));
  }

  @override
  Future<void> close() {
    _roomsSub?.cancel();
    return super.close();
  }
}
