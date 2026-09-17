// lib/draftclash/models/slot_role.dart
//
// A dynamic board slot (role) in DraftClash, created by admins and stored in
// Firestore's `draft_slots` collection.
//
// Effect semantics (resolved entirely client-side — never stored in Firestore):
//   increment → card level added to the player's own score  (normal)
//   decrement → card level subtracted from own score AND added to opponent's
//               score (Traitor-style mechanic)

import 'package:cloud_firestore/cloud_firestore.dart';

enum SlotEffect { increment, decrement }

class SlotRole {
  final String id;       // Firestore document ID
  final String name;     // Display label, e.g. "Vice Captain"
  final String key;      // snake_case field prefix, e.g. "vice_captain"
  final SlotEffect effect;
  final int order;       // 0-based stable display order

  const SlotRole({
    required this.id,
    required this.name,
    required this.key,
    required this.effect,
    required this.order,
  });

  bool get isDecrement => effect == SlotEffect.decrement;

  // ── Firestore deserialization ─────────────────────────────────────────────
  factory SlotRole.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SlotRole(
      id:     doc.id,
      name:   d['name']   as String? ?? 'Slot',
      key:    d['key']    as String? ?? doc.id,
      effect: (d['effect'] as String?) == 'decrement'
          ? SlotEffect.decrement
          : SlotEffect.increment,
      order:  (d['order'] as num?)?.toInt() ?? 99,
    );
  }

  factory SlotRole.fromMap(Map<String, dynamic> d) {
    return SlotRole(
      id:     d['id']     as String? ?? d['key'] as String? ?? 'slot',
      name:   d['name']   as String? ?? 'Slot',
      key:    d['key']    as String? ?? d['id'] as String? ?? 'slot',
      effect: (d['effect'] as String?) == 'decrement'
          ? SlotEffect.decrement
          : SlotEffect.increment,
      order:  (d['order'] as num?)?.toInt() ?? 99,
    );
  }

  // ── Firestore serialization ───────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'name':      name,
    'key':       key,
    'effect':    effect.name,   // 'increment' or 'decrement'
    'order':     order,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toRoomMap() => {
    'id':     id,
    'name':   name,
    'key':    key,
    'effect': effect.name,
    'order':  order,
  };

  SlotRole copyWith({
    String? id,
    String? name,
    String? key,
    SlotEffect? effect,
    int? order,
  }) => SlotRole(
    id:     id     ?? this.id,
    name:   name   ?? this.name,
    key:    key    ?? this.key,
    effect: effect ?? this.effect,
    order:  order  ?? this.order,
  );

  // ── Default fallback slots (used when no slots exist in Firestore yet) ────
  static List<SlotRole> get defaults => [
    const SlotRole(id: '_captain',      name: 'Captain',      key: 'captain',      effect: SlotEffect.increment, order: 0),
    const SlotRole(id: '_vice_captain', name: 'Vice Captain', key: 'vice_captain', effect: SlotEffect.increment, order: 1),
    const SlotRole(id: '_tank',         name: 'Tank',         key: 'tank',         effect: SlotEffect.increment, order: 2),
    const SlotRole(id: '_duelist',      name: 'Duelist',      key: 'duelist',      effect: SlotEffect.increment, order: 3),
    const SlotRole(id: '_support',      name: 'Support',      key: 'support',      effect: SlotEffect.increment, order: 4),
    const SlotRole(id: '_traitor',      name: 'Traitor',      key: 'traitor',      effect: SlotEffect.decrement, order: 5),
  ];

  // ── Icon mapping by common role names (case-insensitive prefix match) ─────
  static String iconKeyFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('captain') && n.contains('vice')) return 'vice_captain';
    if (n.contains('captain'))  return 'captain';
    if (n.contains('tank'))     return 'tank';
    if (n.contains('duel'))     return 'duelist';
    if (n.contains('support'))  return 'support';
    if (n.contains('traitor'))  return 'traitor';
    return 'default';
  }
}
