// lib/draftclash/models/board_slot.dart

enum BoardSlot {
  captain, viceCaptain, tank, duelist, support, traitor;

  String get label {
    switch (this) {
      case BoardSlot.captain:     return 'Captain';
      case BoardSlot.viceCaptain: return 'Vice Captain';
      case BoardSlot.tank:        return 'Tank';
      case BoardSlot.duelist:     return 'Duelist';
      case BoardSlot.support:     return 'Support';
      case BoardSlot.traitor:     return 'Traitor';
    }
  }

  String get key {
    switch (this) {
      case BoardSlot.captain:     return 'captain';
      case BoardSlot.viceCaptain: return 'vice_captain';
      case BoardSlot.tank:        return 'tank';
      case BoardSlot.duelist:     return 'duelist';
      case BoardSlot.support:     return 'support';
      case BoardSlot.traitor:     return 'traitor';
    }
  }

  static BoardSlot fromKey(String key) =>
      BoardSlot.values.firstWhere((s) => s.key == key);

  static const List<BoardSlot> ordered = [
    BoardSlot.captain, BoardSlot.viceCaptain, BoardSlot.tank,
    BoardSlot.duelist, BoardSlot.support, BoardSlot.traitor,
  ];
}
