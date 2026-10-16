import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudiobookService extends ChangeNotifier {
  static final AudiobookService instance = AudiobookService._internal();
  AudiobookService._internal() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  String? _storyTitle;
  String? _storyCoverUrl;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speed = 0.5;
  final double _pitch = 1.0;
  int? _sleepTimerMinutes;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;

  List<Map<String, dynamic>> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  String? get storyTitle => _storyTitle;
  String? get storyCoverUrl => _storyCoverUrl;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get hasTrack => _playlist.isNotEmpty;
  double get speed => _speed;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  Duration? get remainingSleepTime => _sleepTimerEnd?.difference(DateTime.now());

  Map<String, dynamic>? get currentChapter => 
      (_playlist.isNotEmpty && _currentIndex >= 0 && _currentIndex < _playlist.length) 
          ? _playlist[_currentIndex] 
          : null;

  void _initTts() {
    _tts.setSpeechRate(_speed);
    _tts.setPitch(_pitch);
    _tts.setCompletionHandler(() {
      _onTrackComplete();
    });
    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
    });
  }

  String _cleanContent(String raw) {
    if (raw.trim().isEmpty) return "";
    if (raw.startsWith('[{') && raw.endsWith('}]')) {
      try {
        final List<dynamic> delta = jsonDecode(raw);
        final buffer = StringBuffer();
        for (var op in delta) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert']);
          }
        }
        return buffer.toString().trim();
      } catch (_) {}
    }
    return raw;
  }

  Future<void> startPlaylist(List<Map<String, dynamic>> chapters, int startIndex, {String? storyTitle, String? coverUrl}) async {
    if (chapters.isEmpty) return;
    _playlist = List<Map<String, dynamic>>.from(chapters);
    _currentIndex = (startIndex >= 0 && startIndex < _playlist.length) ? startIndex : 0;
    _storyTitle = storyTitle;
    _storyCoverUrl = coverUrl;
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    final chapter = currentChapter;
    if (chapter == null) {
      stop();
      return;
    }

    final rawContent = chapter['content']?.toString() ?? '';
    final plain = _cleanContent(rawContent);
    final title = chapter['title'] ?? 'Chapter ${chapter['chapter_number']}';
    final textToSpeak = '$title.\n\n$plain';

    await _tts.stop();
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(_pitch);

    _isPlaying = true;
    _isPaused = false;
    notifyListeners();

    await _tts.speak(textToSpeak);
  }

  void _onTrackComplete() {
    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      _speakCurrent();
    } else {
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _tts.stop();
      _isPlaying = false;
      _isPaused = true;
      notifyListeners();
    } else if (_isPaused) {
      await _speakCurrent();
    }
  }

  Future<void> nextChapter() async {
    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await _speakCurrent();
    }
  }

  Future<void> previousChapter() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _speakCurrent();
    } else {
      await _speakCurrent();
    }
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    await _tts.setSpeechRate(newSpeed);
    notifyListeners();
  }

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;
    if (minutes != null && minutes > 0) {
      _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        stop();
        _sleepTimerMinutes = null;
        _sleepTimerEnd = null;
        notifyListeners();
      });
    } else {
      _sleepTimerEnd = null;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _isPaused = false;
    _sleepTimer?.cancel();
    _sleepTimerMinutes = null;
    _sleepTimerEnd = null;
    notifyListeners();
  }
}
