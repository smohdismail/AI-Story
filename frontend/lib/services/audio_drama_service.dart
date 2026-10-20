import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'ambient_sound_service.dart';

enum DramaRole {
  narrator,
  maleLead,
  femaleLead,
  secondary,
}

class DramaLine {
  final String text;
  final DramaRole role;
  final String speakerName;
  final double pitch;
  final double rate;

  DramaLine({
    required this.text,
    required this.role,
    required this.speakerName,
    required this.pitch,
    required this.rate,
  });
}

class AudioDramaService extends ChangeNotifier {
  static final AudioDramaService instance = AudioDramaService._internal();
  AudioDramaService._internal() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  final AmbientSoundService _ambientService = AmbientSoundService();

  List<DramaLine> _scriptLines = [];
  int _currentLineIndex = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _userSpeed = 0.42;

  String? _storyTitle;
  String? _chapterTitle;
  int? _chapterNumber;
  String? _coverUrl;
  String _currentBgmId = 'piano';

  // Getters
  List<DramaLine> get scriptLines => _scriptLines;
  int get currentLineIndex => _currentLineIndex;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get speed => _userSpeed;
  String? get storyTitle => _storyTitle;
  String? get chapterTitle => _chapterTitle;
  int? get chapterNumber => _chapterNumber;
  String? get coverUrl => _coverUrl;
  String get currentBgmId => _currentBgmId;

  DramaLine? get currentLine =>
      (_scriptLines.isNotEmpty && _currentLineIndex >= 0 && _currentLineIndex < _scriptLines.length)
          ? _scriptLines[_currentLineIndex]
          : null;

  void _initTts() {
    _tts.setSpeechRate(_userSpeed);
    _tts.setCompletionHandler(() {
      _onLineFinished();
    });
    _tts.setErrorHandler((_) {
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
    });
  }

