// lib/draftclash/blocs/game/draft_game_bloc.dart
//
// DraftGameBloc — single source of truth for an active DraftClash game.
//
// Card loading strategy:
//   • [preloadedCards] is passed in from DraftCatalogCubit (fetched once on
//     DraftClash entry). When provided, _onInit filters them locally instead of
//     hitting Firebase again — zero extra Firestore reads for cards.
//   • If [preloadedCards] is empty (fallback / edge case), the old
//     DraftService.getAllCards() path is used so nothing breaks.
//
// Deck management (no Firestore reads/writes for the deck):
//   • buildDeck(allCards, room.deckSeed) → _localDeck (List<String>)
//   • currentCard = cardCache[_localDeck[room.turnNumber]]  (pure local lookup)
//   • nextCardId  = _localDeck[room.turnNumber + 1] (or null)
//   • Only nextCardId + nextTurnNumber are written to Firestore per move.
//
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/draft_card.dart';
import '../../models/draft_member.dart';
import '../../models/draft_room.dart';
import '../../models/slot_role.dart';
import '../../services/draft_service.dart';

part 'draft_game_event.dart';
part 'draft_game_state.dart';

class DraftGameBloc extends Bloc<DraftGameEvent, DraftGameState> {
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  /// When true all write actions are no-ops — used by the spectator screen.
  final bool isSpectator;

  /// Cards pre-fetched by DraftCatalogCubit. When non-empty, _onInit filters
  /// locally and skips the DraftService.getAllCards() Firestore call entirely.
  final List<DraftCard> _preloadedCards;

  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _membersSub;
  Timer?                       _countdownTimer;

  /// The deterministic card ID sequence for this game.
  /// Built once in _onInit from the card catalogue + room.deckSeed.
  List<String> _localDeck = [];

