// lib/draftclash/models/franchise_category.dart

/// The broad category of a franchise — drives which image API is used
/// and how the AI prompt is worded.
enum FranchiseCategory {
  anime,   // Jikan (MyAnimeList) for images
  movie,   // Wikipedia images
  comics,  // Wikipedia images
  game,    // Wikipedia images
  sports,  // Wikipedia images — generates real players
  other;   // Wikipedia images — requires custom context from admin

  static FranchiseCategory fromString(String? s) {
    switch (s) {
      case 'anime':  return anime;
      case 'movie':  return movie;
      case 'comics': return comics;
      case 'game':   return game;
      case 'sports': return sports;
      default:       return other;
    }
  }

  String get label {
    switch (this) {
      case anime:  return 'Anime';
      case movie:  return 'Movie';
      case comics: return 'Comics';
      case game:   return 'Game';
      case sports: return 'Sports';
      case other:  return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case anime:  return '🎌';
      case movie:  return '🎬';
      case comics: return '🦸';
      case game:   return '🎮';
      case sports: return '⚽';
      case other:  return '✨';
    }
  }

  /// Whether this category generates real people (players) vs fictional characters.
  bool get isRealPeople => this == sports;

  /// Whether an extra custom-context field should be shown in the AI generate screen.
  bool get needsCustomContext => this == other;
}
