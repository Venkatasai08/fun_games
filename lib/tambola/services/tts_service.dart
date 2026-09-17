// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

/// Singleton wrapper around FlutterTts.
/// Call [speak] to announce a called number.
/// [enabled] is a runtime flag each player can toggle independently.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;

  Future<void> _init() async {
    if (_initialised) return;
    _initialised = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);   // slightly slower — clearer for numbers
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // On Android, use the network-quality voice when available
    await _tts.setVoice({'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US'});
  }

  /// Speak the called number (e.g. 69 → "Number 69").
  /// Does nothing if [enabled] is false.
  Future<void> announceNumber(int number, {bool enabled = true}) async {
    if (!enabled) return;
    await _init();
    await _tts.stop();                // cancel any in-progress speech first
    await _tts.speak('Number $number');
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
