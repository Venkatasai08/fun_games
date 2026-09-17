// lib/cardroomgame/models/card_room_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'card_model.dart';

enum HostMode { player, spectator }

// ─────────────────────────────────────────────────────────────────────────────
// CardRoom  –  the room/session document stored in Firestore
// ─────────────────────────────────────────────────────────────────────────────

class CardRoom {
  final String id;
  final String name;
  final String hostId;
  final String hostUsername;
  final int maxPlayers;
  final int cardsPerPlayer;
  final HostMode hostMode;
  final String status; // waiting | playing | finished | cancelled
  final String roomCode;
  final List<TableCard> tableCards;
  final List<PlayingCard> remainingDeck; // cards not yet dealt or grabbed
  final DateTime createdAt;
  int memberCount;

  CardRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostUsername,
    required this.maxPlayers,
    required this.cardsPerPlayer,
    required this.hostMode,
    required this.status,
    required this.roomCode,
    required this.tableCards,
    this.remainingDeck = const [],
    required this.createdAt,
    this.memberCount = 0,
  });

  // ── Convenience booleans ───────────────────────────────────────────────

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';

  // ── Firestore ──────────────────────────────────────────────────────────

  factory CardRoom.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CardRoom(
      id: doc.id,
      name: map['name'] as String? ?? 'Room',
      hostId: map['host_id'] as String,
      hostUsername: map['host_username'] as String? ?? 'Unknown',
      maxPlayers: map['max_players'] as int? ?? 4,
      cardsPerPlayer: map['cards_per_player'] as int? ?? 13,
      hostMode: HostMode.values.byName(map['host_mode'] as String? ?? 'player'),
      status: map['status'] as String? ?? 'waiting',
      roomCode: map['room_code'] as String? ?? '',
      tableCards: (map['table_cards'] as List<dynamic>?)
              ?.map((e) => TableCard.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      remainingDeck: (map['remaining_deck'] as List<dynamic>?)
              ?.map((e) => PlayingCard.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt:
          (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: map['member_count'] as int? ?? 0,
    );
  }

  CardRoom copyWith({
    String? status,
    List<TableCard>? tableCards,
    List<PlayingCard>? remainingDeck,
    int? memberCount,
  }) =>
      CardRoom(
        id: id,
        name: name,
        hostId: hostId,
        hostUsername: hostUsername,
        maxPlayers: maxPlayers,
        cardsPerPlayer: cardsPerPlayer,
        hostMode: hostMode,
        status: status ?? this.status,
        roomCode: roomCode,
        tableCards: tableCards ?? this.tableCards,
        remainingDeck: remainingDeck ?? this.remainingDeck,
        createdAt: createdAt,
        memberCount: memberCount ?? this.memberCount,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TableCard  –  a card that has been placed on the shared table area
// ─────────────────────────────────────────────────────────────────────────────

class TableCard {
  final PlayingCard card;
  final String placedByUserId;
  final String placedByUsername;
  final DateTime placedAt;

  const TableCard({
    required this.card,
    required this.placedByUserId,
    required this.placedByUsername,
    required this.placedAt,
  });

  Map<String, dynamic> toMap() => {
        'card': card.toMap(),
        'placed_by_user_id': placedByUserId,
        'placed_by_username': placedByUsername,
        'placed_at': placedAt.millisecondsSinceEpoch,
      };

  factory TableCard.fromMap(Map<String, dynamic> map) => TableCard(
        card: PlayingCard.fromMap(map['card'] as Map<String, dynamic>),
        placedByUserId: map['placed_by_user_id'] as String? ?? '',
        placedByUsername: map['placed_by_username'] as String? ?? 'Unknown',
        placedAt: map['placed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['placed_at'] as int)
            : DateTime.now(),
      );
}
