// lib/draftclash/blocs/pass_and_play/pnp_bloc.dart
//
// BLoC for the online-backed Pass & Play game mode.
//
// Architecture:
//   • A real Firestore room is created so spectators can watch from the
//     Live Arena.
//   • Both players share one device; the BLoC manages which player is
//     "holding the phone" via the [phase] field:
//       'pass'   → show the pass-the-phone interstitial
//       'play'   → show the active board; timer is running
//       'result' → game finished, show result overlay
//   • All card assignments / skips are written to Firestore via the
//     PnP-specific DraftService helpers (no auth-uid checks needed).
//   • The Firestore room stream is the single source of truth — the BLoC
//     reacts to stream events exactly as the online DraftGameBloc does.
//
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/board_slot.dart';
import '../../models/draft_card.dart';
import '../../models/draft_member.dart';
import '../../models/draft_room.dart';
import '../../services/draft_service.dart';

part 'pnp_event.dart';
part 'pnp_state.dart';

class PnPBloc extends Bloc<PnPEvent, PnPState> {
  final String p1Id;
  final String p2Id;
  final String p1Name;
  final String p2Name;
  final Map<String, DraftCard> cardCache;

  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _membersSub;
  Timer? _countdownTimer;

  PnPBloc({
    required this.p1Id,
    required this.p2Id,
    required this.p1Name,
    required this.p2Name,
    required this.cardCache,
  }) : super(PnPLoading()) {
    on<PnPInitialized>(_onInit);
    on<_PnPRoomUpdated>(_onRoomUpdated);
    on<_PnPMembersUpdated>(_onMembersUpdated);
    on<_PnPCountdownTicked>(_onCountdownTicked);
    on<PnPPassConfirmed>(_onPassConfirmed);
    on<PnPCardAssigned>(_onCardAssigned);
    on<PnPSkipRequested>(_onSkip);
    on<PnPAutoAssign>(_onAutoAssign);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  PnPLoaded? get _loaded {
    final s = state;
    if (s is PnPLoaded) return s;
    if (s is PnPHapticFeedback) return s.loaded;
    return null;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _onInit(PnPInitialized event, Emitter<PnPState> emit) async {
    emit(PnPLoading());
    try {
      final room    = await DraftService.getRoom(event.roomId);
      final members = await DraftService.getMembers(event.roomId);
      if (room == null) {
        emit(const PnPError('Room not found.'));
        return;
      }

      final p1m = members.cast<DraftMember?>().firstWhere(
          (m) => m!.userId == p1Id, orElse: () => members.isNotEmpty ? members.first : null);
      final p2m = members.cast<DraftMember?>().firstWhere(
          (m) => m!.userId == p2Id, orElse: () => members.length > 1 ? members.last : null);

      final currentCard = room.currentCardId != null
          ? cardCache[room.currentCardId]
          : null;

      final loaded = PnPLoaded(
        room: room,
        p1Member: p1m,
        p2Member: p2m,
        currentCard: currentCard,
        cardCache: cardCache,
        countdownSeconds: room.secondsRemaining.clamp(0, 30),
        phase: 'pass',
        currentPlayerId: room.currentTurn ?? p1Id,
        p1Id: p1Id,
        p2Id: p2Id,
        p1Name: p1Name,
        p2Name: p2Name,
      );
      emit(loaded);

      // Subscribe to live Firestore streams
      _roomSub = DraftService.subscribeToRoom(event.roomId, (r) {
        add(_PnPRoomUpdated(r));
      });
      _membersSub = DraftService.subscribeToMembers(event.roomId, (m) {
        add(_PnPMembersUpdated(m));
      });
    } catch (e) {
      emit(PnPError(e.toString()));
    }
  }

  // ── Room stream handler ───────────────────────────────────────────────────

  void _onRoomUpdated(_PnPRoomUpdated event, Emitter<PnPState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    final updatedRoom = event.room;
    final cardChanged = updatedRoom.currentCardId != prev.room.currentCardId;
    final turnChanged = updatedRoom.currentTurn != null &&
        updatedRoom.currentTurn != prev.room.currentTurn;

    // Resolve card from cache — zero extra reads
    final DraftCard? currentCard;
    if (cardChanged) {
      currentCard = updatedRoom.currentCardId != null
          ? cardCache[updatedRoom.currentCardId]
          : null;
    } else {
      currentCard = prev.currentCard;
    }

    final newLoaded = prev.copyWith(
      room: updatedRoom,
      currentCard: currentCard,
      clearCurrentCard: updatedRoom.currentCardId == null,
      countdownSeconds: updatedRoom.secondsRemaining.clamp(0, 30),
    );

    // ── Game finished ──────────────────────────────────────────────────────
    if (updatedRoom.isFinished && !prev.room.isFinished) {
      _stopTimer();
      emit(newLoaded.copyWith(phase: 'result'));
      return;
    }

    // ── Turn advanced → show pass-the-phone screen ─────────────────────────
    if (turnChanged) {
      _stopTimer();
      emit(newLoaded.copyWith(
        phase: 'pass',
        currentPlayerId: updatedRoom.currentTurn!,
      ));
      return;
    }

    // ── New card drawn (same turn, card changed) ───────────────────────────
    if (cardChanged && updatedRoom.currentCardId != null) {
      emit(PnPHapticFeedback(newLoaded));
    }
    emit(newLoaded);
  }

  // ── Members stream handler ────────────────────────────────────────────────

  Future<void> _onMembersUpdated(
      _PnPMembersUpdated event, Emitter<PnPState> emit) async {
    final prev = _loaded;
    if (prev == null) return;

    final p1m = event.members.cast<DraftMember?>().firstWhere(
        (m) => m!.userId == p1Id, orElse: () => prev.p1Member);
    final p2m = event.members.cast<DraftMember?>().firstWhere(
        (m) => m!.userId == p2Id, orElse: () => prev.p2Member);

    emit(prev.copyWith(p1Member: p1m, p2Member: p2m));

    // Finalise if both boards full
    if (p1m != null &&
        p2m != null &&
        p1m.isBoardFull &&
        p2m.isBoardFull &&
        !prev.room.isFinished) {
      // Compute scores from board + cardCache (never stored in Firestore)
      final scores = <String, double>{
        for (final m in event.members)
          m.userId: m.board.values
              .whereType<String>()
              .map((id) => cardCache[id]?.level ?? 0.0)
              .fold(0.0, (sum, lvl) => sum + lvl),
      };
      await DraftService.checkAndFinaliseIfDone(
        roomId:       prev.room.id,
        members:      event.members,
        room:         prev.room,
        memberScores: scores,
      );
    }
  }

  // ── Countdown tick ────────────────────────────────────────────────────────

  void _onCountdownTicked(_PnPCountdownTicked event, Emitter<PnPState> emit) {
    final prev = _loaded;
    if (prev == null || prev.phase != 'play') return;
    emit(prev.copyWith(countdownSeconds: event.seconds));
    if (event.seconds <= 0) add(PnPAutoAssign());
  }

  // ── Pass confirmed ────────────────────────────────────────────────────────

  void _onPassConfirmed(PnPPassConfirmed event, Emitter<PnPState> emit) {
    final prev = _loaded;
    if (prev == null || prev.phase != 'pass') return;
    emit(prev.copyWith(phase: 'play'));
    _startCountdown();
  }

  // ── Card assigned / Skip / Auto-assign ──────────────────────────────────
  // These actions are now handled locally by GameplayScreen (which manages
  // the P&P game state in-memory and writes only the sync payload to
  // Firestore via pnpSyncBoard / pnpFinishGame). PnPBloc is kept as a
  // spectator-friendly room observer; it does not issue game writes.

  Future<void> _onCardAssigned(
      PnPCardAssigned event, Emitter<PnPState> emit) async {}

  Future<void> _onSkip(
      PnPSkipRequested event, Emitter<PnPState> emit) async {}

  Future<void> _onAutoAssign(
      PnPAutoAssign event, Emitter<PnPState> emit) async {}

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final prev = _loaded;
      if (prev == null) return;
      final remaining = prev.room.secondsRemaining.clamp(0, 30);
      add(_PnPCountdownTicked(remaining));
    });
  }

  void _stopTimer() => _countdownTimer?.cancel();

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _stopTimer();
    return super.close();
  }
}
