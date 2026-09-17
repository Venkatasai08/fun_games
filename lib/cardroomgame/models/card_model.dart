// lib/cardroomgame/models/card_model.dart
import 'package:equatable/equatable.dart';

enum CardSuit { spades, hearts, diamonds, clubs }

enum CardRank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

class PlayingCard extends Equatable {
  final String id; // e.g. "hearts_queen"
  final CardSuit suit;
  final CardRank rank;
  final bool faceUp;

  const PlayingCard({
    required this.id,
    required this.suit,
    required this.rank,
    this.faceUp = false,
  });

  // ── Factory ────────────────────────────────────────────────────────────

  static List<PlayingCard> generateDeck() {
    final deck = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        deck.add(PlayingCard(
          id: '${suit.name}_${rank.name}',
          suit: suit,
          rank: rank,
        ));
      }
    }
    return deck;
  }

  // ── Display helpers ────────────────────────────────────────────────────

  String get suitSymbol {
    switch (suit) {
      case CardSuit.spades:
        return '♠';
      case CardSuit.hearts:
        return '♥';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
    }
  }

  String get rankLabel {
    switch (rank) {
      case CardRank.ace:
        return 'A';
      case CardRank.two:
        return '2';
      case CardRank.three:
        return '3';
      case CardRank.four:
        return '4';
      case CardRank.five:
        return '5';
      case CardRank.six:
        return '6';
      case CardRank.seven:
        return '7';
      case CardRank.eight:
        return '8';
      case CardRank.nine:
        return '9';
      case CardRank.ten:
        return '10';
      case CardRank.jack:
        return 'J';
      case CardRank.queen:
        return 'Q';
      case CardRank.king:
        return 'K';
    }
  }

  bool get isRed =>
      suit == CardSuit.hearts || suit == CardSuit.diamonds;

  // ── Serialization ──────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'suit': suit.name,
        'rank': rank.name,
        'face_up': faceUp,
      };

  factory PlayingCard.fromMap(Map<String, dynamic> map) => PlayingCard(
        id: map['id'] as String,
        suit: CardSuit.values.byName(map['suit'] as String),
        rank: CardRank.values.byName(map['rank'] as String),
        faceUp: map['face_up'] as bool? ?? false,
      );

  PlayingCard copyWith({bool? faceUp}) => PlayingCard(
        id: id,
        suit: suit,
        rank: rank,
        faceUp: faceUp ?? this.faceUp,
      );

  @override
  List<Object?> get props => [id, suit, rank, faceUp];
}
