// lib/draftclash/blocs/lobby/draft_lobby_bloc.dart
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/draft_catalog_cubit.dart';
import '../../models/draft_room.dart';
import '../../models/slot_role.dart';
import '../../services/draft_service.dart';
import '../../services/draft_sound_service.dart';

part 'draft_lobby_event.dart';
part 'draft_lobby_state.dart';

class DraftLobbyBloc extends Bloc<DraftLobbyEvent, DraftLobbyState> {
  // ── Dependencies ──────────────────────────────────────────────────────────

  /// The session-wide catalog cubit — cards + franchises fetched once on entry.
  final DraftCatalogCubit _catalog;

  // ── Subscriptions ─────────────────────────────────────────────────────────

  StreamSubscription<dynamic>?        _roomsSub;
  StreamSubscription<dynamic>?        _waitSub;
  StreamSubscription<DraftCatalogState>? _catalogSub;

  // ── Local form / nav state ────────────────────────────────────────────────

  List<DraftRoom> _rooms            = [];
  int             _navIndex         = 0;
  int             _tabIndex         = 0;
  List<String>    _franchises       = [];
  List<SlotRole>  _slots            = SlotRole.defaults;
  List<String>?   _selectedFranchises;
  bool            _hasPassword      = false;
  bool            _obscurePassword  = true;
  bool            _soundEnabled     = true;

  // ── Constructor ───────────────────────────────────────────────────────────

  DraftLobbyBloc({required DraftCatalogCubit catalog})
      : _catalog = catalog,
        super(DraftLobbyInitial()) {
    on<DraftLobbyLoadRequested>(_onLoad);
    on<_DraftLobbyRoomsUpdated>(_onRoomsUpdated);
    on<_DraftCatalogReady>(_onCatalogReady);
    on<DraftLobbyNavChanged>(_onNavChanged);
    on<DraftLobbyTabChanged>(_onTabChanged);
    on<DraftLobbySearchByCode>(_onSearch);
    on<DraftLobbyJoinRequested>(_onJoinRequested);
    on<DraftLobbyPasswordVerified>(_onPasswordVerified);
    on<DraftLobbyFranchiseSelected>(_onFranchiseSelected);
    on<DraftLobbyPasswordToggled>(_onPasswordToggled);
    on<DraftLobbyPasswordVisibilityToggled>(_onPasswordVisToggled);
    on<DraftLobbySoundToggled>(_onSoundToggled);
    on<DraftLobbyCreateSubmitted>(_onCreateSubmitted);
    on<_DraftLobbyOpponentJoined>(_onOpponentJoined);
    on<DraftLobbyQuickMatchRequested>(_onQuickMatch);
    on<DraftLobbyCancel>(_onCancel);

    // ── Catalog sync ──────────────────────────────────────────────────────
    //
    // If the catalog is already loaded when this bloc is created (e.g. user
    // navigates away and back), populate franchises immediately.
    // Otherwise subscribe and fire an internal event once it lands.
    if (catalog.state.isLoaded) {
      _franchises = catalog.state.franchiseNames;
      _slots = catalog.state.effectiveSlots;
    } else {
      _catalogSub = catalog.stream.listen((s) {
        if (s.isLoaded) add(const _DraftCatalogReady());
      });
    }

    add(DraftLobbyLoadRequested());
  }

  // ── Load rooms (no Firebase franchise fetch — catalog owns that) ──────────

  Future<void> _onLoad(
      DraftLobbyLoadRequested _, Emitter<DraftLobbyState> emit) async {
    await _roomsSub?.cancel();
    emit(DraftLobbyLoading());

    // Franchises come from DraftCatalogCubit, not Firebase directly.
    // _franchises is already set in the constructor if the catalog was loaded,
    // or will be set via _onCatalogReady when the stream fires.

    _roomsSub = DraftService.watchRooms().listen(
      (rooms) => add(_DraftLobbyRoomsUpdated(rooms)),
      onError: (_) {},
    );
  }

  void _onRoomsUpdated(
      _DraftLobbyRoomsUpdated event, Emitter<DraftLobbyState> emit) {
    _rooms = event.rooms;
    _emitLoaded(emit);
  }