  /// Parses raw chapter text into multi-character drama lines
  List<DramaLine> parseChapter(String rawContent, {List<dynamic>? characters}) {
    final plain = _cleanContent(rawContent);
    if (plain.trim().isEmpty) return [];

    final lines = <DramaLine>[];
    final maleNames = <String>{};
    final femaleNames = <String>{};

    if (characters != null) {
      for (var c in characters) {
        final name = (c['name'] ?? '').toString().trim().toLowerCase();
        final gender = (c['gender'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          if (gender.contains('male') && !gender.contains('female')) {
            maleNames.add(name);
          } else if (gender.contains('female')) {
            femaleNames.add(name);
          }
        }
      }
    }

    // Split text into paragraphs or dialogue segments
    final regex = RegExp(r'([“"”][^“"”]+[“"”])|([^“"”\n]+)');
    final matches = regex.allMatches(plain);

    for (var match in matches) {
      final seg = match.group(0)?.trim() ?? '';
      if (seg.isEmpty) continue;

      if ((seg.startsWith('"') && seg.endsWith('"')) ||
          (seg.startsWith('“') && seg.endsWith('”'))) {
        // Dialogue Line
        final cleanDialogue = seg.substring(1, seg.length - 1).trim();
        if (cleanDialogue.isEmpty) continue;

        // Context search around the match for speaker tag
        final startPos = match.start;
        final endPos = match.end;
        final beforeSnippet = plain.substring((startPos > 40 ? startPos - 40 : 0), startPos).toLowerCase();
        final afterSnippet = plain.substring(endPos, (endPos + 40 < plain.length ? endPos + 40 : plain.length)).toLowerCase();
        final surrounding = '$beforeSnippet $afterSnippet';

        String speaker = 'Narrator';
        DramaRole role = DramaRole.narrator;
        double pitch = 1.0;
        double rate = _userSpeed;

        // Check if any character names appear in surrounding tags
        bool matched = false;
        for (var name in maleNames) {
          if (surrounding.contains(name)) {
            speaker = '${name[0].toUpperCase()}${name.substring(1)}';
            role = DramaRole.maleLead;
            pitch = 0.76; // Deep baritone
            rate = _userSpeed * 0.92;
            matched = true;
            break;
          }
        }

        if (!matched) {
          for (var name in femaleNames) {
            if (surrounding.contains(name)) {
              speaker = '${name[0].toUpperCase()}${name.substring(1)}';
              role = DramaRole.femaleLead;
              pitch = 1.24; // Soft emotive female
              rate = _userSpeed * 0.98;
              matched = true;
              break;
            }
          }
        }

        if (!matched) {
          // Heuristic based on pronouns & dialogue tags
          if (surrounding.contains('he said') ||
              surrounding.contains('he whispered') ||
              surrounding.contains('he asked') ||
              surrounding.contains('his voice') ||
              surrounding.contains('he replied') ||
              surrounding.contains('he growled')) {
            speaker = 'Male Lead (Baritone)';
            role = DramaRole.maleLead;
            pitch = 0.78;
            rate = _userSpeed * 0.92;
          } else if (surrounding.contains('she said') ||
              surrounding.contains('she whispered') ||
              surrounding.contains('she asked') ||
              surrounding.contains('her voice') ||
              surrounding.contains('she replied') ||
              surrounding.contains('she gasped')) {
            speaker = 'Female Lead';
            role = DramaRole.femaleLead;
            pitch = 1.22;
            rate = _userSpeed * 0.98;
          } else {
            // General character dialogue
            speaker = 'Dialogue';
            role = DramaRole.maleLead;
            pitch = 0.85;
            rate = _userSpeed * 0.94;
          }
        }

        lines.add(DramaLine(
          text: cleanDialogue,
          role: role,
          speakerName: speaker,
          pitch: pitch,
          rate: rate,
        ));
      } else {
        // Narration segment
        lines.add(DramaLine(
          text: seg,
          role: DramaRole.narrator,
          speakerName: 'Narrator',
          pitch: 1.0,
          rate: _userSpeed,
        ));
      }
    }

    return lines;
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

  Future<void> startDrama({
    required String rawContent,
    required String chapterTitle,
    int? chapterNumber,
    String? storyTitle,
    String? coverUrl,
    List<dynamic>? characters,
    String bgm = 'piano',
  }) async {
    await stop();

    _chapterTitle = chapterTitle;
    _chapterNumber = chapterNumber;
    _storyTitle = storyTitle;
    _coverUrl = coverUrl;
    _currentBgmId = bgm;
    _scriptLines = parseChapter(rawContent, characters: characters);
    _currentLineIndex = 0;

    if (_scriptLines.isEmpty) return;

    // Start background music at ambient volume
    _startAmbientScore(bgm);

    _isPlaying = true;
    _isPaused = false;
    notifyListeners();

    await _speakCurrentLine();
  }

  void _startAmbientScore(String bgmId) {
    if (bgmId == 'none') {
      _ambientService.stop();
      return;
    }
    final preset = AmbientSoundService.presets.firstWhere(
      (p) => p.id == bgmId,
      orElse: () => AmbientSoundService.presets.first,
    );
    _ambientService.playPreset(preset);
    _ambientService.setVolume(0.18); // Delicate background score level
  }

  Future<void> _speakCurrentLine() async {
    final line = currentLine;
    if (line == null) {
      await stop();
      return;
    }

    await _tts.stop();
    await _tts.setPitch(line.pitch);
    await _tts.setSpeechRate(line.rate);
    notifyListeners();

    await _tts.speak(line.text);
  }

  void _onLineFinished() {
    if (!_isPlaying || _isPaused) return;

    if (_currentLineIndex + 1 < _scriptLines.length) {
      _currentLineIndex++;
      notifyListeners();
      // Brief natural pause between dialogue turns
      Timer(const Duration(milliseconds: 250), () {
        if (_isPlaying && !_isPaused) {
          _speakCurrentLine();
        }
      });
    } else {
      // Completed entire drama
      _isPlaying = false;
      _isPaused = false;
      _ambientService.stop();
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _tts.stop();
      _isPlaying = false;
      _isPaused = true;
      _ambientService.pause();
      notifyListeners();
    } else if (_isPaused) {
      _isPlaying = true;
      _isPaused = false;
      _ambientService.resume();
      notifyListeners();
      await _speakCurrentLine();
    }
  }

  Future<void> nextLine() async {
    if (_currentLineIndex + 1 < _scriptLines.length) {
      _currentLineIndex++;
      await _speakCurrentLine();
    }
  }

  Future<void> previousLine() async {
    if (_currentLineIndex > 0) {
      _currentLineIndex--;
      await _speakCurrentLine();
    } else {
      await _speakCurrentLine();
    }
  }

  Future<void> jumpToLine(int index) async {
    if (index >= 0 && index < _scriptLines.length) {
      _currentLineIndex = index;
      await _speakCurrentLine();
    }
  }

  Future<void> setBgm(String presetId) async {
    _currentBgmId = presetId;
    _startAmbientScore(presetId);
    notifyListeners();
  }

  Future<void> setSpeed(double newSpeed) async {
    _userSpeed = newSpeed;
    if (_isPlaying && currentLine != null) {
      await _tts.setSpeechRate(_userSpeed);
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _tts.stop();
    _ambientService.stop();
    _isPlaying = false;
    _isPaused = false;
    _currentLineIndex = 0;
    notifyListeners();
  }
}
