// lib/draftclash/services/draft_sound_service.dart
//
// Sound effects for DraftClash using flutter_tts (already in pubspec)
// + SystemSound/HapticFeedback for UI taps.

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DraftSoundService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool soundEnabled = true;

  static Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.55);
    await _tts.setVolume(1.0);
    _initialized = true;
  }

  static Future<void> _speak(String text) async {
    if (!soundEnabled) return;
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  // ── UI interactions ───────────────────────────────────────────────────────

  static void tapSound() {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void successTap() {
    if (!soundEnabled) return;
    HapticFeedback.mediumImpact();
  }

  static void errorTap() {
    if (!soundEnabled) return;
    HapticFeedback.heavyImpact();
  }

  // ── Game events ───────────────────────────────────────────────────────────

  static Future<void> roomCreated() =>
      _speak('Room created! Share your code.');

  static Future<void> opponentJoined() =>
      _speak('Opponent joined! Draft is starting!');

  static Future<void> gameStarting() =>
      _speak('Draft Clash! Starting now. Choose wisely.');

  static Future<void> yourTurn() => _speak('Your turn!');

  static Future<void> cardDrawn(String cardName) =>
      _speak('Card drawn: $cardName');

  static Future<void> slotFilled(String slotName) =>
      _speak('$slotName filled.');

  static Future<void> skipUsed() => _speak('Skip used.');

  static Future<void> timerWarning() => _speak('5 seconds!');

  static Future<void> roundOver() => _speak('Draft complete!');

  static Future<void> victory() => _speak('Victory! You win this draft!');

  static Future<void> defeat() => _speak('Better luck next time.');

  static Future<void> draw() => _speak("It's a draw!");

  static Future<void> joinedRoom(String roomName) =>
      _speak('Joined $roomName.');

  static Future<void> stop() async {
    await _tts.stop();
  }
}