  // ── Catalog ready (internal) ──────────────────────────────────────────────

  void _onCatalogReady(_DraftCatalogReady _, Emitter<DraftLobbyState> emit) {
    _franchises = _catalog.state.franchiseNames;
    _slots = _catalog.state.effectiveSlots;
    _catalogSub?.cancel(); // one-shot — we only need the first load
    _catalogSub = null;
    _emitLoaded(emit);
  }

  // ── Nav ───────────────────────────────────────────────────────────────────

  void _onNavChanged(DraftLobbyNavChanged event, Emitter<DraftLobbyState> emit) {
    _navIndex = event.index;
    DraftSoundService.tapSound();
    _emitLoaded(emit);
  }

  void _onTabChanged(DraftLobbyTabChanged event, Emitter<DraftLobbyState> emit) {
    _tabIndex = event.index;
    DraftSoundService.tapSound();
    _emitLoaded(emit);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _onSearch(
      DraftLobbySearchByCode event, Emitter<DraftLobbyState> emit) async {
    if (event.code.trim().length != 6) {
      emit(const DraftLobbySearchResult(
          error: 'Please enter a valid 6-digit code.'));
      return;
    }
    emit(DraftLobbySearchLoading());
    try {
      final room = await DraftService.getRoomByCode(event.code.trim());
      emit(DraftLobbySearchResult(
        room: room,
        error: room == null ? 'No room found with that code.' : null,
      ));
    } catch (e) {
      emit(DraftLobbySearchResult(error: e.toString()));
    }
  }

  // ── Join ──────────────────────────────────────────────────────────────────

  Future<void> _onJoinRequested(
      DraftLobbyJoinRequested event, Emitter<DraftLobbyState> emit) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final room = _rooms.cast<DraftRoom?>().firstWhere(
          (r) => r!.id == event.roomId,
          orElse: () => null,
        ) ??
        await DraftService.getRoom(event.roomId);

    if (room == null) {
      emit(const DraftLobbyJoinFailure('Room not found.'));
      _emitLoaded(emit);
      return;
    }

    if (myUid != null && room.isHost(myUid)) {
      emit(DraftLobbyWaiting(
        roomId: room.id,
        code: room.code,
        roomName: room.roomName ?? 'Your Room',
      ));
      _subscribeForOpponent(room.id);
      return;
    }

    if (room.hasPassword) {
      emit(DraftLobbyPasswordRequired(
          roomId: room.id, roomName: room.roomName ?? room.code));
      _emitLoaded(emit);
      return;
    }

    await _proceedJoin(event.roomId, emit);
  }

  Future<void> _onPasswordVerified(
      DraftLobbyPasswordVerified event, Emitter<DraftLobbyState> emit) async {
    final ok = await DraftService.verifyPassword(event.roomId, event.password);
    if (!ok) {
      DraftSoundService.errorTap();
      emit(DraftLobbyPasswordWrong());
      _emitLoaded(emit);
      return;
    }
    await _proceedJoin(event.roomId, emit);
  }

  Future<void> _proceedJoin(String roomId, Emitter<DraftLobbyState> emit) async {
    emit(DraftLobbyJoinLoading(rooms: _rooms, navIndex: _navIndex));
    try {
      final room = await DraftService.joinRoomById(roomId);
      if (room == null) {
        DraftSoundService.errorTap();
        emit(const DraftLobbyJoinFailure(
            'Could not join — room may be full or already started.'));
        _emitLoaded(emit);
        return;
      }
      DraftSoundService.successTap();
      await DraftSoundService.joinedRoom(room.roomName ?? 'the room');
      emit(DraftLobbyReady(roomId));
    } catch (e) {
      DraftSoundService.errorTap();
      emit(DraftLobbyJoinFailure(e.toString()));
      _emitLoaded(emit);
    }
  }

  // ── Create tab form ───────────────────────────────────────────────────────

  void _onFranchiseSelected(
      DraftLobbyFranchiseSelected event, Emitter<DraftLobbyState> emit) {
    _selectedFranchises =
        (event.franchises?.isEmpty ?? true) ? null : event.franchises;
    DraftSoundService.tapSound();
    _emitLoaded(emit);
  }

