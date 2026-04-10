import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sound service for focus session audio feedback.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      _initialized = true;
      debugPrint('SoundService: Initialized');
    } catch (e) {
      debugPrint('SoundService: Init failed — $e');
    }
  }

  /// Play the water droplet sound.
  Future<void> playDroplet() async {
    if (!_initialized) return;
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/droplet.mp3'));
    } catch (e) {
      debugPrint('SoundService: Playback failed — $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(1.0);
  }

  void dispose() {
    _player.dispose();
  }
}
