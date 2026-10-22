import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class CharacterVoiceService extends ChangeNotifier {
  static final CharacterVoiceService _instance = CharacterVoiceService._internal();
  factory CharacterVoiceService() => _instance;
  CharacterVoiceService._internal() {
    _initPlayer();
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentMessageId;
  String? _currentSpeakingText;
  bool _autoVoiceEnabled = false;
  String _preferredVoice = 'en-US-JennyNeural';

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentMessageId => _currentMessageId;
  String? get currentSpeakingText => _currentSpeakingText;
  bool get autoVoiceEnabled => _autoVoiceEnabled;
  String get preferredVoice => _preferredVoice;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoVoiceEnabled = prefs.getBool('pref_autovoice_enabled') ?? false;
      _preferredVoice = prefs.getString('pref_character_voice') ?? 'en-US-JennyNeural';
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing voice preferences: $e');
    }
  }

  void _initPlayer() {
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _isLoading = false;
      _currentMessageId = null;
      _currentSpeakingText = null;
      notifyListeners();
    });

    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
  }

  Future<void> setAutoVoice(bool enabled) async {
    _autoVoiceEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_autovoice_enabled', enabled);
    } catch (e) {
      debugPrint('Failed to save auto-voice pref: $e');
    }
  }

  Future<void> setPreferredVoice(String voiceId) async {
    _preferredVoice = voiceId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_character_voice', voiceId);
    } catch (e) {
      debugPrint('Failed to save voice id pref: $e');
    }
  }

  static String cleanDialogueForSpeech(String rawText) {
    if (rawText.isEmpty) return '';
    // Strip intimacy score changes e.g. [INTIMACY: +2]
    var clean = rawText.replaceAll(RegExp(r'\[INTIMACY:[^\]]*\]', caseSensitive: false), '');
    // Strip actions inside *asterisks* (e.g. *chuckles softly*, *reaches out*)
    clean = clean.replaceAll(RegExp(r'\*[^*]+\*'), '');
    clean = clean.replaceAll(RegExp(r'[_#`~]'), '');
    clean = clean.trim();
    if ((clean.startsWith('"') && clean.endsWith('"')) || (clean.startsWith("'") && clean.endsWith("'"))) {
      clean = clean.substring(1, clean.length - 1).trim();
    }
    if (clean.isEmpty) {
      clean = rawText.replaceAll('*', '').trim();
    }
    return clean.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> playDialogue({
    required String characterId,
    required String text,
    String? messageId,
    String? voiceId,
  }) async {
    // If currently playing the exact same message, clicking again acts as toggle/pause
    if (_isPlaying && _currentMessageId != null && _currentMessageId == messageId) {
      await stop();
      return;
    }

    await stop();

    final spokenText = cleanDialogueForSpeech(text);
    if (spokenText.isEmpty) return;

    _isLoading = true;
    _currentMessageId = messageId;
    _currentSpeakingText = spokenText;
    notifyListeners();

    try {
      final effectiveVoice = voiceId ?? _preferredVoice;
      final res = await ApiService.getCharacterSpeech(
        characterId,
        spokenText,
        voiceId: effectiveVoice,
      );

      final audioBase64 = res['audio_base64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        throw Exception('Received empty audio payload from server');
      }

      final bytes = base64Decode(audioBase64);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/character_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      _isLoading = false;
      _isPlaying = true;
      notifyListeners();

      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Error playing character dialogue voice: $e');
      _isLoading = false;
      _isPlaying = false;
      _currentMessageId = null;
      _currentSpeakingText = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping voice player: $e');
    }
    _isPlaying = false;
    _isLoading = false;
    _currentMessageId = null;
    _currentSpeakingText = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
