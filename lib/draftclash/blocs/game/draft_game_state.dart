part of 'draft_game_bloc.dart';

abstract class DraftGameState extends Equatable {
  const DraftGameState();
  @override
  List<Object?> get props => [];
}

class DraftGameLoading extends DraftGameState {}

class DraftGameLoaded extends DraftGameState {
  final DraftRoom          room;
  final DraftMember?       myMember;
  final List<DraftMember>  allMembers;
  final DraftCard?         currentCard;
  final int                countdownSeconds;
  final bool               isAssigning;
  final Map<String, DraftCard> cardCache;
  final List<SlotRole>     slots;

  const DraftGameLoaded({
    required this.room,
    required this.myMember,
    required this.allMembers,
    this.currentCard,
    this.countdownSeconds = 15,
    this.isAssigning = false,
    this.cardCache = const {},
    this.slots = const [],
  });

  // ── Score computation (never stored in Firestore) ──────────────────────────

  /// Computes a member's score from their board + the card catalogue.
  /// This replaces the old stored total_score field.
  double computeScore(DraftMember member) {
    double total = 0;
    for (final slot in slots) {
      final cardId = member.board[slot.key];
      if (cardId == null) continue;
      final level = cardCache[cardId]?.level ?? 0.0;
      total += slot.isDecrement ? -level : level;
    }
    for (final other in allMembers.where((m) => m.userId != member.userId)) {
      for (final slot in slots.where((s) => s.isDecrement)) {
        final cardId = other.board[slot.key];
        if (cardId != null) total += cardCache[cardId]?.level ?? 0.0;
      }
    }
    return total;
  }

  double get myScore       => myMember != null ? computeScore(myMember!) : 0.0;
  double get opponentScore => opponentMember != null ? computeScore(opponentMember!) : 0.0;

  /// uid → computed score for every member in the room.
  Map<String, double> get memberScores => {
    for (final m in allMembers) m.userId: computeScore(m),
  };

  // ── Convenience helpers ────────────────────────────────────────────────────

  DraftMember? get opponentMember => allMembers.cast<DraftMember?>().firstWhere(
    (m) => m!.userId != myMember?.userId,
    orElse: () => null,
  );

  bool get isMyTurn   => room.currentTurn == myMember?.userId;
  bool get mySkipUsed => myMember != null && room.hasUsedSkip(myMember!.userId);

  DraftGameLoaded copyWith({
    DraftRoom?            room,
    DraftMember?          myMember,
    List<DraftMember>?    allMembers,
    DraftCard?            currentCard,
    bool                  clearCurrentCard = false,
    int?                  countdownSeconds,
    bool?                 isAssigning,
    Map<String, DraftCard>? cardCache,
    List<SlotRole>?       slots,
  }) {
    return DraftGameLoaded(
      room:             room             ?? this.room,
      myMember:         myMember         ?? this.myMember,
      allMembers:       allMembers       ?? this.allMembers,
      currentCard:      clearCurrentCard ? null : (currentCard ?? this.currentCard),
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isAssigning:      isAssigning      ?? this.isAssigning,
      cardCache:        cardCache        ?? this.cardCache,
      slots:            slots            ?? this.slots,
    );
  }

  @override
  List<Object?> get props => [
    room, myMember, allMembers, currentCard,
    countdownSeconds, isAssigning, cardCache, slots,
  ];
}

/// Side-effect: triggers haptic feedback when the turn advances.
class DraftGameHapticFeedback extends DraftGameState {
  final DraftGameLoaded loaded;
  const DraftGameHapticFeedback(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

/// Game finished — show result overlay.
class DraftGameShowResult extends DraftGameState {
  final DraftGameLoaded loaded;
  const DraftGameShowResult(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class DraftGameError extends DraftGameState {
  final String message;
  const DraftGameError(this.message);
  @override
  List<Object?> get props => [message];
}
