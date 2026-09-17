// lib/tambola/services/room_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/room.dart';
import '../models/ticket_model.dart';
import '../../services/auth_service.dart';

class RoomService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── FIRESTORE STRUCTURE ─────────────────────────────────────────────────
  //
  //  profiles/{uid}                ← top-level (owned by AuthService)
  //  fun_games/stats               ← top-level app stats (owned by AuthService)
  //  tambola/app_data
  //      ├── rooms/                ← subcollection
  //      └── room_members/         ← subcollection
  //
  // ─────────────────────────────────────────────────────────────────────────

  /// Root document for Tambola-specific data
  static DocumentReference get _appData =>
      _db.collection('tambola').doc('app_data');

  static CollectionReference get _rooms =>
      _appData.collection('rooms');

  static CollectionReference get _roomMembers =>
      _appData.collection('room_members');

  // ─── STATS HELPERS ───────────────────────────────────────────────────────

  /// Increments a Tambola-specific counter on app_data.
  static Future<void> _incrementStat(String field, int delta) async {
    await _appData.set({
      field: FieldValue.increment(delta),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── USERNAME LOOKUP ─────────────────────────────────────────────────────

  /// Delegates to AuthService which owns the profiles collection.
  static Future<String> _getUsername(String uid) =>
      AuthService.getUsername(uid);

  // ─── ROOMS ──────────────────────────────────────────────────────────────

  /// Live stream of all rooms combined with the current user's membership set.
  /// Uses rxdart CombineLatest to merge two Firestore streams into one list,
  /// avoiding any sequential per-room fetches.
  static Stream<List<Room>> watchRooms() {
    final currentUid = _auth.currentUser?.uid;

    final roomsStream = _rooms
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(Room.fromFirestore).toList());

    // Stream of room IDs the current user has joined
    final membershipStream = currentUid != null
        ? _roomMembers
            .where('user_id', isEqualTo: currentUid)
            .snapshots()
            .map((snap) => snap.docs
                .map((d) =>
                    (d.data() as Map<String, dynamic>)['room_id'] as String)
                .toSet())
        : Stream.value(<String>{});

    return Rx.combineLatest2<List<Room>, Set<String>, List<Room>>(
      roomsStream,
      membershipStream,
      (rooms, joinedIds) {
        for (final room in rooms) {
          room.isCurrentUserMember = joinedIds.contains(room.id);
          // memberCount is stored directly on the room document (updated
          // by joinRoom / deleteRoom), so no extra query needed here.
        }
        return rooms;
      },
    );
  }

  static Future<Room?> createRoom({
    required String name,
    required int maxNumber,
    String? password,
    bool autoCall = false,
    int autoCallInterval = 5,
    bool suggestionMode = false,
    bool soundEnabled = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final username = await _getUsername(user.uid);

    final roomCode = _generateRoomCode();

    final docRef = await _rooms.add({
      'name': name,
      'host_id': user.uid,
      'host_username': username,
      'password': (password?.isNotEmpty == true) ? password : null,
      'max_number': maxNumber,
      'status': 'waiting',
      'called_numbers': [],
      'last_called': null,
      'auto_call': autoCall,
      'auto_call_interval': autoCallInterval,
      'suggestion_mode': suggestionMode,
      'sound_enabled': soundEnabled,
      'winner_id': null,
      'winner_username': null,
      'room_code': roomCode,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Increment total_rooms counter on app_data
    await _incrementStat('total_rooms', 1);

    // Auto-join the host as a member so they get their own ticket
    final ticket = TicketGenerator.generate(maxNumber);
    await _roomMembers.add({
      'room_id': docRef.id,
      'user_id': user.uid,
      'username': username,
      'ticket': TicketGenerator.toJson(ticket),
      'marked_numbers': [],
      'has_claimed_housie': false,
      'joined_at': FieldValue.serverTimestamp(),
    });
    // Set initial member_count to 1 (the host)
    await docRef.update({'member_count': 1});

    final doc = await docRef.get();
    return Room.fromFirestore(doc);
  }

  /// Generates a unique 6-digit room code.
  static String _generateRoomCode() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString();
  }

  /// Finds a room by its 6-digit code.
  static Future<Room?> getRoomByCode(String code) async {
    final snap = await _rooms
        .where('room_code', isEqualTo: code.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final room = Room.fromFirestore(snap.docs.first);
    try {
      final countSnap = await _roomMembers
          .where('room_id', isEqualTo: room.id)
          .count()
          .get();
      room.memberCount = countSnap.count ?? 0;
    } catch (_) {}
    return room;
  }

  static Future<bool> verifyPassword(String roomId, String password) async {
    final doc = await _rooms.doc(roomId).get();
    final storedPassword =
        (doc.data() as Map<String, dynamic>?)?['password'] as String?;
    if (storedPassword == null) return true;
    return storedPassword == password;
  }

  static Future<Room?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return Room.fromFirestore(doc);
  }

  // ─── MEMBERS ────────────────────────────────────────────────────────────

  static Future<RoomMember?> joinRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Check if already a member
    final existingSnap = await _roomMembers
        .where('room_id', isEqualTo: roomId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      return RoomMember.fromFirestore(existingSnap.docs.first);
    }

    final room = await getRoom(roomId);
    if (room == null) return null;

    final username = await _getUsername(user.uid);
    final ticket = TicketGenerator.generate(room.maxNumber);

    final docRef = await _roomMembers.add({
      'room_id': roomId,
      'user_id': user.uid,
      'username': username,
      'ticket': TicketGenerator.toJson(ticket),
      'marked_numbers': [],
      'has_claimed_housie': false,
      'joined_at': FieldValue.serverTimestamp(),
    });

    // Keep member_count on the room doc in sync so watchRooms needs no query
    await _rooms.doc(roomId).update({
      'member_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return RoomMember.fromFirestore(doc);
  }

  static Future<List<RoomMember>> getMembers(String roomId) async {
    final snap = await _roomMembers
        .where('room_id', isEqualTo: roomId)
        .get();

    return snap.docs.map((doc) => RoomMember.fromFirestore(doc)).toList();
  }

  static Future<RoomMember?> getMyMembership(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _roomMembers
        .where('room_id', isEqualTo: roomId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return RoomMember.fromFirestore(snap.docs.first);
  }

  // ─── GAME ACTIONS ────────────────────────────────────────────────────────

  /// Host updates live-editable room settings mid-game.
  static Future<void> updateRoomSettings(String roomId, {
    bool? autoCall,
    int? autoCallInterval,
    bool? suggestionMode,
    bool? soundEnabled,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (autoCall != null) updates['auto_call'] = autoCall;
    if (autoCallInterval != null) updates['auto_call_interval'] = autoCallInterval;
    if (suggestionMode != null) updates['suggestion_mode'] = suggestionMode;
    if (soundEnabled != null) updates['sound_enabled'] = soundEnabled;
    await _rooms.doc(roomId).update(updates);
  }

  static Future<void> startGame(String roomId) async {
    await _rooms.doc(roomId).update({
      'status': 'playing',
      'is_paused': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setPaused(String roomId, {required bool paused}) async {
    await _rooms.doc(roomId).update({
      'is_paused': paused,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<int?> callNextNumber(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null) return null;

    final called = List<int>.from(room.calledNumbers);
    final allNumbers = List.generate(room.maxNumber, (i) => i + 1);
    final remaining = allNumbers.where((n) => !called.contains(n)).toList();

    if (remaining.isEmpty) {
      await _rooms.doc(roomId).update({
        'status': 'finished',
        'updated_at': FieldValue.serverTimestamp(),
      });
      return null;
    }

    remaining.shuffle();
    final next = remaining.first;
    called.add(next);

    await _rooms.doc(roomId).update({
      'called_numbers': called,
      'last_called': next,
      'updated_at': FieldValue.serverTimestamp(),
    });

    return next;
  }

  static Future<void> markNumber(String roomId, int number) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final member = await getMyMembership(roomId);
    if (member == null) return;

    final marked = List<int>.from(member.markedNumbers);
    if (!marked.contains(number)) {
      marked.add(number);
      await _roomMembers.doc(member.id).update({
        'marked_numbers': marked,
      });
    }
  }

  static Future<bool> claimHousie(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final member = await getMyMembership(roomId);
    final room = await getRoom(roomId);
    if (member == null || room == null) return false;

    final isValid =
        TicketGenerator.isFullHouse(member.ticket, room.calledNumbers);
    if (!isValid) return false;

    final username = await _getUsername(user.uid);

    await _rooms.doc(roomId).update({
      'status': 'finished',
      'winner_id': user.uid,
      'winner_username': username,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _roomMembers.doc(member.id).update({
      'has_claimed_housie': true,
    });

    // Increment total_games_finished on app_data
    await _incrementStat('total_games_finished', 1);

    return true;
  }

  static Future<void> deleteRoom(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null) return;

    // If game was waiting (never started), delete it entirely
    if (room.isWaiting) {
      final membersSnap = await _roomMembers
          .where('room_id', isEqualTo: roomId)
          .get();
      final batch = _db.batch();
      for (final doc in membersSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_rooms.doc(roomId));
      await batch.commit();
      await _incrementStat('total_rooms', -1);
    } else {
      // If game was playing, mark as cancelled so it appears in Finished tab
      await _rooms.doc(roomId).update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── REAL-TIME (Firestore onSnapshot) ───────────────────────────────────

  static StreamSubscription<DocumentSnapshot> subscribeToRoom(
    String roomId,
    void Function(Room) onRoomUpdate,
  ) {
    return _rooms.doc(roomId).snapshots().listen((doc) {
      if (doc.exists) {
        onRoomUpdate(Room.fromFirestore(doc));
      }
    });
  }

  static StreamSubscription<QuerySnapshot> subscribeToMembers(
    String roomId,
    void Function(List<RoomMember>) onMembersUpdate,
  ) {
    return _roomMembers
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .listen((snap) {
      final members =
          snap.docs.map((doc) => RoomMember.fromFirestore(doc)).toList();
      onMembersUpdate(members);
    });
  }

  // ─── APP STATS (optional, for dashboard/admin use) ───────────────────────

  /// Returns a stream of the app_data document for live stats
  static Stream<Map<String, dynamic>> watchAppStats() {
    return _appData.snapshots().map((doc) {
      if (!doc.exists) return {};
      return (doc.data() as Map<String, dynamic>?) ?? {};
    });
  }
}
