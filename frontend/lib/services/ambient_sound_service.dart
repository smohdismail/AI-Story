import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AmbientPreset {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String description;

  const AmbientPreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.description,
  });
}

class AmbientSoundService {
  static final AmbientSoundService _instance = AmbientSoundService._internal();
  factory AmbientSoundService() => _instance;
  AmbientSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  AmbientPreset? _currentPreset;
  double _volume = 0.5;
  double _preDuckVolume = 0.5;
  bool _isPlaying = false;

  static const List<AmbientPreset> presets = [
    AmbientPreset(
      id: 'rain',
      name: 'Heavy Rain & Thunder',
      icon: '🌧️',
      url: 'https://actions.google.com/sounds/v1/weather/rain_heavy.ogg',
      description: 'Rain drumming against floor-to-ceiling glass & distant thunder',
    ),
    AmbientPreset(
      id: 'fireplace',
      name: 'Crackling Fireplace',
      icon: '🔥',
      url: 'https://actions.google.com/sounds/v1/ambiences/fireplace.ogg',
      description: 'Warm glowing embers in a secluded winter cabin',
    ),
    AmbientPreset(
      id: 'ocean',
      name: 'Night Ocean Balcony',
      icon: '🌊',
      url: 'https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg',
      description: 'Soft rolling tides under a midnight moon',
    ),
    AmbientPreset(
      id: 'night_crickets',
      name: 'Midnight Garden & Crickets',
      icon: '🌙',
      url: 'https://actions.google.com/sounds/v1/animals/crickets_chirping.ogg',
      description: 'Peaceful secluded garden under starlight',
    ),
  ];

  AmbientPreset? get currentPreset => _currentPreset;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  Future<void> playPreset(AmbientPreset preset) async {
    try {
      _currentPreset = preset;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      await _player.play(UrlSource(preset.url));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Error playing ambient sound: $e');
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping ambient sound: $e');
    }
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    if (_isPlaying) {
      await _player.setVolume(_volume);
    }
  }

  Future<void> duckVolume() async {
    if (!_isPlaying) return;
    _preDuckVolume = _volume;
    await _player.setVolume((_volume * 0.25).clamp(0.05, 1.0));
  }

  Future<void> restoreVolume() async {
    if (!_isPlaying) return;
    await _player.setVolume(_preDuckVolume);
  }

  void dispose() {
    _player.dispose();
  }
}
