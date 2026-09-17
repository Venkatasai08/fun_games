// lib/draftclash/models/draft_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single character card in DraftClash.
///
/// [franchiseIds] — the list of franchise IDs this card belongs to.
///   Supports multi-franchise (e.g. Messi → [barcelonaId, argentinaId]).
///   Backward-compatible: old cards with a single [franchiseId] string field
///   are automatically read into a one-element list.
///
/// [franchiseName] — the primary display franchise name (unchanged).
class DraftCard {
  final String id;

  /// All franchise IDs this card belongs to.
  final List<String> franchiseIds;

  /// Primary display franchise (kept for backward compat + game filtering).
  final String franchiseName;

  final String name;
  final String description;
  final double level;
  final String imageUrl;

  const  DraftCard({
    required this.id,
    required this.franchiseIds,
    required this.franchiseName,
    required this.name,
    required this.description,
    required this.level,
    required this.imageUrl,
  });

  /// Convenience getter — first element, or empty string.
  String get franchiseId => franchiseIds.isNotEmpty ? franchiseIds.first : '';

  // ── Firestore deserialization ─────────────────────────────────────────────
  //
  // Handles both legacy format  { franchiseId: "abc" }
  // and new format              { franchiseIds: ["abc", "xyz"] }
  factory DraftCard.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    List<String> ids;
    final rawIds = d['franchiseIds'];
    if (rawIds is List && rawIds.isNotEmpty) {
      ids = rawIds.map((e) => e.toString()).toList();
    } else {
      // Legacy single-string field
      final oldId = d['franchiseId'] as String? ?? '';
      ids = oldId.isNotEmpty ? [oldId] : [];
    }

    return DraftCard(
      id:            doc.id,
      franchiseIds:  ids,
      franchiseName: d['franchiseName'] as String? ?? '',
      name:          d['name']          as String? ?? 'Unknown',
      description:   d['description']   as String? ?? '',
      level:         ((d['level'] as num?)?.toDouble() ?? 1.0).clamp(1.0, 10.0),
      imageUrl:      d['imageUrl']      as String? ?? '',
    );
  }

  // ── Firestore serialization ───────────────────────────────────────────────
  //
  // Writes the new [franchiseIds] list. Does NOT write the old [franchiseId]
  // scalar — existing old-format docs keep their field until migrated.
  Map<String, dynamic> toMap() => {
    'franchiseIds':  franchiseIds,
    'franchiseName': franchiseName,
    'name':          name,
    'description':   description,
    'level':         level,
    'imageUrl':      imageUrl,
    'createdAt':     FieldValue.serverTimestamp(),
  };

  DraftCard copyWith({
    String?       id,
    List<String>? franchiseIds,
    String?       franchiseName,
    String?       name,
    String?       description,
    double?       level,
    String?       imageUrl,
  }) {
    return DraftCard(
      id:            id            ?? this.id,
      franchiseIds:  franchiseIds  ?? List.from(this.franchiseIds),
      franchiseName: franchiseName ?? this.franchiseName,
      name:          name          ?? this.name,
      description:   description   ?? this.description,
      level:         level         ?? this.level,
      imageUrl:      imageUrl      ?? this.imageUrl,
    );
  }

  String get tierLabel {
    if (level >= 9.6) return 'LEGENDARY';
    if (level >= 8.5) return 'MYTHIC';
    if (level >= 6.5) return 'EPIC';
    if (level >= 3.5) return 'RARE';
    return 'COMMON';
  }

  /// Display string e.g. "7.5" or "8.0" → "8"
  String get levelDisplay =>
      level == level.roundToDouble() ? level.toInt().toString() : level.toStringAsFixed(1);
}
