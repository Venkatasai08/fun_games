// lib/cardroomgame/blocs/rooms/card_rooms_bloc.dart
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/card_room_model.dart';
import '../../services/card_room_service.dart';

part 'card_rooms_event.dart';
part 'card_rooms_state.dart';

class CardRoomsBloc extends Bloc<CardRoomsEvent, CardRoomsState> {
  StreamSubscription<List<CardRoom>>? _roomsSub;

  CardRoomsBloc() : super(CardRoomsLoading()) {
    on<CardRoomsLoadRequested>(_onLoad);
    on<CardRoomsUpdated>(_onUpdated);
    on<CardRoomsNavChanged>(_onNavChanged);
    on<CardRoomsTabChanged>(_onTabChanged);
    on<CardRoomsJoinRequested>(_onJoin);
    on<CardRoomsSearchByCode>(_onSearchByCode);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  CardRoomsLoaded? get _loaded {
    final s = state;
    if (s is CardRoomsLoaded) return s;
    if (s is CardRoomsJoinLoading) {
      return CardRoomsLoaded(rooms: s.rooms, tabIndex: s.tabIndex, navIndex: s.navIndex);
    }
    return null;
  }

  // ── Handlers ───────────────────────────────────────────────────────────

  Future<void> _onLoad(
      CardRoomsLoadRequested event, Emitter<CardRoomsState> emit) async {
    _roomsSub?.cancel();
    emit(CardRoomsLoading());

    _roomsSub = CardRoomService.watchRooms().listen(
      (rooms) => add(CardRoomsUpdated(rooms)),
      onError: (e) => emit(CardRoomsError(e.toString())),
    );
  }

  void _onUpdated(CardRoomsUpdated event, Emitter<CardRoomsState> emit) {
    final prev = _loaded;
    emit(CardRoomsLoaded(
      rooms: event.rooms,
      tabIndex: prev?.tabIndex ?? 0,
      navIndex: prev?.navIndex ?? 0,
    ));
  }

  void _onNavChanged(
      CardRoomsNavChanged event, Emitter<CardRoomsState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(navIndex: event.index));
  }

  void _onTabChanged(
      CardRoomsTabChanged event, Emitter<CardRoomsState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(tabIndex: event.index));
  }

  Future<void> _onJoin(
      CardRoomsJoinRequested event, Emitter<CardRoomsState> emit) async {
    final prev = _loaded;
    if (prev == null) return;

    emit(CardRoomsJoinLoading(
      rooms: prev.rooms,
      tabIndex: prev.tabIndex,
      navIndex: prev.navIndex,
      joiningRoomId: event.roomId,
    ));

    try {
      final player = await CardRoomService.joinRoom(event.roomId);
      if (player != null) {
        emit(CardRoomsJoinSuccess(roomId: event.roomId));
      } else {
        emit(const CardRoomsJoinFailure('Unable to join room.'));
      }
    } catch (e) {
      emit(CardRoomsJoinFailure(e.toString()));
    }
  }

  Future<void> _onSearchByCode(
      CardRoomsSearchByCode event, Emitter<CardRoomsState> emit) async {
    final prev = _loaded;
    final navIdx = prev?.navIndex ?? 1;
    final tabIdx = prev?.tabIndex ?? 0;

    if (event.code.trim().length != 6) {
      emit(CardRoomsSearchResult(
        navIndex: navIdx,
        tabIndex: tabIdx,
        rooms: prev?.rooms ?? [],
        room: null,
        error: 'Please enter a valid 6-digit code.',
      ));
      return;
    }

    emit(CardRoomsSearchLoading(navIndex: navIdx, tabIndex: tabIdx));

    try {
      final room = await CardRoomService.getRoomByCode(event.code.trim());
      emit(CardRoomsSearchResult(
        navIndex: navIdx,
        tabIndex: tabIdx,
        rooms: prev?.rooms ?? [],
        room: room,
        error: room == null ? 'No room found with that code.' : null,
      ));
    } catch (e) {
      emit(CardRoomsSearchResult(
        navIndex: navIdx,
        tabIndex: tabIdx,
        rooms: prev?.rooms ?? [],
        room: null,
        error: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() {
    _roomsSub?.cancel();
    return super.close();
  }
}
