import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';
import '../../services/tts_service.dart';
import '../../models/ticket_model.dart';

part 'game_event.dart';
part 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _membersSub;
  Timer? _autoCallTimer;
  Timer? _countdownTimer;

  /// Exposed so the UI can check host status without accessing private fields.
  bool get isHost {
    final s = state;
    if (s is GameLoaded) return s.room.hostId == _userId;
    return false;
  }

  GameBloc() : super(GameLoading()) {
    on<GameInitialized>(_onInitialized);
    on<GameRoomUpdated>(_onRoomUpdated);
    on<GameMembersUpdated>(_onMembersUpdated);
    on<GameCountdownTicked>(_onCountdownTicked);
    on<GameStartRequested>(_onStartGame);
    on<GameNumberCallRequested>(_onCallNumber);
    on<GamePauseRequested>(_onPause);
    on<GameResumeRequested>(_onResume);
    on<GameCancelConfirmed>(_onCancelConfirmed);
    on<GameNumberMarked>(_onNumberMarked);
    on<GameHousieClaimConfirmed>(_onHousieClaimConfirmed);
    on<GameSoundToggled>(_onSoundToggled);
    on<GameSettingsUpdateRequested>(_onSettingsUpdate);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  GameLoaded? get _loaded {
    final s = state;
    if (s is GameLoaded) return s;
    // Side-effect states carry a loaded snapshot — use it so timers still work
    if (s is GameShowPausedSnackbar) return s.loaded;
    if (s is GameDismissPausedSnackbar) return s.loaded;
    if (s is GameHapticFeedback) return s.loaded;
    if (s is GameShowWinnerDialog) return s.loaded;
    if (s is GameHousieClaimed) return s.loaded;
    return null;
  }

  bool get _isHost => _loaded?.room.hostId == _userId;

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    // Tick immediately so UI shows full value, then count down each second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = seconds - t.tick;
      if (remaining >= 0) {
        add(GameCountdownTicked(remaining));
      } else {
        t.cancel();
      }
    });
  }

  void _startAutoCall(int intervalSeconds) {
    _autoCallTimer?.cancel();
    _autoCallTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => add(GameNumberCallRequested()),
    );
  }

  void _stopTimers() {
    _autoCallTimer?.cancel();
    _countdownTimer?.cancel();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onInitialized(
      GameInitialized event, Emitter<GameState> emit) async {
    emit(GameLoading());
    try {
      final results = await Future.wait([
        RoomService.getRoom(event.roomId),
        RoomService.getMyMembership(event.roomId),
        RoomService.getMembers(event.roomId),
      ]);

      final room = results[0] as Room?;
      final myMember = results[1] as RoomMember?;
      final members = results[2] as List<RoomMember>;

      if (room == null) {
        emit(GameNotFound());
        return;
      }

      final isPaused = room.autoCall && room.isPlaying && room.isPaused;
      final loaded = GameLoaded(
        room: room,
        myMember: myMember,
        allMembers: members,
        isAutoCallPaused: isPaused,
        // Host defaults ON, participants default OFF (from room.soundEnabled)
        soundEnabled: room.soundEnabled,
      );
      emit(loaded);

      // Restore timers for already-running games (joining mid-game)
      if (room.autoCall && room.isPlaying) {
        if (room.isPaused) {
          emit(GameShowPausedSnackbar(loaded));
          emit(loaded);
        } else {
          _startCountdown(room.autoCallInterval);
          if (_isHost) _startAutoCall(room.autoCallInterval);
        }
      }

      // Subscribe to realtime updates after initial state is set
      _roomSub = RoomService.subscribeToRoom(event.roomId, (updatedRoom) {
        add(GameRoomUpdated(updatedRoom));
      });
      _membersSub = RoomService.subscribeToMembers(event.roomId, (members) {
        add(GameMembersUpdated(members));
      });
    } catch (e) {
      emit(GameError(e.toString()));
    }
  }

  void _onRoomUpdated(GameRoomUpdated event, Emitter<GameState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    final updatedRoom = event.room;
    final prevLastCalled = prev.room.lastCalled;
    final prevIsPaused = prev.room.isPaused;
    final wasPlaying = prev.room.isPlaying;

    final newLoaded = prev.copyWith(
      room: updatedRoom.copyWith(memberCount: prev.allMembers.length),
    );

    // ── Pause / resume ─────────────────────────────────────────────────────
    if (updatedRoom.isPaused != prevIsPaused) {
      if (updatedRoom.isPaused) {
        _stopTimers();
        final paused =
            newLoaded.copyWith(isAutoCallPaused: true, countdownSeconds: 0);
        emit(GameShowPausedSnackbar(paused));
        emit(paused);
      } else {
        final resumed = newLoaded.copyWith(isAutoCallPaused: false);
        emit(GameDismissPausedSnackbar(resumed));
        emit(resumed);
        _startCountdown(updatedRoom.autoCallInterval);
        if (_isHost) _startAutoCall(updatedRoom.autoCallInterval);
      }
      return;
    }

    // ── Game just started ──────────────────────────────────────────────────
    if (!wasPlaying && updatedRoom.isPlaying) {
      emit(newLoaded);
      if (updatedRoom.autoCall) {
        _startCountdown(updatedRoom.autoCallInterval);
        if (_isHost) _startAutoCall(updatedRoom.autoCallInterval);
      }
      return;
    }

    // ── New number called ──────────────────────────────────────────────────
    if (updatedRoom.lastCalled != null &&
        updatedRoom.lastCalled != prevLastCalled) {
      // Announce number via TTS if player has sound enabled
      TtsService.instance.announceNumber(
        updatedRoom.lastCalled!,
        enabled: newLoaded.soundEnabled,
      );
      emit(GameHapticFeedback(newLoaded));
      emit(newLoaded);
      if (updatedRoom.autoCall &&
          updatedRoom.isPlaying &&
          !updatedRoom.isPaused) {
        _startCountdown(updatedRoom.autoCallInterval);
      }
      return;
    }

    // ── Game finished ──────────────────────────────────────────────────────
    if (updatedRoom.isFinished) {
      _stopTimers();
      final finished = newLoaded.copyWith(countdownSeconds: 0);
      emit(GameDismissPausedSnackbar(finished));
      emit(GameShowWinnerDialog(finished));
      emit(finished);
      return;
    }

    emit(newLoaded);
  }

  void _onMembersUpdated(
      GameMembersUpdated event, Emitter<GameState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    // Use the updated member if found; fall back to the previous one (which
    // may be null for guests whose Firestore write hasn't propagated yet).
    final myMember = event.members.cast<RoomMember?>().firstWhere(
      (m) => m!.userId == _userId,
      orElse: () => prev.myMember,
    );

    emit(prev.copyWith(allMembers: event.members, myMember: myMember));
  }

  void _onCountdownTicked(
      GameCountdownTicked event, Emitter<GameState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(countdownSeconds: event.seconds));
  }

  Future<void> _onStartGame(
      GameStartRequested event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    try {
      await RoomService.startGame(prev.room.id);
      // Stream will handle the state update
    } catch (e) {
      emit(GameError(e.toString()));
      emit(prev);
    }
  }

  Future<void> _onCallNumber(
      GameNumberCallRequested event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost || prev.isCallingNumber) return;
    if (prev.isAutoCallPaused || !prev.room.isPlaying) return;

    emit(prev.copyWith(isCallingNumber: true));
    try {
      await RoomService.callNextNumber(prev.room.id);
    } catch (e) {
      // Ignore — stream will update
    } finally {
      final current = _loaded;
      if (current != null && current.isCallingNumber) {
        emit(current.copyWith(isCallingNumber: false));
      }
    }
  }

  Future<void> _onPause(
      GamePauseRequested event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    _stopTimers();
    emit(prev.copyWith(isAutoCallPaused: true, countdownSeconds: 0));
    await RoomService.setPaused(prev.room.id, paused: true);
  }

  Future<void> _onResume(
      GameResumeRequested event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    // Timers restart via stream when isPaused flips to false
    await RoomService.setPaused(prev.room.id, paused: false);
  }

  Future<void> _onCancelConfirmed(
      GameCancelConfirmed event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    emit(prev.copyWith(isCancelling: true));
    try {
      await RoomService.deleteRoom(prev.room.id);
      emit(GameCancelled());
    } catch (e) {
      emit(prev.copyWith(isCancelling: false));
      emit(GameError(e.toString()));
      emit(prev);
    }
  }

  Future<void> _onNumberMarked(
      GameNumberMarked event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || prev.myMember == null) return;

    final markedNums = List<int>.from(prev.myMember!.markedNumbers);
    if (markedNums.contains(event.number)) return;
    markedNums.add(event.number);

    final updatedMember = RoomMember(
      id: prev.myMember!.id,
      roomId: prev.myMember!.roomId,
      userId: prev.myMember!.userId,
      username: prev.myMember!.username,
      ticket: prev.myMember!.ticket,
      markedNumbers: markedNums,
      hasClaimedHousie: prev.myMember!.hasClaimedHousie,
    );
    // Optimistic update
    emit(prev.copyWith(myMember: updatedMember));
    await RoomService.markNumber(prev.room.id, event.number);
  }

  Future<void> _onHousieClaimConfirmed(
      GameHousieClaimConfirmed event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null) return;

    final won = await RoomService.claimHousie(prev.room.id);
    emit(GameHousieClaimed(prev, won: won));
    emit(prev);
  }

  void _onSoundToggled(GameSoundToggled event, Emitter<GameState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    if (!event.value) TtsService.instance.stop();
    emit(prev.copyWith(soundEnabled: event.value));
  }

  Future<void> _onSettingsUpdate(
      GameSettingsUpdateRequested event, Emitter<GameState> emit) async {
    final prev = _loaded;
    if (prev == null || !_isHost) return;
    try {
      await RoomService.updateRoomSettings(
        prev.room.id,
        autoCall: event.autoCall,
        autoCallInterval: event.autoCallInterval,
        suggestionMode: event.suggestionMode,
        soundEnabled: event.soundEnabled,
      );
      // Restart/stop auto-call timers based on new settings
      if (event.autoCall && prev.room.isPlaying && !prev.isAutoCallPaused) {
        _stopTimers();
        _startCountdown(event.autoCallInterval);
        _startAutoCall(event.autoCallInterval);
      } else if (!event.autoCall) {
        _stopTimers();
      }
      // Stream will update the room in state automatically
    } catch (e) {
      emit(GameError(e.toString()));
      emit(prev);
    }
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _stopTimers();
    TtsService.instance.stop();
    return super.close();
  }
}
