import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AmbientPreset {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String description;
  final String associatedWeather; // 'rain', 'snow', 'night', 'cafe', 'sunny'

  const AmbientPreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.description,
    this.associatedWeather = 'rain',
  });
}

class AmbientSoundService extends ChangeNotifier {
  static final AmbientSoundService _instance = AmbientSoundService._internal();
  factory AmbientSoundService() => _instance;
  AmbientSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  AmbientPreset? _currentPreset;
  double _volume = 0.5;
  double _preDuckVolume = 0.5;
  bool _isPlaying = false;

  // Real-world dynamic weather & ambience state
  String _currentWeather = 'rain'; // 'rain', 'snow', 'night', 'cafe', 'sunny', 'none'
  bool _isOverlayEnabled = true;
  bool _autoSyncWithRealWorld = false;
  double _weatherIntensity = 0.75;

  static const List<AmbientPreset> presets = [
    AmbientPreset(
      id: 'rain',
      name: 'Heavy Rain & Thunder',
      icon: '🌧️',
      url: 'https://actions.google.com/sounds/v1/weather/rain_heavy.ogg',
      description: 'Rain drumming against floor-to-ceiling glass & distant thunder',
      associatedWeather: 'rain',
    ),
    AmbientPreset(
      id: 'jazz',
      name: 'Sultry Velvet Jazz',
      icon: '🎷',
      url: 'https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
      description: 'Late-night upright bass, warm piano, and smoky lounge romance',
      associatedWeather: 'cafe',
    ),
    AmbientPreset(
      id: 'night_crickets',
      name: 'Midnight Garden & Crickets',
      icon: '🌙',
      url: 'https://actions.google.com/sounds/v1/animals/crickets_chirping.ogg',
      description: 'Peaceful secluded garden under quiet starlight',
      associatedWeather: 'night',
    ),
    AmbientPreset(
      id: 'fireplace',
      name: 'Crackling Fireplace',
      icon: '🔥',
      url: 'https://actions.google.com/sounds/v1/ambiences/fireplace.ogg',
      description: 'Warm glowing embers in a secluded winter cabin',
      associatedWeather: 'snow',
    ),
    AmbientPreset(
      id: 'ocean',
      name: 'Night Ocean Balcony',
      icon: '🌊',
      url: 'https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg',
      description: 'Soft rolling tides under a midnight moon',
      associatedWeather: 'night',
    ),
    AmbientPreset(
      id: 'piano',
      name: 'Midnight Piano Solitude',
      icon: '🎹',
      url: 'https://actions.google.com/sounds/v1/ambiences/humming_meditation.ogg',
      description: 'Slow, melancholic felt piano chords mirroring emotional hesitation',
      associatedWeather: 'rain',
    ),
    AmbientPreset(
      id: 'strings',
      name: 'Cinematic Heartstrings',
      icon: '🎻',
      url: 'https://actions.google.com/sounds/v1/ambiences/outdoor_evening.ogg',
      description: 'Tender orchestral cello & swelling strings for high-stakes climaxes',
      associatedWeather: 'night',
    ),
  ];

  AmbientPreset? get currentPreset => _currentPreset;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  String get currentWeather => _currentWeather;
  bool get isOverlayEnabled => _isOverlayEnabled;
  bool get autoSyncWithRealWorld => _autoSyncWithRealWorld;
  double get weatherIntensity => _weatherIntensity;

  String get effectiveWeather {
    if (!_autoSyncWithRealWorld) return _currentWeather;
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5) return 'night';
    if (hour >= 5 && hour < 9) return 'sunny';
    if (hour >= 9 && hour < 17) return 'cafe';
    if (hour >= 17 && hour < 22) return 'rain';
    return _currentWeather;
  }

  String get localTimeDesc {
    final now = DateTime.now();
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final timeStr = '$displayHour:$minute $period';

    if (hour >= 23 || hour < 5) return 'Late Night ($timeStr)';
    if (hour < 8) return 'Crisp Early Morning ($timeStr)';
    if (hour < 12) return 'Bright Morning ($timeStr)';
    if (hour < 17) return 'Afternoon ($timeStr)';
    if (hour < 20) return 'Twilight Sunset ($timeStr)';
    return 'Quiet Evening ($timeStr)';
  }

  void setWeather(String weather, {bool syncSound = true}) {
    _currentWeather = weather;
    if (syncSound) {
      // Find matching sound preset
      final match = presets.firstWhere(
        (p) => p.associatedWeather == weather,
        orElse: () => presets[0],
      );
      playPreset(match);
    }
    notifyListeners();
  }

  void toggleOverlay(bool enabled) {
    _isOverlayEnabled = enabled;
    notifyListeners();
  }

  void toggleAutoSync(bool enabled) {
    _autoSyncWithRealWorld = enabled;
    if (_autoSyncWithRealWorld) {
      setWeather(effectiveWeather, syncSound: false);
    }
    notifyListeners();
  }

  void setWeatherIntensity(double val) {
    _weatherIntensity = val.clamp(0.1, 1.0);
    notifyListeners();
  }

  Future<void> playPreset(AmbientPreset preset) async {
    try {
      _currentPreset = preset;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      await _player.play(UrlSource(preset.url));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing ambient sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping ambient sound: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing ambient sound: $e');
    }
  }

  Future<void> resume() async {
    try {
      if (_currentPreset != null) {
        await _player.resume();
        _isPlaying = true;
        notifyListeners();
      } else if (presets.isNotEmpty) {
        await playPreset(presets[0]);
      }
    } catch (e) {
      debugPrint('Error resuming ambient sound: $e');
    }
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    if (_isPlaying) {
      await _player.setVolume(_volume);
    }
    notifyListeners();
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
