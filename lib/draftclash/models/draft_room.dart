// lib/draftclash/models/draft_room.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'slot_role.dart';

/// A DraftClash room.
///
/// Players are stored as parallel lists — no hardcoded player1/player2.
/// Scores are NOT stored in Firestore; they are computed from member boards
/// + cardCache inside the BLoC.
class DraftRoom {
  final String id;
  final String code;
  final String status; // waiting | drafting | finished | no_cards

  // ── Players (list — no player1/player2 concept) ───────────────────────────
  final List<String> playerIds;       // [hostUid, guestUid?]
  final List<String> playerUsernames; // parallel list of display names

  // ── Live game state ───────────────────────────────────────────────────────
  final String?          currentTurn;   // uid of the player whose turn it is
  final String?          currentCardId; // card on the table — spectators read this
  final int              turnNumber;    // index into the local deck
  final int              deckSeed;      // both clients build the same deck from this
  final Map<String, bool> skipsUsed;   // uid → hasUsedSkip
  final DateTime?        turnDeadline;

  // ── Result ────────────────────────────────────────────────────────────────
  final String? winnerId;
  final String? winnerUsername;

  // ── Metadata ──────────────────────────────────────────────────────────────
  final DateTime      createdAt;
  final String?       franchise;    // legacy single-franchise filter
  final List<String>? franchises;  // multi-franchise filter (preferred)
  final String?       password;
  final bool          isPublic;
  final String?       roomName;
  final bool          isPassAndPlay;
  final List<SlotRole> slots;

  const DraftRoom({
    required this.id,
    required this.code,
    required this.status,
    required this.playerIds,
    required this.playerUsernames,
    this.currentTurn,
    this.currentCardId,
    this.turnNumber = 0,
    this.deckSeed = 0,
    required this.skipsUsed,
    this.turnDeadline,
    this.winnerId,
    this.winnerUsername,
    required this.createdAt,
    this.franchise,
    this.franchises,
    this.password,
    this.isPublic = true,
    this.roomName,
    this.isPassAndPlay = false,
    this.slots = const [],
  });

  factory DraftRoom.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DraftRoom(
      id:               doc.id,
      code:             d['code']    as String? ?? '',
      status:           d['status']  as String? ?? 'waiting',
      playerIds:        d['player_ids'] != null
          ? List<String>.from(d['player_ids'] as List)
          : _legacyPlayerIds(d),
      playerUsernames:  d['player_usernames'] != null
          ? List<String>.from(d['player_usernames'] as List)
          : _legacyPlayerUsernames(d),
      currentTurn:      d['current_turn']    as String?,
      currentCardId:    d['current_card_id'] as String?,
      turnNumber:       (d['turn_number']    as num?)?.toInt() ?? 0,
      deckSeed:         (d['deck_seed']      as num?)?.toInt() ?? 0,
      skipsUsed:        d['skips_used'] != null
          ? Map<String, bool>.from(d['skips_used'] as Map)
          : {},
      turnDeadline:     d['turn_deadline'] != null
          ? (d['turn_deadline'] as Timestamp).toDate()
          : null,
      winnerId:         d['winner_id']       as String?,
      winnerUsername:   d['winner_username'] as String?,
      createdAt:        d['created_at'] != null
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      franchise:        d['franchise']  as String?,
      franchises:       d['franchises'] != null
          ? List<String>.from(d['franchises'] as List)
          : null,
      password:         d['password']   as String?,
      isPublic:         d['is_public']  as bool? ?? true,
      roomName:         d['room_name']  as String?,
      isPassAndPlay:    d['is_pass_and_play'] as bool? ?? false,
      slots:            _roomSlots(d),
    );
  }

  static List<SlotRole> _roomSlots(Map<String, dynamic> d) {
    final raw = d['slots'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((slot) => SlotRole.fromMap(Map<String, dynamic>.from(slot)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // ── Backward-compat helpers for old player1_id / player2_id docs ──────────

  static List<String> _legacyPlayerIds(Map<String, dynamic> d) {
    final p1 = d['player1_id'] as String?;
    final p2 = d['player2_id'] as String?;
    return [if (p1 != null) p1, if (p2 != null) p2];
  }

  static List<String> _legacyPlayerUsernames(Map<String, dynamic> d) {
    final p1 = d['player1_username'] as String?;
    final p2 = d['player2_username'] as String?;
    return [if (p1 != null) p1, if (p2 != null) p2];
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  /// The room host (first player who created the room).
  String? get hostId       => playerIds.isNotEmpty       ? playerIds.first       : null;
  String? get hostUsername => playerUsernames.isNotEmpty ? playerUsernames.first : null;

  bool get isFull => playerIds.length >= 2;

  /// True when [uid] is any participant (host or guest).
  bool isPlayer(String uid) => playerIds.contains(uid);

  /// True when [uid] is specifically the host.
  bool isHost(String uid) => playerIds.isNotEmpty && playerIds.first == uid;

  bool hasUsedSkip(String uid) => skipsUsed[uid] == true;

  // ── Status ────────────────────────────────────────────────────────────────

  bool get isWaiting  => status == 'waiting';
  bool get isDrafting => status == 'drafting';
  bool get isFinished => status == 'finished';
  bool get hasPassword => password != null && password!.isNotEmpty;
  List<SlotRole> get effectiveSlots =>
      slots.isNotEmpty ? slots : SlotRole.defaults;

  int get secondsRemaining {
    if (turnDeadline == null) return -1;
    return turnDeadline!.difference(DateTime.now()).inSeconds;
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  DraftRoom copyWith({
    String?            status,
    List<String>?      playerIds,
    List<String>?      playerUsernames,
    String?            currentTurn,
    String?            currentCardId,
    bool               clearCurrentCard = false,
    int?               turnNumber,
    int?               deckSeed,
    Map<String, bool>? skipsUsed,
    DateTime?          turnDeadline,
    bool               clearDeadline = false,
    String?            winnerId,
    String?            winnerUsername,
  }) {
    return DraftRoom(
      id:               id,
      code:             code,
      status:           status           ?? this.status,
      playerIds:        playerIds        ?? this.playerIds,
      playerUsernames:  playerUsernames  ?? this.playerUsernames,
      currentTurn:      currentTurn      ?? this.currentTurn,
      currentCardId:    clearCurrentCard ? null : (currentCardId ?? this.currentCardId),
      turnNumber:       turnNumber       ?? this.turnNumber,
      deckSeed:         deckSeed         ?? this.deckSeed,
      skipsUsed:        skipsUsed        ?? this.skipsUsed,
      turnDeadline:     clearDeadline    ? null : (turnDeadline ?? this.turnDeadline),
      winnerId:         winnerId         ?? this.winnerId,
      winnerUsername:   winnerUsername   ?? this.winnerUsername,
      createdAt:        createdAt,
      franchise:        franchise,
      franchises:       franchises,
      password:         password,
      isPublic:         isPublic,
      roomName:         roomName,
      isPassAndPlay:    isPassAndPlay,
      slots:            slots,
    );
  }
}