  DraftGameBloc({
    this.isSpectator = false,
    List<DraftCard>? preloadedCards,
  })  : _preloadedCards = preloadedCards ?? [],
        super(DraftGameLoading()) {
    on<DraftGameInitialized>(_onInit);
    on<DraftGameRoomUpdated>(_onRoomUpdated);
    on<DraftGameMembersUpdated>(_onMembersUpdated);
    on<DraftGameCountdownTicked>(_onCountdownTicked);
    on<DraftGameCardAssigned>(_onCardAssigned);
    on<DraftGameSkipRequested>(_onSkip);
    on<DraftGameAutoAssign>(_onAutoAssign);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DraftGameLoaded? get _loaded {
    final s = state;
    if (s is DraftGameLoaded)         return s;
    if (s is DraftGameHapticFeedback) return s.loaded;
    if (s is DraftGameShowResult)     return s.loaded;
    return null;
  }

  bool get isMyTurn => _loaded?.room.currentTurn == _userId;

  String? _deckCardAt(int index) =>
      (index >= 0 && index < _localDeck.length) ? _localDeck[index] : null;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _onInit(
      DraftGameInitialized event, Emitter<DraftGameState> emit) async {
    emit(DraftGameLoading());
    try {
      final room = await DraftService.getRoom(event.roomId);
      if (room == null) { emit(const DraftGameError('Room not found.')); return; }

      final slots = room.effectiveSlots;
      final myMemberFuture = DraftService.getMyMembership(
        event.roomId,
        slots: slots,
      );
      final membersFuture = DraftService.getMembers(
        event.roomId,
        slots: slots,
      );

      // ── Card loading ────────────────────────────────────────────────────
      //
      // FAST PATH: catalog is pre-loaded → filter locally, zero Firebase reads.
      // FALLBACK : catalog was empty (shouldn't happen in normal flow) → fetch.
      //
      final selected = room.franchises ??
          (room.franchise != null ? [room.franchise!] : null);

      final List<DraftCard> allCards;
      if (_preloadedCards.isNotEmpty) {
        // Filter the session cache by franchise — same logic as
        // DraftService.getAllCards so both clients get the identical card list
        // and therefore the identical deck after sort + shuffle with deckSeed.
        allCards = (selected == null || selected.isEmpty)
            ? _preloadedCards
            : _preloadedCards
                .where((c) => selected.contains(c.franchiseName))
                .toList();
      } else {
        // Fallback — fetch from Firestore (edge case: cubit not in tree).
        allCards = await DraftService.getAllCards(franchises: selected);
      }

      final myMember = await myMemberFuture;
      final members  = await membersFuture;

      final cardCache = <String, DraftCard>{for (final c in allCards) c.id: c};

      _localDeck = DraftService.buildDeck(allCards, room.deckSeed);

      final currentCard = cardCache[_deckCardAt(room.turnNumber)];

      final loaded = DraftGameLoaded(
        room:             room,
        myMember:         myMember,
        allMembers:       members,
        currentCard:      currentCard,
        countdownSeconds: room.secondsRemaining.clamp(0, DraftService.turnSeconds),
        cardCache:        cardCache,
        slots:            slots,
      );
      emit(loaded);

      _startCountdown();

      _roomSub    = DraftService.subscribeToRoom(event.roomId,
          (r) => add(DraftGameRoomUpdated(r)));
      _membersSub = DraftService.subscribeToMembers(
        event.roomId,
        (m) => add(DraftGameMembersUpdated(m)),
        slots: slots,
      );
    } catch (e) {
      emit(DraftGameError(e.toString()));
    }
  }

  // ── Room stream ───────────────────────────────────────────────────────────

  void _onRoomUpdated(DraftGameRoomUpdated event, Emitter<DraftGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;

    final updatedRoom = event.room;
    final turnChanged = updatedRoom.turnNumber != prev.room.turnNumber;

    final currentCard = turnChanged
        ? prev.cardCache[_deckCardAt(updatedRoom.turnNumber)]
        : (updatedRoom.currentCardId == null ? null : prev.currentCard);

    final newLoaded = prev.copyWith(
      room:             updatedRoom,
      currentCard:      currentCard,
      clearCurrentCard: updatedRoom.currentCardId == null,
      countdownSeconds: updatedRoom.secondsRemaining
          .clamp(0, DraftService.turnSeconds),
    );

    if (updatedRoom.isFinished && !prev.room.isFinished) {
      _stopTimer();
      emit(DraftGameShowResult(newLoaded));
      return;
    }

    if (turnChanged) {
      _startCountdown();
      emit(DraftGameHapticFeedback(newLoaded));
    }

    emit(newLoaded);
  }

  // ── Members stream ────────────────────────────────────────────────────────

  Future<void> _onMembersUpdated(
      DraftGameMembersUpdated event, Emitter<DraftGameState> emit) async {
    final prev = _loaded;
    if (prev == null) return;

    final myMember = event.members.cast<DraftMember?>().firstWhere(
      (m) => m!.userId == _userId,
      orElse: () => prev.myMember,
    );

    final updatedLoaded =
        prev.copyWith(allMembers: event.members, myMember: myMember);
    emit(updatedLoaded);

    if (event.members.length >= 2 &&
        event.members.every((m) => m.isBoardFullWith(prev.slots)) &&
        !prev.room.isFinished) {
      await DraftService.checkAndFinaliseIfDone(
        roomId:       prev.room.id,
        members:      event.members,
        room:         prev.room,
        memberScores: updatedLoaded.memberScores,
      );
    }
  }

  // ── Countdown ─────────────────────────────────────────────────────────────

  void _onCountdownTicked(
      DraftGameCountdownTicked event, Emitter<DraftGameState> emit) {
    final prev = _loaded;
    if (prev == null) return;
    emit(prev.copyWith(countdownSeconds: event.seconds));
    if (event.seconds <= 0 &&
        prev.room.currentTurn == _userId &&
        prev.myMember != null &&
        !prev.myMember!.isBoardFullWith(prev.slots)) {
      add(DraftGameAutoAssign());
    }
  }

  // ── Player actions ────────────────────────────────────────────────────────

  Future<void> _onCardAssigned(
      DraftGameCardAssigned event, Emitter<DraftGameState> emit) async {
    if (isSpectator) return;
    final prev = _loaded;
    if (prev == null || prev.myMember == null) return;
    if (prev.room.currentTurn != _userId)      return;
    if (prev.isAssigning)                      return;
    if (prev.currentCard == null)              return;

    emit(prev.copyWith(isAssigning: true));
    try {
      final nextTurn = prev.room.turnNumber + 1;
      await DraftService.assignCard(
        roomId:         prev.room.id,
        memberId:       prev.myMember!.id,
        slot:           event.slot,
        room:           prev.room,
        member:         prev.myMember!,
        cardLevel:      prev.currentCard!.level,
        nextCardId:     _deckCardAt(nextTurn),
        nextTurnNumber: nextTurn,
      );
      HapticFeedback.selectionClick();
    } catch (_) {}

    final cur = _loaded;
    if (cur != null && cur.isAssigning) emit(cur.copyWith(isAssigning: false));
  }

  Future<void> _onSkip(
      DraftGameSkipRequested event, Emitter<DraftGameState> emit) async {
    if (isSpectator) return;
    final prev = _loaded;
    if (prev == null)                     return;
    if (prev.room.hasUsedSkip(_userId))   return;
    if (prev.room.currentTurn != _userId) return;

    try {
      final nextTurn = prev.room.turnNumber + 1;
      await DraftService.skipCard(
        roomId:         prev.room.id,
        room:           prev.room,
        nextCardId:     _deckCardAt(nextTurn),
        nextTurnNumber: nextTurn,
      );
    } catch (_) {}
  }

  Future<void> _onAutoAssign(
      DraftGameAutoAssign event, Emitter<DraftGameState> emit) async {
    if (isSpectator) return;
    final prev = _loaded;
    if (prev == null || prev.myMember == null) return;
    if (prev.myMember!.isBoardFullWith(prev.slots)) return;
    if (prev.room.currentTurn != _userId)      return;
    if (prev.currentCard == null)              return;

    try {
      final nextTurn = prev.room.turnNumber + 1;
      await DraftService.autoAssign(
        roomId:         prev.room.id,
        room:           prev.room,
        member:         prev.myMember!,
        cardLevel:      prev.currentCard!.level,
        nextCardId:     _deckCardAt(nextTurn),
        nextTurnNumber: nextTurn,
      );
    } catch (_) {}
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final prev = _loaded;
      if (prev == null) return;
      final remaining =
          prev.room.secondsRemaining.clamp(0, DraftService.turnSeconds);
      add(DraftGameCountdownTicked(remaining));
    });
  }

  void _stopTimer() => _countdownTimer?.cancel();

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _stopTimer();
    return super.close();
  }
}
