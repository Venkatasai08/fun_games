part of 'pnp_bloc.dart';

abstract class PnPState extends Equatable {
  const PnPState();
  @override
  List<Object?> get props => [];
}

class PnPLoading extends PnPState {}

/// Main loaded state — drives the entire P&P game screen.
class PnPLoaded extends PnPState {
  final DraftRoom room;
  final DraftMember? p1Member;
  final DraftMember? p2Member;
  final DraftCard? currentCard;
  final Map<String, DraftCard> cardCache;
  final int countdownSeconds;
  final bool isAssigning;

  /// 'pass' → show the pass-the-phone interstitial
  /// 'play' → show the active board + timer
  /// 'result' → game is over, show result overlay
  final String phase;

  /// The UID of the player who is currently picking (P1 uid or P2 virtual uid).
  final String currentPlayerId;
  final String p1Id;
  final String p2Id;
  final String p1Name;
  final String p2Name;

  const PnPLoaded({
    required this.room,
    required this.p1Member,
    required this.p2Member,
    required this.currentCard,
    required this.cardCache,
    required this.countdownSeconds,
    required this.phase,
    required this.currentPlayerId,
    required this.p1Id,
    required this.p2Id,
    required this.p1Name,
    required this.p2Name,
    this.isAssigning = false,
  });

  bool get isP1Turn => currentPlayerId == p1Id;
  DraftMember? get currentMember  => isP1Turn ? p1Member : p2Member;
  DraftMember? get opponentMember => isP1Turn ? p2Member : p1Member;
  String get currentName  => isP1Turn ? p1Name : p2Name;
  String get opponentName => isP1Turn ? p2Name : p1Name;
  bool   get currentSkipUsed => room.hasUsedSkip(currentPlayerId);

  // ── Score helpers (computed from board + cardCache, never stored) ──────────
  double _scoreFor(DraftMember? m) => m == null ? 0.0 :
      m.board.values.whereType<String>()
          .map((id) => cardCache[id]?.level ?? 0.0)
          .fold(0.0, (s, l) => s + l);

  double get p1Score       => _scoreFor(p1Member);
  double get p2Score       => _scoreFor(p2Member);
  double get currentScore  => _scoreFor(currentMember);
  double get opponentScore => _scoreFor(opponentMember);

  PnPLoaded copyWith({
    DraftRoom? room,
    DraftMember? p1Member,
    DraftMember? p2Member,
    DraftCard? currentCard,
    bool clearCurrentCard = false,
    int? countdownSeconds,
    bool? isAssigning,
    String? phase,
    String? currentPlayerId,
  }) {
    return PnPLoaded(
      room: room ?? this.room,
      p1Member: p1Member ?? this.p1Member,
      p2Member: p2Member ?? this.p2Member,
      currentCard:
          clearCurrentCard ? null : (currentCard ?? this.currentCard),
      cardCache: cardCache,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isAssigning: isAssigning ?? this.isAssigning,
      phase: phase ?? this.phase,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      p1Id: p1Id,
      p2Id: p2Id,
      p1Name: p1Name,
      p2Name: p2Name,
    );
  }

  @override
  List<Object?> get props => [
        room,
        p1Member,
        p2Member,
        currentCard,
        countdownSeconds,
        isAssigning,
        phase,
        currentPlayerId,
      ];
}

/// Side-effect: triggers haptic feedback when a new card is revealed.
class PnPHapticFeedback extends PnPState {
  final PnPLoaded loaded;
  const PnPHapticFeedback(this.loaded);
  @override
  List<Object?> get props => [loaded];
}

class PnPError extends PnPState {
  final String message;
  const PnPError(this.message);
  @override
  List<Object?> get props => [message];
}
