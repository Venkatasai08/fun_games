// lib/draftclash/models/draft_member.dart
//
// A player's membership in a DraftClash room.
// Only the board (slot → cardId) is stored in Firestore.
// Score is NEVER stored — computed client-side from board + card levels + slot effects.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'board_slot.dart';
import 'slot_role.dart';

class DraftMember {
  final String id;
  final String roomId;
  final String userId;
  final String username;

  /// slot.key → cardId (null = slot not yet filled).
  final Map<String, String?> board;

  const DraftMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.board,
  });

  /// Deserializes from Firestore using a dynamic slot list.
  /// Falls back to the static [BoardSlot.ordered] keys if no slots are provided,
  /// ensuring backward compatibility with existing documents.
  factory DraftMember.fromFirestore(
    DocumentSnapshot doc, {
    List<SlotRole>? slots,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    final board = <String, String?>{};
    if (slots != null && slots.isNotEmpty) {
      for (final slot in slots) {
        board[slot.key] = d['board_${slot.key}'] as String?;
      }
    } else {
      // Backward-compat: fall back to static enum keys
      for (final slot in BoardSlot.ordered) {
        board[slot.key] = d['board_${slot.key}'] as String?;
      }
    }
    return DraftMember(
      id:       doc.id,
      roomId:   d['room_id']  as String? ?? '',
      userId:   d['user_id']  as String? ?? '',
      username: d['username'] as String? ?? 'Unknown',
      board:    board,
    );
  }

  /// Whether all slots in [slots] are filled.
  /// Falls back to BoardSlot.ordered if [slots] is empty.
  bool isBoardFullWith(List<SlotRole> slots) {
    if (slots.isEmpty) {
      return BoardSlot.ordered.every((s) => board[s.key] != null);
    }
    return slots.every((s) => board[s.key] != null);
  }

  /// Legacy getter for backward compat (uses static enum).
  bool get isBoardFull =>
      BoardSlot.ordered.every((s) => board[s.key] != null);

  /// Empty slots from the dynamic list.
  List<SlotRole> emptySlotsFrom(List<SlotRole> slots) =>
      slots.where((s) => board[s.key] == null).toList();

  /// Legacy getter for backward compat (uses static enum).
  List<BoardSlot> get emptySlots =>
      BoardSlot.ordered.where((s) => board[s.key] == null).toList();

  DraftMember copyWith({Map<String, String?>? board}) => DraftMember(
        id: id, roomId: roomId, userId: userId, username: username,
        board: board ?? this.board,
      );
}
