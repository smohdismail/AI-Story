import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'ambient_sound_service.dart';
import '../api.dart';

class RealWorldSyncService extends ChangeNotifier {
  static final RealWorldSyncService _instance = RealWorldSyncService._internal();
  static RealWorldSyncService get instance => _instance;
  factory RealWorldSyncService() => _instance;
  RealWorldSyncService._internal();

  bool _isInitialized = false;
  bool _isLoading = false;

  String _city = 'Local';
  String _country = '';
  double? _temperatureC;
  String _weatherDescription = 'Clear';
  String _weatherCategory = 'sunny'; // 'rain', 'snow', 'night', 'cafe', 'sunny'
  bool _isDay = true;
  DateTime _lastFetched = DateTime.now();

  // Settings
  bool _syncEnabled = true;

  String get city => _city;
  String get country => _country;
  double? get temperatureC => _temperatureC;
  String get weatherDescription => _weatherDescription;
  String get weatherCategory => _weatherCategory;
  bool get isDay => _isDay;
  bool get isLoading => _isLoading;
  bool get syncEnabled => _syncEnabled;

  String get displayLocation {
    if (_city == 'Local' && _country.isEmpty) return 'Live Earth Sync';
    if (_country.isEmpty) return _city;
    return '$_city, $_country';
  }

  String get temperatureDisplay {
    if (_temperatureC == null) return '';
    return '${_temperatureC!.round()}°C';
  }

  String get localTimeFormatted {
    final now = DateTime.now();
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = now.minute.toString().padLeft(2, '0');
    return '$displayHour:$minute $period';
  }

  String get humanRoutinePhase {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 9) {
      return 'Early morning (waking up, breakfast, morning coffee/tea)';
    } else if (hour >= 9 && hour < 12) {
      return 'Morning focus hours (working, studying, busy active day)';
    } else if (hour >= 12 && hour < 14) {
      return 'Midday lunch break (eating lunch, midday pause)';
    } else if (hour >= 14 && hour < 18) {
      return 'Afternoon (working, studying, winding down daily tasks)';
    } else if (hour >= 18 && hour < 21) {
      return 'Evening unwind (heading home, dinner, relaxing)';
    } else if (hour >= 21 && hour < 23) {
      return 'Night cozy downtime (getting comfortable in bed, winding down)';
    } else if (hour >= 23 || hour < 4) {
      return 'Late night (dark quiet room, in bed, sleepy vulnerability)';
    } else {
      return 'Silent pre-dawn twilight hours';
    }
  }

  String get fullRealityContext {
    if (!_syncEnabled) return '';

    final temp = _temperatureC != null ? '${_temperatureC!.round()}°C' : '';
    final weatherPart = temp.isNotEmpty ? '$temp, $_weatherDescription' : _weatherDescription;

    return '''• User's Real City/Location: $displayLocation
• Live Real-World Weather: $weatherPart
• Real Local Clock Time: $localTimeFormatted
• Daily Biological Routine: $humanRoutinePhase''';
  }

  Timer? _periodicSyncTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadFromPrefs();
    refreshReality();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      refreshReality();
    });
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _city = prefs.getString('reality_city') ?? 'Local';
      _country = prefs.getString('reality_country') ?? '';
      _temperatureC = prefs.getDouble('reality_temp');
      _weatherDescription = prefs.getString('reality_desc') ?? 'Clear';
      _weatherCategory = prefs.getString('reality_category') ?? 'sunny';
      _syncEnabled = prefs.getBool('reality_sync_enabled') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reality_city', _city);
      await prefs.setString('reality_country', _country);
      if (_temperatureC != null) {
        await prefs.setDouble('reality_temp', _temperatureC!);
      }
      await prefs.setString('reality_desc', _weatherDescription);
      await prefs.setString('reality_category', _weatherCategory);
      await prefs.setBool('reality_sync_enabled', _syncEnabled);
    } catch (_) {}
  }

  Future<void> refreshReality() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. IP Geolocation fetch
      final geoResp = await http.get(Uri.parse('http://ip-api.com/json/')).timeout(const Duration(seconds: 5));
      if (geoResp.statusCode == 200) {
        final geo = jsonDecode(geoResp.body) as Map<String, dynamic>;
        if (geo['status'] == 'success') {
          _city = geo['city'] ?? _city;
          _country = geo['country'] ?? _country;
          final lat = geo['lat'];
          final lon = geo['lon'];

          // 2. Open-Meteo live weather fetch
          if (lat != null && lon != null) {
            final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,is_day';
            final weatherResp = await http.get(Uri.parse(weatherUrl)).timeout(const Duration(seconds: 5));
            if (weatherResp.statusCode == 200) {
              final wdata = jsonDecode(weatherResp.body) as Map<String, dynamic>;
              final current = wdata['current'] as Map<String, dynamic>?;
              if (current != null) {
                _temperatureC = (current['temperature_2m'] as num?)?.toDouble();
                _isDay = (current['is_day'] as int? ?? 1) == 1;
                final code = current['weather_code'] as int? ?? 0;
                _interpretWeatherCode(code, _isDay);
              }
            }
          }
        }
      }

      _lastFetched = DateTime.now();
      await _saveToPrefs();

      // Automatically sync with AmbientSoundService visual overlay
      AmbientSoundService().setWeather(_weatherCategory, syncSound: false);

      // Ping backend heartbeat to keep Render and Supabase alive
      ApiService.pingHeartbeat();

    } catch (e) {
      debugPrint('RealWorldSyncService: refresh error $e (using cached values)');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _interpretWeatherCode(int code, bool isDay) {
    if (code == 0) {
      _weatherDescription = isDay ? 'Clear & Sunny' : 'Clear Starlight';
      _weatherCategory = isDay ? 'sunny' : 'night';
    } else if (code == 1 || code == 2 || code == 3) {
      _weatherDescription = 'Partly Cloudy';
      _weatherCategory = isDay ? 'cafe' : 'night';
    } else if (code == 45 || code == 48) {
      _weatherDescription = 'Foggy & Misty';
      _weatherCategory = 'cafe';
    } else if (code >= 51 && code <= 57) {
      _weatherDescription = 'Gentle Drizzle';
      _weatherCategory = 'rain';
    } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      _weatherDescription = 'Rain';
      _weatherCategory = 'rain';
    } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      _weatherDescription = 'Snowfall';
      _weatherCategory = 'snow';
    } else if (code >= 95 && code <= 99) {
      _weatherDescription = 'Thunderstorm & Rain';
      _weatherCategory = 'rain';
    } else {
      _weatherDescription = isDay ? 'Daytime' : 'Night';
      _weatherCategory = isDay ? 'sunny' : 'night';
    }

    // If it's night time locally, prefer 'night' unless it's actively raining/snowing
    final hour = DateTime.now().hour;
    if ((hour >= 21 || hour < 6) && _weatherCategory != 'rain' && _weatherCategory != 'snow') {
      _weatherCategory = 'night';
    }
  }

  void toggleSync(bool enabled) {
    _syncEnabled = enabled;
    _saveToPrefs();
    notifyListeners();
  }

  void setManualOverride({
    required String city,
    required String country,
    required double tempC,
    required String weatherCategory,
    required String weatherDescription,
  }) {
    _city = city;
    _country = country;
    _temperatureC = tempC;
    _weatherCategory = weatherCategory;
    _weatherDescription = weatherDescription;
    _saveToPrefs();

    AmbientSoundService().setWeather(_weatherCategory, syncSound: false);
    notifyListeners();
  }
}