  void _onPasswordToggled(
      DraftLobbyPasswordToggled event, Emitter<DraftLobbyState> emit) {
    _hasPassword = event.enabled;
    _emitLoaded(emit);
  }

  void _onPasswordVisToggled(
      DraftLobbyPasswordVisibilityToggled _, Emitter<DraftLobbyState> emit) {
    _obscurePassword = !_obscurePassword;
    _emitLoaded(emit);
  }

  void _onSoundToggled(
      DraftLobbySoundToggled event, Emitter<DraftLobbyState> emit) {
    _soundEnabled = event.enabled;
    DraftSoundService.soundEnabled = event.enabled;
    _emitLoaded(emit);
  }

  // ── Quick Match ───────────────────────────────────────────────────────────

  Future<void> _onQuickMatch(
      DraftLobbyQuickMatchRequested event, Emitter<DraftLobbyState> emit) async {
    final myUid      = FirebaseAuth.instance.currentUser?.uid;
    final franchises = event.franchises;

    DraftRoom? openRoom;
    if (franchises != null && franchises.isNotEmpty) {
      openRoom = _rooms.cast<DraftRoom?>().firstWhere(
        (r) =>
            r!.isWaiting &&
            !r.hasPassword &&
            (myUid == null || !r.isPlayer(myUid)) &&
            franchises.contains(r.franchise),
        orElse: () => null,
      );
    }
    openRoom ??= _rooms.cast<DraftRoom?>().firstWhere(
      (r) =>
          r!.isWaiting &&
          !r.hasPassword &&
          (myUid == null || !r.isPlayer(myUid)),
      orElse: () => null,
    );

    if (openRoom != null) {
      await _proceedJoin(openRoom.id, emit);
    } else {
      emit(const DraftLobbyError(
          'No open rooms right now.\nTry \'Play with Friend\' instead!'));
      _emitLoaded(emit);
    }
  }

  Future<void> _onCreateSubmitted(
      DraftLobbyCreateSubmitted event, Emitter<DraftLobbyState> emit) async {
    emit(DraftLobbyCreateLoading());
    try {
      final room = await DraftService.createRoom(
        roomName: event.roomName,
        franchises: event.franchises,
        password: event.password,
        slots: event.slots,
        isPublic: true,
      );
      if (room == null) {
        emit(const DraftLobbyError('Failed to create room. Try again.'));
        _emitLoaded(emit);
        return;
      }
      DraftSoundService.successTap();
      await DraftSoundService.roomCreated();

      emit(DraftLobbyWaiting(
        roomId: room.id,
        code: room.code,
        roomName: room.roomName ?? event.roomName,
      ));
      _subscribeForOpponent(room.id);
    } catch (e) {
      DraftSoundService.errorTap();
      emit(DraftLobbyError(e.toString()));
      _emitLoaded(emit);
    }
  }

  void _subscribeForOpponent(String roomId) {
    _waitSub?.cancel();
    _waitSub = DraftService.subscribeToRoom(roomId, (room) {
      if (room.isDrafting) add(_DraftLobbyOpponentJoined(roomId));
    });
  }

  void _onOpponentJoined(
      _DraftLobbyOpponentJoined event, Emitter<DraftLobbyState> emit) {
    _waitSub?.cancel();
    _waitSub = null;
    DraftSoundService.opponentJoined();
    emit(DraftLobbyReady(event.roomId));
  }

  void _onCancel(DraftLobbyCancel _, Emitter<DraftLobbyState> emit) {
    _waitSub?.cancel();
    _waitSub = null;
    _navIndex = 0;
    _emitLoaded(emit);
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _emitLoaded(Emitter<DraftLobbyState> emit) {
    emit(DraftLobbyLoaded(
      rooms: _rooms,
      navIndex: _navIndex,
      tabIndex: _tabIndex,
      franchises: _franchises,
      slots: _slots,
      selectedFranchises: _selectedFranchises,
      hasPassword: _hasPassword,
      obscurePassword: _obscurePassword,
      soundEnabled: _soundEnabled,
    ));
  }

  @override
  Future<void> close() {
    _roomsSub?.cancel();
    _waitSub?.cancel();
    _catalogSub?.cancel();
    return super.close();
  }
}
