// lib/draftclash/services/draft_service.dart
//
// What is stored in Firestore vs kept in memory:
//
// ROOM DOC — minimal live game state:
//   player_ids[], player_usernames[]  — list-based, no player1/player2 fields
//   status, current_turn, current_card_id
//   turn_number, deck_seed            — deck never stored; rebuilt locally
//   skips_used, turn_deadline
//   winner_id, winner_username        — set on game over
//   room metadata (code, room_name, franchise/s, password, is_public, etc.)
//
// NOT stored: deck[], scores — both computed locally from member boards + cardCache
//
// MEMBER DOC — board only:
//   room_id, user_id, username
//   board_<slot> fields               — slot.key → cardId (null = empty)
//
// NOT stored: total_score — computed from board + cardCache in BLoC state
//
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/board_slot.dart';
import '../models/draft_card.dart';
import '../models/draft_franchise.dart';
import '../models/draft_member.dart';
import '../models/draft_room.dart';
import '../models/franchise_category.dart';
import '../models/slot_role.dart';
export '../models/franchise_category.dart' show FranchiseCategory;
export '../models/slot_role.dart' show SlotRole, SlotEffect;
import '../../services/auth_service.dart';

class DraftService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const int turnSeconds  = 15; // public so BLoC can clamp countdown
  static const int _maxDeckSize = 50;

  // ── Refs ──────────────────────────────────────────────────────────────────

  static CollectionReference get _cards      => _db.collection('cards');
  static CollectionReference get _franchises => _db.collection('franchises');
  static CollectionReference get _slots      => _db.collection('draft_slots');
  static DocumentReference   get _appData    => _db.collection('draftclash').doc('app_data');
  static CollectionReference get _rooms      => _appData.collection('rooms');
  static CollectionReference get _members    => _appData.collection('room_members');

  static Future<String> _username() =>
      AuthService.getUsername(_auth.currentUser!.uid);

  // ── Slot roles ────────────────────────────────────────────────────────────

  /// Fetches all slot roles ordered by their display order.
  /// Returns defaults if the collection is empty.
  static Future<List<SlotRole>> getAllSlots() async {
    final snap = await _slots.orderBy('order').get();
    if (snap.docs.isEmpty) return SlotRole.defaults;
    return snap.docs.map(SlotRole.fromFirestore).toList();
  }

  /// Adds a slot. Returns the new Firestore ID.
  static Future<String> addSlot(SlotRole slot) async {
    final ref = await _slots.add(slot.toMap());
    return ref.id;
  }

  /// Updates an existing slot document.
  static Future<void> updateSlot(SlotRole slot) async {
    await _slots.doc(slot.id).update({
      'name':   slot.name,
      'key':    slot.key,
      'effect': slot.effect.name,
      'order':  slot.order,
    });
  }

  /// Deletes a slot document.
  static Future<void> deleteSlot(String slotId) async =>
      _slots.doc(slotId).delete();

  // ── Franchise catalogue ───────────────────────────────────────────────────

  static Future<List<DraftFranchise>> getAllFranchises() async {
    final snap = await _franchises.orderBy('name').get();
    return snap.docs.map(DraftFranchise.fromFirestore).toList();
  }

  static Stream<List<DraftFranchise>> watchFranchises() =>
      _franchises.orderBy('name').snapshots()
          .map((s) => s.docs.map(DraftFranchise.fromFirestore).toList());

  static Future<String> addFranchise({
    required String name,
    required String imageUrl,
    FranchiseCategory category = FranchiseCategory.other,
  }) async {
    final ref = await _franchises.add({
      'name':      name.trim(),
      'imageUrl':  imageUrl,
      'cardCount': 0,
      'category':  category.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> updateFranchise({
    required String id,
    required String name,
    required String imageUrl,
    required FranchiseCategory category,
  }) async {
    await _franchises.doc(id).update({
      'name':     name.trim(),
      'imageUrl': imageUrl,
      'category': category.name,
    });
  }

  static Future<void> deleteFranchise(String id) async =>
      _franchises.doc(id).delete();

  static Future<void> _incrementCardCount(String franchiseId) async =>
      _franchises.doc(franchiseId).update({'cardCount': FieldValue.increment(1)});

  // ── Card catalogue ────────────────────────────────────────────────────────

  static Future<List<String>> getFranchises() async {
    final snap = await _franchises.orderBy('name').get();
    return snap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static Future<List<DraftCard>> getAllCards({
    String?       franchise,  // legacy single-franchise
    List<String>? franchises, // multi-franchise filter
  }) async {
    final selected = franchises ?? (franchise != null ? [franchise] : []);
    Query q = _cards;
    if (selected.length == 1) {
      q = q.where('franchiseName', isEqualTo: selected.first);
    } else if (selected.length > 1) {
      q = q.where('franchiseName', whereIn: selected.take(30).toList());
    }
    final snap = await q.get();
    return snap.docs.map(DraftCard.fromFirestore).toList();
  }

  static Stream<List<DraftCard>> watchCards() =>
      _cards.snapshots().map((s) => s.docs.map(DraftCard.fromFirestore).toList());

  /// Writes the card to Firestore and returns it with the generated document ID.
  /// Return value is used by DraftCatalogCubit to insert into cached state.
  static Future<DraftCard> addCard(DraftCard card) async {
    final ref = await _cards.add(card.toMap());
    for (final id in card.franchiseIds) {
      if (id.isNotEmpty) await _incrementCardCount(id);
    }
    final doc = await ref.get();
    return DraftCard.fromFirestore(doc);
  }

  static Future<int> addCards(List<DraftCard> cards) async {
    if (cards.isEmpty) return 0;
    final Map<String, int> franchiseCounts = {};
    int saved = 0;
    const chunkSize = 400;
    for (int i = 0; i < cards.length; i += chunkSize) {
      final chunk = cards.sublist(i, (i + chunkSize).clamp(0, cards.length));
      final batch = _db.batch();
      for (final card in chunk) {
        batch.set(_cards.doc(), card.toMap());
        for (final id in card.franchiseIds) {
          if (id.isNotEmpty) franchiseCounts[id] = (franchiseCounts[id] ?? 0) + 1;
        }
        saved++;
      }
      await batch.commit();
    }
    for (final entry in franchiseCounts.entries) {
      await _franchises.doc(entry.key)
          .update({'cardCount': FieldValue.increment(entry.value)});
    }
    return saved;
  }

  static Future<void> updateCard(DraftCard card) async {
    final oldDoc  = await _cards.doc(card.id).get();
    final oldData = oldDoc.data() as Map<String, dynamic>?;
    List<String> oldIds;
    final rawOldIds = oldData?['franchiseIds'];
    if (rawOldIds is List && rawOldIds.isNotEmpty) {
      oldIds = rawOldIds.map((e) => e.toString()).toList();
    } else {
      final oldSingle = oldData?['franchiseId'] as String? ?? '';
      oldIds = oldSingle.isNotEmpty ? [oldSingle] : [];
    }
    await _cards.doc(card.id).update({
      'name':         card.name,
      'description':  card.description,
      'level':        card.level,
      'imageUrl':     card.imageUrl,
      'franchiseIds': card.franchiseIds,
    });
    final newIds  = card.franchiseIds;
    final added   = newIds.where((id) => !oldIds.contains(id));
    final removed = oldIds.where((id) => !newIds.contains(id));
    for (final id in added) {
      if (id.isNotEmpty)
        await _franchises.doc(id).update({'cardCount': FieldValue.increment(1)});
    }
    for (final id in removed) {
      if (id.isNotEmpty)
        await _franchises.doc(id).update({'cardCount': FieldValue.increment(-1)});
    }
  }

  static Future<void> deleteCard(DraftCard card) async {
    await _cards.doc(card.id).delete();
    for (final id in card.franchiseIds) {
      if (id.isNotEmpty)
        await _franchises.doc(id).update({'cardCount': FieldValue.increment(-1)});
    }
  }

  /// Deletes ALL cards whose [franchiseName] field matches [franchiseName].
  /// Also decrements the cardCount on every franchise linked via franchiseIds.
  /// Returns the number of cards deleted.
  static Future<int> deleteCardsForFranchise({
    required String franchiseName,
  }) async {
    final snap =
        await _cards.where('franchiseName', isEqualTo: franchiseName).get();
    if (snap.docs.isEmpty) return 0;

    // Tally how many cards reference each franchise so we can decrement counts.
    final Map<String, int> decrements = {};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final raw  = data['franchiseIds'];
      List<String> ids;
      if (raw is List && raw.isNotEmpty) {
        ids = raw.map((e) => e.toString()).toList();
      } else {
        final old = data['franchiseId'] as String? ?? '';
        ids = old.isNotEmpty ? [old] : [];
      }
      for (final id in ids) {
        if (id.isNotEmpty) decrements[id] = (decrements[id] ?? 0) + 1;
      }
    }

    // Batch-delete cards in chunks of 400 (Firestore batch limit).
    const chunkSize = 400;
    for (int i = 0; i < snap.docs.length; i += chunkSize) {
      final chunk =
          snap.docs.sublist(i, (i + chunkSize).clamp(0, snap.docs.length));
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Decrement cardCount on every affected franchise.
    for (final entry in decrements.entries) {
      await _franchises
          .doc(entry.key)
          .update({'cardCount': FieldValue.increment(-entry.value)});
    }

    return snap.docs.length;
  }

  // ── Room listing ──────────────────────────────────────────────────────────

  static Stream<List<DraftRoom>> watchRooms() {
    return _rooms
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(DraftRoom.fromFirestore).toList());
  }

  static Future<DraftRoom?> getRoomByCode(String code) async {
    final snap = await _rooms
        .where('code', isEqualTo: code.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DraftRoom.fromFirestore(snap.docs.first);
  }

  static Future<DraftRoom?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return DraftRoom.fromFirestore(doc);
  }

  // ── Room creation ─────────────────────────────────────────────────────────

  static Future<DraftRoom?> createRoom({
    String?       roomName,
    String?       franchise,
    List<String>? franchises,
    String?       password,
    List<SlotRole>? slots,
    bool          isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final username           = await _username();
    final code               = _generateCode();
    final selected           = franchises ?? (franchise != null ? [franchise] : null);
    final effectiveFranchise = selected?.length == 1 ? selected!.first : null;

    final docRef = await _rooms.add({
      'code':              code,
      'status':            'waiting',
      'player_ids':        [user.uid],
      'player_usernames':  [username],
      'current_turn':      null,
      'current_card_id':   null,
      'turn_number':       0,
      'deck_seed':         0,
      'skips_used':        {},
      'turn_deadline':     null,
      'winner_id':         null,
      'winner_username':   null,
      'created_at':        FieldValue.serverTimestamp(),
      'room_name':         roomName ?? '$username\'s Room',
      'franchise':         effectiveFranchise,
      'franchises':        selected,
      'password':          password,
      'is_public':         isPublic,
      'slots':             slots?.map((s) => s.toRoomMap()).toList(),
    });

    await _createMember(docRef.id, user.uid, username, slots: slots);
    final doc = await docRef.get();
    return DraftRoom.fromFirestore(doc);
  }

  // ── Room joining ──────────────────────────────────────────────────────────

  static Future<bool> verifyPassword(String roomId, String password) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return false;
    final stored = (doc.data() as Map<String, dynamic>)['password'] as String?;
    return stored == password;
  }

  static Future<DraftRoom?> joinRoomById(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc  = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;

    final room = DraftRoom.fromFirestore(doc);
    if (room.status != 'waiting')              return null;
    if (room.isPlayer(user.uid))               return room;
    if (room.isFull)                           return null;

    final username = await _username();

    await _rooms.doc(roomId).update({
      'player_ids':       FieldValue.arrayUnion([user.uid]),
      'player_usernames': FieldValue.arrayUnion([username]),
    });
    await _createMember(roomId, user.uid, username, slots: room.effectiveSlots);
    await _startDraft(
      roomId,
      hostId:     room.hostId!,
      guestId:    user.uid,
      franchise:  room.franchise,
      franchises: room.franchises,
    );

    final updated = await _rooms.doc(roomId).get();
    return DraftRoom.fromFirestore(updated);
  }

  static Future<DraftRoom?> joinRoomByCode(String code) async {
    final room = await getRoomByCode(code);
    if (room == null) return null;
    return joinRoomById(room.id);
  }

  // ── Membership ────────────────────────────────────────────────────────────

  static Future<DraftMember?> getMyMembership(
    String roomId, {
    List<SlotRole>? slots,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _members
        .where('room_id', isEqualTo: roomId)
        .where('user_id', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DraftMember.fromFirestore(snap.docs.first, slots: slots);
  }

  static Future<List<DraftMember>> getMembers(
    String roomId, {
    List<SlotRole>? slots,
  }) async {
    final snap = await _members.where('room_id', isEqualTo: roomId).get();
    return snap.docs
        .map((doc) => DraftMember.fromFirestore(doc, slots: slots))
        .toList();
  }

  // ── Game actions ──────────────────────────────────────────────────────────

  static Future<void> assignCard({
    required String      roomId,
    required String      memberId,
    required SlotRole    slot,
    required DraftRoom   room,
    required DraftMember member,
    required double      cardLevel,
    required String?     nextCardId,
    required int         nextTurnNumber,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || room.currentCardId == null) return;
    if (room.currentTurn != uid)        return;
    if (member.board[slot.key] != null) return;

    final batch = _db.batch();
    batch.update(_members.doc(memberId), {
      'board_${slot.key}': room.currentCardId,
    });
    _advanceTurn(batch, roomId, room,
        nextCardId: nextCardId, nextTurnNumber: nextTurnNumber);
    await batch.commit();
  }

  static Future<void> skipCard({
    required String    roomId,
    required DraftRoom room,
    required String?   nextCardId,
    required int       nextTurnNumber,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || room.currentCardId == null) return;
    if (room.currentTurn != uid)  return;
    if (room.hasUsedSkip(uid))    return;

    final batch = _db.batch();
    batch.update(_rooms.doc(roomId), {
      'skips_used': Map<String, bool>.from(room.skipsUsed)..[uid] = true,
    });
    _advanceTurn(batch, roomId, room,
        nextCardId: nextCardId, nextTurnNumber: nextTurnNumber);
    await batch.commit();
  }

  static Future<void> autoAssign({
    required String      roomId,
    required DraftRoom   room,
    required DraftMember member,
    required double      cardLevel,
    required String?     nextCardId,
    required int         nextTurnNumber,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || room.currentCardId == null) return;
    if (room.currentTurn != uid) return;
    final empty = member.emptySlotsFrom(room.effectiveSlots);
    if (empty.isEmpty)           return;
    await assignCard(
      roomId: roomId, memberId: member.id, slot: empty.first,
      room: room, member: member, cardLevel: cardLevel,
      nextCardId: nextCardId, nextTurnNumber: nextTurnNumber,
    );
  }

  // ── Real-time subscriptions ───────────────────────────────────────────────

  static StreamSubscription<DocumentSnapshot> subscribeToRoom(
    String roomId,
    void Function(DraftRoom) onUpdate,
  ) {
    return _rooms.doc(roomId).snapshots().listen((doc) {
      if (doc.exists) onUpdate(DraftRoom.fromFirestore(doc));
    });
  }

  static StreamSubscription<QuerySnapshot> subscribeToMembers(
    String roomId,
    void Function(List<DraftMember>) onUpdate,
    {List<SlotRole>? slots}
  ) {
    return _members.where('room_id', isEqualTo: roomId).snapshots().listen(
        (snap) => onUpdate(snap.docs
            .map((doc) => DraftMember.fromFirestore(doc, slots: slots))
            .toList()));
  }

  // ── Finalisation ──────────────────────────────────────────────────────────

  static Future<void> checkAndFinaliseIfDone({
    required String              roomId,
    required List<DraftMember>   members,
    required DraftRoom           room,
    required Map<String, double> memberScores,
  }) async {
    if (members.length < 2)                   return;
    if (!members.every((m) => m.isBoardFullWith(room.effectiveSlots))) return;
    if (room.isFinished)                      return;

    DraftMember? winner;
    double topScore = -1;
    bool isDraw = false;

    for (final m in members) {
      final s = memberScores[m.userId] ?? 0.0;
      if (s > topScore) {
        topScore = s;
        winner   = m;
        isDraw   = false;
      } else if (s == topScore) {
        isDraw = true;
      }
    }

    await _rooms.doc(roomId).update({
      'status':          'finished',
      'winner_id':       isDraw ? null : winner?.userId,
      'winner_username': isDraw ? null : winner?.username,
      'current_card_id': null,
      'turn_deadline':   null,
      'current_turn':    null,
    });
  }

  // ── Pass & Play room creation ─────────────────────────────────────────────

  static Future<({DraftRoom room, DraftMember p1Member, DraftMember p2Member})?>
      createPassAndPlayRoom({
    required String          player1Name,
    required String          player2Name,
    required List<DraftCard> allCards,
    List<String>?            franchises,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final code = _generateCode();
    final p1Id = user.uid;
    final p2Id = 'pnp_${code}_p2';
    final seed = Random().nextInt(0x7FFFFFFF);
    final deck = buildDeck(allCards, seed);
    if (deck.isEmpty) return null;

    final deadline = DateTime.now().toUtc().add(const Duration(seconds: 30));

    final docRef = await _rooms.add({
      'code':             code,
      'status':           'drafting',
      'player_ids':       [p1Id, p2Id],
      'player_usernames': [player1Name, player2Name],
      'is_pass_and_play': true,
      'current_turn':     p1Id,
      'current_card_id':  deck.first,
      'turn_number':      0,
      'deck_seed':        seed,
      'skips_used':       {p1Id: false, p2Id: false},
      'turn_deadline':    Timestamp.fromDate(deadline),
      'winner_id':        null,
      'winner_username':  null,
      'created_at':       FieldValue.serverTimestamp(),
      'room_name':        '$player1Name vs $player2Name',
      'franchise':        null,
      'franchises':       franchises,
      'password':         null,
      'is_public':        true,
    });

    final p1MemberId = await _createMember(docRef.id, p1Id, player1Name);
    final p2MemberId = await _createMember(docRef.id, p2Id, player2Name);

    final roomDoc = await docRef.get();
    final p1Doc   = await _members.doc(p1MemberId).get();
    final p2Doc   = await _members.doc(p2MemberId).get();

    return (
      room:     DraftRoom.fromFirestore(roomDoc),
      p1Member: DraftMember.fromFirestore(p1Doc),
      p2Member: DraftMember.fromFirestore(p2Doc),
    );
  }

  // ── P&P spectator sync ────────────────────────────────────────────────────

  static Future<void> pnpSyncBoard({
    required String   roomId,
    required String   p1MemberId,
    required String   p2MemberId,
    required Map<String, DraftCard?> p1Board,
    required Map<String, DraftCard?> p2Board,
    required String   currentTurnId,
    required String?  currentCardId,
  }) async {
    try {
      final batch = _db.batch();
      final p1Fields = <String, dynamic>{};
      for (final e in p1Board.entries) {
        p1Fields['board_${e.key}'] = e.value?.id;
      }
      batch.update(_members.doc(p1MemberId), p1Fields);
      final p2Fields = <String, dynamic>{};
      for (final e in p2Board.entries) {
        p2Fields['board_${e.key}'] = e.value?.id;
      }
      batch.update(_members.doc(p2MemberId), p2Fields);
      batch.update(_rooms.doc(roomId), {
        'current_turn':    currentTurnId,
        'current_card_id': currentCardId,
        'status':          'drafting',
      });
      await batch.commit();
    } catch (_) {}
  }

  static Future<void> pnpFinishGame({
    required String   roomId,
    required String   p1MemberId,
    required String   p2MemberId,
    required Map<String, DraftCard?> p1Board,
    required Map<String, DraftCard?> p2Board,
    required String?  winnerId,
    required String?  winnerUsername,
  }) async {
    try {
      final batch = _db.batch();
      final p1Fields = <String, dynamic>{};
      for (final e in p1Board.entries) {
        p1Fields['board_${e.key}'] = e.value?.id;
      }
      batch.update(_members.doc(p1MemberId), p1Fields);
      final p2Fields = <String, dynamic>{};
      for (final e in p2Board.entries) {
        p2Fields['board_${e.key}'] = e.value?.id;
      }
      batch.update(_members.doc(p2MemberId), p2Fields);
      batch.update(_rooms.doc(roomId), {
        'status':          'finished',
        'winner_id':       winnerId,
        'winner_username': winnerUsername,
        'current_turn':    null,
        'current_card_id': null,
        'turn_deadline':   null,
      });
      await batch.commit();
    } catch (_) {}
  }

  // ── Deck builder ──────────────────────────────────────────────────────────

  static List<String> buildDeck(List<DraftCard> cards, int seed) {
    if (cards.isEmpty) return [];
    final sorted = List<DraftCard>.from(cards)
      ..sort((a, b) => a.id.compareTo(b.id));
    sorted.shuffle(Random(seed));
    return sorted.take(_maxDeckSize).map((c) => c.id).toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static void _advanceTurn(
    WriteBatch batch,
    String     roomId,
    DraftRoom  room, {
    required String? nextCardId,
    required int     nextTurnNumber,
  }) {
    final ids      = room.playerIds;
    final curIndex = ids.indexOf(room.currentTurn ?? '');
    final nextTurn = ids.isNotEmpty ? ids[(curIndex + 1) % ids.length] : null;

    if (nextCardId == null) {
      batch.update(_rooms.doc(roomId), {
        'status':          'finished',
        'turn_number':     nextTurnNumber,
        'current_card_id': null,
        'turn_deadline':   null,
        'current_turn':    null,
      });
    } else {
      batch.update(_rooms.doc(roomId), {
        'turn_number':     nextTurnNumber,
        'current_card_id': nextCardId,
        'current_turn':    nextTurn,
        'turn_deadline':   Timestamp.fromDate(
            DateTime.now().toUtc().add(const Duration(seconds: turnSeconds))),
      });
    }
  }

  static Future<void> _startDraft(
    String roomId, {
    required String    hostId,
    required String    guestId,
    String?            franchise,
    List<String>?      franchises,
  }) async {
    final selected = franchises ?? (franchise != null ? [franchise] : null);
    final cards    = await getAllCards(
      franchises: (selected?.isEmpty ?? true) ? null : selected,
    );
    if (cards.length < 12) {
      await _rooms.doc(roomId).update({'status': 'no_cards'});
      return;
    }

    final seed     = Random().nextInt(0x7FFFFFFF);
    final deck     = buildDeck(cards, seed);
    final deadline = DateTime.now().toUtc()
        .add(const Duration(seconds: turnSeconds));

    await _rooms.doc(roomId).update({
      'status':          'drafting',
      'current_turn':    hostId,
      'deck_seed':       seed,
      'turn_number':     0,
      'current_card_id': deck.first,
      'turn_deadline':   Timestamp.fromDate(deadline),
      'skips_used':      {hostId: false, guestId: false},
    });
  }

  static Future<String> _createMember(
      String roomId, String uid, String username, {
      List<SlotRole>? slots,
  }) async {
    final boardFields = <String, dynamic>{};
    if (slots != null && slots.isNotEmpty) {
      for (final slot in slots) {
        boardFields['board_${slot.key}'] = null;
      }
    } else {
      // Fallback: use static BoardSlot keys for backward compat
      for (final slot in BoardSlot.ordered) {
        boardFields['board_${slot.key}'] = null;
      }
    }
    final ref = await _members.add({
      'room_id':   roomId,
      'user_id':   uid,
      'username':  username,
      ...boardFields,
      'joined_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static String _generateCode() =>
      (100000 + Random().nextInt(900000)).toString();

  // ── Migration helpers ─────────────────────────────────────────────────────

  static Future<Map<String, int>> migrateCardFranchiseIds(
      {void Function(int done, int total)? onProgress}) async {
    final snap  = await _cards.get();
    final total = snap.docs.length;

    final toMigrate = snap.docs.where((doc) {
      final d      = doc.data() as Map<String, dynamic>;
      final hasNew = d['franchiseIds'] is List && (d['franchiseIds'] as List).isNotEmpty;
      return !hasNew;
    }).toList();

    int migrated = 0, skipped = total - toMigrate.length, failed = 0, done = 0;
    const chunkSize = 400;

    for (int i = 0; i < toMigrate.length; i += chunkSize) {
      final chunk = toMigrate.sublist(i, (i + chunkSize).clamp(0, toMigrate.length));
      final batch = _db.batch();
      for (final doc in chunk) {
        try {
          final d   = doc.data() as Map<String, dynamic>;
          final old = d['franchiseId'] as String? ?? '';
          batch.update(doc.reference, {
            'franchiseIds': old.isNotEmpty ? [old] : [],
          });
          migrated++;
        } catch (_) {
          failed++;
        }
        done++;
        onProgress?.call(done, toMigrate.length);
      }
      await batch.commit();
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  static Future<int> recalculateFranchiseCardCounts(
      {void Function(int done, int total)? onProgress}) async {
    final cardSnap = await _cards.get();
    final Map<String, int> counts = {};

    for (final doc in cardSnap.docs) {
      final d   = doc.data() as Map<String, dynamic>;
      List<String> ids;
      final raw = d['franchiseIds'];
      if (raw is List && raw.isNotEmpty) {
        ids = raw.map((e) => e.toString()).toList();
      } else {
        final old = d['franchiseId'] as String? ?? '';
        ids = old.isNotEmpty ? [old] : [];
      }
      for (final id in ids) {
        if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    final franchiseSnap = await _franchises.get();
    int updated = 0, done = 0;
    const chunkSize = 400;
    final docs = franchiseSnap.docs;

    for (int i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.sublist(i, (i + chunkSize).clamp(0, docs.length));
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'cardCount': counts[doc.id] ?? 0});
        updated++;
        done++;
        onProgress?.call(done, docs.length);
      }
      await batch.commit();
    }
    return updated;
  }
}
