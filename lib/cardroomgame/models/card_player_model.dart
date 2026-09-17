// lib/cardroomgame/models/card_player_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'card_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardPlayer  –  a member document stored under room_members subcollection
// ─────────────────────────────────────────────────────────────────────────────

class CardPlayer {
  final String id; // Firestore document id
  final String roomId;
  final String userId;
  final String username;
  final List<PlayingCard> hand;
  final bool isSpectator;
  final bool isReady;

  const CardPlayer({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.hand,
    this.isSpectator = false,
    this.isReady = false,
  });

  factory CardPlayer.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CardPlayer(
      id: doc.id,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String? ?? 'Unknown',
      hand: (map['hand'] as List<dynamic>?)
              ?.map((e) => PlayingCard.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSpectator: map['is_spectator'] as bool? ?? false,
      isReady: map['is_ready'] as bool? ?? false,
    );
  }

  CardPlayer copyWith({
    List<PlayingCard>? hand,
    bool? isReady,
  }) =>
      CardPlayer(
        id: id,
        roomId: roomId,
        userId: userId,
        username: username,
        hand: hand ?? this.hand,
        isSpectator: isSpectator,
        isReady: isReady ?? this.isReady,
      );
}
