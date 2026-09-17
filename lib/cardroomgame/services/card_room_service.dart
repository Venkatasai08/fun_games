// lib/cardroomgame/services/card_room_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';
import '../models/card_room_model.dart';
import '../models/card_player_model.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardRoomService
//
// Firestore structure:
//   card_room/app_data
//     └── rooms/{roomId}          ← room config + status + table_cards
//     └── room_members/{memberId} ← per-player hand & meta
// ─────────────────────────────────────────────────────────────────────────────

class CardRoomService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static DocumentReference get _appData =>
      _db.collection('card_room').doc('app_data');

  static CollectionReference get _rooms => _appData.collection('rooms');

  static CollectionReference get _roomMembers =>
      _appData.collection('room_members');

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<String> _getUsername(String uid) =>
      AuthService.getUsername(uid);

  static String _generateRoomCode() =>
      (100000 + Random().nextInt(900000)).toString();

  // ── Create ────────────────────────────────────────────────────────────────

  static Future<CardRoom?> createRoom({
    required String name,
    required int maxPlayers,
    required int cardsPerPlayer,
    required HostMode hostMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final username = await _getUsername(user.uid);
    final roomCode = _generateRoomCode();

    final docRef = await _rooms.add({
      'name': name,
      'host_id': user.uid,
      'host_username': username,
      'max_players': maxPlayers,
      'cards_per_player': cardsPerPlayer,
      'host_mode': hostMode.name,
      'status': 'waiting',
      'room_code': roomCode,
      'table_cards': [],
      'member_count': 1,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Host auto-joins as a member
    await _roomMembers.add({
      'room_id': docRef.id,
      'user_id': user.uid,
      'username': username,
      'hand': [],
      'is_spectator': hostMode == HostMode.spectator,
      'is_ready': false,
      'joined_at': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return CardRoom.fromFirestore(doc);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  static Future<CardRoom?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return CardRoom.fromFirestore(doc);
  }

  static Future<CardRoom?> getRoomByCode(String code) async {
    final snap = await _rooms
        .where('room_code', isEqualTo: code.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CardRoom.fromFirestore(snap.docs.first);
  }

  static Stream<List<CardRoom>> watchRooms() {
    return _rooms
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(CardRoom.fromFirestore).toList());
  }

  // ── Join / Members ────────────────────────────────────────────────────────

  static Future<CardPlayer?> joinRoom(
    String roomId, {
    bool asSpectator = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Idempotent — return existing membership if already joined
    final existingSnap = await _roomMembers
        .where('room_id', isEqualTo: roomId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      return CardPlayer.fromFirestore(existingSnap.docs.first);
    }

    final username = await _getUsername(user.uid);

    final docRef = await _roomMembers.add({
      'room_id': roomId,
      'user_id': user.uid,
      'username': username,
      'hand': [],
      'is_spectator': asSpectator,
      'is_ready': false,
      'joined_at': FieldValue.serverTimestamp(),
    });

    await _rooms.doc(roomId).update({
      'member_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return CardPlayer.fromFirestore(doc);
  }

  static Future<CardPlayer?> getMyMembership(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _roomMembers
        .where('room_id', isEqualTo: roomId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return CardPlayer.fromFirestore(snap.docs.first);
  }

  static Future<List<CardPlayer>> getMembers(String roomId) async {
    final snap =
        await _roomMembers.where('room_id', isEqualTo: roomId).get();
    return snap.docs.map((d) => CardPlayer.fromFirestore(d)).toList();
  }

  // ── Game Flow ─────────────────────────────────────────────────────────────

  /// Host calls this — shuffles the deck and deals cards to each non-spectator.
  static Future<void> startGame(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null) return;

    final members = await getMembers(roomId);
    final players = members.where((m) => !m.isSpectator).toList();

    // Shuffle a standard 52-card deck
    final deck = PlayingCard.generateDeck()..shuffle(Random());

    final batch = _db.batch();

    int dealtCount = 0;
    for (int i = 0; i < players.length; i++) {
      final start = i * room.cardsPerPlayer;
      final end = (start + room.cardsPerPlayer).clamp(0, deck.length);
      if (start >= deck.length) break;
      final hand = deck.sublist(start, end);
      batch.update(_roomMembers.doc(players[i].id), {
        'hand': hand.map((c) => c.toMap()).toList(),
      });
      dealtCount = end;
    }

    // Cards beyond what was dealt form the remaining draw deck
    final remaining = dealtCount < deck.length
        ? deck.sublist(dealtCount)
        : <PlayingCard>[];

    batch.update(_rooms.doc(roomId), {
      'status': 'playing',
      'table_cards': [],
      'remaining_deck': remaining.map((c) => c.toMap()).toList(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Card Moves ────────────────────────────────────────────────────────────

  /// Player drags a card to the shared table (face-up or face-down).
  static Future<void> playCardToTable(
    String roomId,
    PlayingCard card, {
    bool faceUp = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final member = await getMyMembership(roomId);
    if (member == null) return;

    final username = await _getUsername(user.uid);
    final newHand =
        member.hand.where((c) => c.id != card.id).toList();

    final tableCard = TableCard(
      card: card.copyWith(faceUp: faceUp),
      placedByUserId: user.uid,
      placedByUsername: username,
      placedAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.update(_roomMembers.doc(member.id), {
      'hand': newHand.map((c) => c.toMap()).toList(),
    });
    batch.update(_rooms.doc(roomId), {
      'table_cards': FieldValue.arrayUnion([tableCard.toMap()]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Player drags a card directly to another player's hand.
  static Future<void> passCardToPlayer(
    String roomId,
    PlayingCard card,
    String targetUserId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final allMembers = await getMembers(roomId);
    final sender =
        allMembers.firstWhere((m) => m.userId == user.uid);
    final recipient =
        allMembers.firstWhere((m) => m.userId == targetUserId);

    final newSenderHand =
        sender.hand.where((c) => c.id != card.id).toList();
    final newRecipientHand = [
      ...recipient.hand,
      card.copyWith(faceUp: false),
    ];

    final batch = _db.batch();
    batch.update(_roomMembers.doc(sender.id), {
      'hand': newSenderHand.map((c) => c.toMap()).toList(),
    });
    batch.update(_roomMembers.doc(recipient.id), {
      'hand': newRecipientHand.map((c) => c.toMap()).toList(),
    });

    await batch.commit();
  }

  /// Host can clear all cards from the shared table.
  static Future<void> clearTable(String roomId) async {
    await _rooms.doc(roomId).update({
      'table_cards': [],
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Any player grabs a specific card from the remaining deck into their hand.
  static Future<void> grabCardFromDeck(
    String roomId,
    PlayingCard card,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final member = await getMyMembership(roomId);
    if (member == null) return;

    final newHand = [...member.hand, card.copyWith(faceUp: false)];

    final batch = _db.batch();
    batch.update(_roomMembers.doc(member.id), {
      'hand': newHand.map((c) => c.toMap()).toList(),
    });
    // Remove this specific card from the remaining deck
    batch.update(_rooms.doc(roomId), {
      'remaining_deck': FieldValue.arrayRemove([card.toMap()]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Host undoes the last card placed on the table (removes it from tableCards).
  static Future<void> undoLastTableCard(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null || room.tableCards.isEmpty) return;

    final updated = [...room.tableCards]..removeLast();
    await _rooms.doc(roomId).update({
      'table_cards': updated.map((tc) => tc.toMap()).toList(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Host ends the session gracefully (status → finished).
  static Future<void> endGame(String roomId) async {
    await _rooms.doc(roomId).update({
      'status': 'finished',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Host deletes a waiting room entirely, or marks a running room cancelled.
  static Future<void> deleteRoom(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null) return;

    if (room.isWaiting) {
      final membersSnap =
          await _roomMembers.where('room_id', isEqualTo: roomId).get();
      final batch = _db.batch();
      for (final doc in membersSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_rooms.doc(roomId));
      await batch.commit();
    } else {
      await _rooms.doc(roomId).update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Real-time subscriptions ───────────────────────────────────────────────

  static StreamSubscription<DocumentSnapshot> subscribeToRoom(
    String roomId,
    void Function(CardRoom) onUpdate,
  ) {
    return _rooms.doc(roomId).snapshots().listen((doc) {
      if (doc.exists) onUpdate(CardRoom.fromFirestore(doc));
    });
  }

  static StreamSubscription<QuerySnapshot> subscribeToMembers(
    String roomId,
    void Function(List<CardPlayer>) onUpdate,
  ) {
    return _roomMembers
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .listen((snap) {
      onUpdate(snap.docs.map((d) => CardPlayer.fromFirestore(d)).toList());
    });
  }
}
