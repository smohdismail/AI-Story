import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ambient_sound_service.dart';
import '../widgets/audio_drama_sheet.dart';
import '../api.dart';

enum ReaderTheme {
  amoled,
  dark,
  sepia,
  light,
  candlelight,
}

class ZenReaderScreen extends StatefulWidget {
  final String title;
  final String content;
  final String? backgroundImage;
  final String? storyId;
  final String? chapterId;
  final String? choicesJson;
  final int? chapterCount;
  final List<Map<String, dynamic>>? allChapters;
  final int? currentIndex;

  const ZenReaderScreen({
    super.key,
    required this.title,
    required this.content,
    this.backgroundImage,
    this.storyId,
    this.chapterId,
    this.choicesJson,
    this.chapterCount,
    this.allChapters,
    this.currentIndex,
  });

  @override
  State<ZenReaderScreen> createState() => _ZenReaderScreenState();
}

class _ZenReaderScreenState extends State<ZenReaderScreen> {
  // Reading Typography & Appearance
  double _fontSize = 18.0;
  double _lineHeight = 1.7;
  String _fontFamily = 'Serif';
  ReaderTheme _readerTheme = ReaderTheme.dark;
  bool _fullscreen = false;

  // Chapter State
  late String _currentTitle;
  late String _currentContent;
  String? _currentChapterId;
  String? _currentStoryId;
  int _currentChapterCount = 0;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _chapters = [];

  // Audio / TTS
  final FlutterTts flutterTts = FlutterTts();
  bool _isPlaying = false;
  double _ttsSpeed = 0.5;
  double _ttsPitch = 1.0;

  // Interactive Story Choices
  List<String> _choices = [];
  bool _loadingChoices = false;
  int? _selectedChoiceIndex;
  final TextEditingController _customChoiceController = TextEditingController();

  // After-Hours Heat Switch & Cinematic Teaser
  bool _isAfterHours = false;
  String? _cachedStandardContent;
  String? _cachedAfterHoursContent;
  bool _isLoadingAfterHours = false;
  Map<String, dynamic>? _chapterTeaser;
  bool _loadingTeaser = false;

  // Ambient Soundscape, Tactile Haptics & What-If Cut
  final AmbientSoundService _ambientService = AmbientSoundService();
  bool _enableHeartbeatHaptics = true;
  Timer? _heartbeatTimer;
  Map<String, dynamic>? _whatIfVignette;
  bool _loadingWhatIf = false;
  bool _loadingSubconscious = false;
  List<dynamic>? _cachedSubconscious;

  // Feature 1: 🔄 POV Flip (Dual-Lens Scene Switcher)
  bool _isPovFlipped = false;
  bool _loadingPovFlip = false;
  Map<String, dynamic>? _cachedPovData;

  // Feature 3: ✍️ Margin Scribbles (Live Reader Co-Authoring)
  bool _loadingMarginSteer = false;

  // Feature 6: 🎧 Dynamic Story Mixtape & Sonic Mood Engine
  Map<String, dynamic>? _cachedSonicScore;
  bool _loadingSonicScore = false;

  // Batch 4: 🎙️ Dual-Cast Audio Drama
  bool _enableDualCast = true;
  String _currentSpeaker = 'Narrator';
  int _audioSegmentIndex = 0;
  List<Map<String, String>> _audioSegments = [];

  // Batch 4: 🕯️ Candlelight & Hearthglow reading animation
  double _candleFlicker = 1.0;
  Timer? _flickerTimer;

  // Batch 4: 📜 Post-Chapter Private Diary
  Map<String, dynamic>? _cachedDiary;
  bool _loadingDiary = false;

  // Feature 7: 💬 Timed Reader Floating Reactions
  List<dynamic> _chapterReactions = [];

  Future<void> _loadReactions() async {
    final cid = _currentChapterId ?? widget.chapterId;
    if (cid == null) return;
    try {
      final list = await ApiService.getChapterReactions(cid);
      if (mounted) setState(() => _chapterReactions = list);
    } catch (_) {}
  }

  void _showReactDialog(int paraIndex, String previewText) {
    final cid = _currentChapterId ?? widget.chapterId;
    if (cid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181720),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final textCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Drop Inline Reader Reaction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                '"$previewText"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['🔥', '😭', '💀', '❤️‍🔥', '🫣', '👑'].map((emoji) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                      await ApiService.addChapterReaction(cid, paragraphIndex: paraIndex, emoji: emoji);
                      _loadReactions();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Whisper a short reaction (e.g. "I can\'t breathe 😭")...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.amber),
                    onPressed: () async {
                      if (textCtrl.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      await ApiService.addChapterReaction(
                        cid,
                        paragraphIndex: paraIndex,
                        emoji: '💬',
                        reactionText: textCtrl.text.trim(),
                      );
                      _loadReactions();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
    _currentContent = _extractPlainText(widget.content);
    _currentChapterId = widget.chapterId;
    _currentStoryId = widget.storyId;
    _currentChapterCount = widget.chapterCount ?? 0;
    _chapters = widget.allChapters ?? [];
    _currentIndex = widget.currentIndex ?? 0;

    _initTts();
    _loadChoices();
    _loadReactions();
    _initCandleFlickerTimer();
  }

  void _initCandleFlickerTimer() {
    _flickerTimer?.cancel();
    _flickerTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_readerTheme == ReaderTheme.candlelight) {
        setState(() {
          _candleFlicker = 0.93 + (DateTime.now().millisecond % 8) * 0.01;
        });
      }
    });
  }

  String _extractPlainText(String raw) {
    if (raw.trim().isEmpty) return "No content in this chapter yet.";
    if (raw.startsWith('[{') && raw.endsWith('}]')) {
      try {
        final List<dynamic> delta = jsonDecode(raw);
        final buffer = StringBuffer();
        for (var op in delta) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert']);
          }
        }
        final res = buffer.toString().trim();
        if (res.isNotEmpty) return res;
      } catch (_) {}
    }
    return raw;
  }

  void _loadChoices() async {
    if (widget.choicesJson != null && widget.choicesJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.choicesJson!);
        if (decoded is List && decoded.isNotEmpty) {
          setState(() {
            _choices = List<String>.from(decoded);
          });
          return;
        }
      } catch (_) {}
    }

    if (_currentStoryId != null && _currentChapterId != null) {
      _fetchChoices();
    }
  }

  Future<void> _fetchChoices() async {
    setState(() => _loadingChoices = true);
    try {
      final choices = await ApiService.generateChapterChoices(_currentStoryId!, _currentChapterId!);
      if (mounted) {
        setState(() {
          _choices = choices;
          _loadingChoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingChoices = false);
      }
    }
  }

  void _initTts() {
    flutterTts.setCompletionHandler(() {
      if (_enableDualCast && _isPlaying && _audioSegments.isNotEmpty) {
        if (_audioSegmentIndex < _audioSegments.length - 1) {
          _audioSegmentIndex++;
          _speakCurrentAudioSegment();
          return;
        }
      }
      _stopHeartbeatHaptics();
      _ambientService.restoreVolume();
      if (mounted) setState(() => _isPlaying = false);
    });
    flutterTts.setErrorHandler((msg) {
      _stopHeartbeatHaptics();
      _ambientService.restoreVolume();
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  List<Map<String, String>> _parseAudioDramaSegments(String text) {
    final segments = <Map<String, String>>[];
    final regex = RegExp(r'("[^"]*?"|[“][^”]*?[”])');
    int lastEnd = 0;
    int dialogueCounter = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        final narration = text.substring(lastEnd, match.start).trim();
        if (narration.isNotEmpty) {
          segments.add({'role': 'narrator', 'text': narration});
        }
      }
      final quote = match.group(0)?.trim() ?? '';
      if (quote.isNotEmpty) {
        final startLookback = (match.start > 60) ? match.start - 60 : 0;
        final endLookahead = (match.end + 60 < text.length) ? match.end + 60 : text.length;
        final contextAround = (text.substring(startLookback, match.start) + ' ' + text.substring(match.end, endLookahead)).toLowerCase();

        String role;
        if (contextAround.contains('she ') || contextAround.contains('her ') || contextAround.contains('elena') || contextAround.contains('whispered she') || contextAround.contains('she said')) {
          role = 'female_lead';
        } else if (contextAround.contains('he ') || contextAround.contains('his ') || contextAround.contains('him ') || contextAround.contains('growled') || contextAround.contains('rasped') || contextAround.contains('alexander')) {
          role = 'male_lead';
        } else {
          role = (dialogueCounter % 2 == 0) ? 'male_lead' : 'female_lead';
        }
        dialogueCounter++;

        final cleanedQuote = quote.replaceAll('"', '').replaceAll('“', '').replaceAll('”', '');
        if (cleanedQuote.trim().isNotEmpty) {
          segments.add({'role': role, 'text': cleanedQuote.trim()});
        }
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        segments.add({'role': 'narrator', 'text': remaining});
      }
    }

    if (segments.isEmpty && text.trim().isNotEmpty) {
      segments.add({'role': 'narrator', 'text': text.trim()});
    }
    return segments;
  }

  Future<void> _speakCurrentAudioSegment() async {
    if (!_isPlaying || _audioSegmentIndex >= _audioSegments.length) {
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final seg = _audioSegments[_audioSegmentIndex];
    final role = seg['role'] ?? 'narrator';
    final text = seg['text'] ?? '';

    if (text.trim().isEmpty) {
      if (_audioSegmentIndex < _audioSegments.length - 1) {
        _audioSegmentIndex++;
        await _speakCurrentAudioSegment();
      }
      return;
    }

    double pitch = _ttsPitch;
    double rate = _ttsSpeed;
    String speakerLabel = 'Narrator';

    if (role == 'male_lead') {
      pitch = (_ttsPitch * 0.76).clamp(0.5, 1.5);
      rate = (_ttsSpeed * 0.94).clamp(0.2, 1.5);
      speakerLabel = 'Male Lead (Deep & Resonant)';
    } else if (role == 'female_lead') {
      pitch = (_ttsPitch * 1.25).clamp(0.5, 1.5);
      rate = (_ttsSpeed * 0.98).clamp(0.2, 1.5);
      speakerLabel = 'Female Lead (Soft & Melodic)';
    } else {
      pitch = (_ttsPitch * 1.0).clamp(0.5, 1.5);
      rate = (_ttsSpeed * 0.92).clamp(0.2, 1.5);
      speakerLabel = 'Narrator (Atmospheric)';
    }

    if (mounted) {
      setState(() {
        _currentSpeaker = speakerLabel;
      });
    }

    await flutterTts.setPitch(pitch);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.speak(text);
  }

  void _triggerHeartbeatHaptic() {
    if (!_enableHeartbeatHaptics) return;
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      HapticFeedback.mediumImpact();
    });
  }

  void _startHeartbeatHaptics() {
    _heartbeatTimer?.cancel();
    if (!_enableHeartbeatHaptics) return;
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (!_enableHeartbeatHaptics || !mounted) {
        t.cancel();
        return;
      }
      _triggerHeartbeatHaptic();
    });
  }

  void _stopHeartbeatHaptics() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      _audioSegments.clear();
      _audioSegmentIndex = 0;
      await flutterTts.stop();
      _stopHeartbeatHaptics();
      _ambientService.restoreVolume();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (_currentContent.trim().isNotEmpty) {
        if (mounted) setState(() => _isPlaying = true);
        _ambientService.duckVolume();
        _startHeartbeatHaptics();

        if (_enableDualCast) {
          _audioSegments = _parseAudioDramaSegments(_currentContent);
          _audioSegmentIndex = 0;
          await _speakCurrentAudioSegment();
        } else {
          await flutterTts.setSpeechRate(_ttsSpeed);
          await flutterTts.setPitch(_ttsPitch);
          await flutterTts.speak(_currentContent);
        }
      }
    }
  }

  void _showTtsSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _getCardColor(),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textColor = _getTextColor();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Audiobook Voice Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(
                          icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.6)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          const Icon(Icons.record_voice_over, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '🎙️ Dual-Cast Audio Drama',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Automatically shifts between deep male cadence, melodic female cadence, and atmospheric narration for dialogue.',
                        style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                      ),
                      value: _enableDualCast,
                      activeColor: Colors.amber,
                      onChanged: (val) {
                        setSheetState(() => _enableDualCast = val);
                        setState(() => _enableDualCast = val);
                      },
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.speed, color: textColor),
                        const SizedBox(width: 12),
                        Text('Speed: ${_ttsSpeed.toStringAsFixed(1)}x', style: TextStyle(color: textColor)),
                        Expanded(
                          child: Slider(
                            value: _ttsSpeed,
                            min: 0.2,
                            max: 1.5,
                            activeColor: Colors.amber,
                            onChanged: (val) {
                              setSheetState(() => _ttsSpeed = val);
                              setState(() => _ttsSpeed = val);
                              flutterTts.setSpeechRate(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.record_voice_over, color: textColor),
                        const SizedBox(width: 12),
                        Text('Pitch: ${_ttsPitch.toStringAsFixed(1)}x', style: TextStyle(color: textColor)),
                        Expanded(
                          child: Slider(
                            value: _ttsPitch,
                            min: 0.5,
                            max: 1.5,
                            activeColor: Colors.amber,
                            onChanged: (val) {
                              setSheetState(() => _ttsPitch = val);
                              setState(() => _ttsPitch = val);
                              flutterTts.setPitch(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _togglePlayback();
                        },
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Stop Reading' : (_enableDualCast ? 'Start Dual-Cast Audio Drama' : 'Start Reading Aloud')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWhisperDialog() {
    if (_currentChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Whisper requires an active saved chapter.')),
      );
      return;
    }

    final quickWhispers = [
      'Pull them close and whisper a teasing challenge: "You think I\'m letting you get away with that?"',
      'Lean in, brushing lips against their ear: "Look at me... say my name."',
      'A soft, vulnerable confession: "Stop running. I can\'t pretend I don\'t want you anymore."',
      'A possessive touch: lace fingers together firmly and pull them against your chest.',
      'A breathless murmur: "Tell me to stop, and I will. But don\'t lie to me."',
    ];

    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: _getCardColor(),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textColor = _getTextColor();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Colors.pinkAccent),
                        SizedBox(width: 8),
                        Text(
                          '💬 Dialogue Whisper',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.6)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Intervene mid-scene! Direct a whispered line or intimate physical gesture to steer character chemistry immediately.',
                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 16),
                const Text('Quick Romantic Whispers & Gestures:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...quickWhispers.map((whisper) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _executeWhisper(whisper);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(whisper, style: const TextStyle(fontSize: 13, height: 1.3)),
                  ),
                )),
                const SizedBox(height: 10),
                const Text('Or Custom Whisper / Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'e.g. Whisper "You look gorgeous when you blush."',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (customCtrl.text.trim().isNotEmpty) {
                          Navigator.pop(ctx);
                          _executeWhisper(customCtrl.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeWhisper(String whisperPrompt) async {
    if (_currentChapterId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.pinkAccent),
            SizedBox(width: 20),
            Expanded(child: Text('AI Director branching scene with your whisper...')),
          ],
        ),
      ),
    );

    try {
      final res = await ApiService.submitDialogueWhisper(
        _currentChapterId!,
        whisperPrompt,
      );

      if (mounted) {
        Navigator.pop(context); // close loading
        final reaction = res['character_reaction'] ?? '';
        final extended = res['extended_scene'] ?? '';
        final branch = [reaction, extended].where((s) => s.toString().trim().isNotEmpty).join('\n\n');

        if (branch.isNotEmpty) {
          setState(() {
            _currentContent += '\n\n— 💬 Directed Whisper: "$whisperPrompt" —\n\n$branch';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Whisper inserted! The characters reacted to your direction.'),
              backgroundColor: Colors.pinkAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to insert whisper: $e')),
        );
      }
    }
  }

  Future<void> _toggleAfterHours() async {
    if (_isAfterHours) {
      setState(() {
        _isAfterHours = false;
        if (_cachedStandardContent != null) {
          _currentContent = _cachedStandardContent!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to Standard Story Cut')),
      );
      return;
    }

    _cachedStandardContent = _currentContent;
    if (_cachedAfterHoursContent != null) {
      setState(() {
        _isAfterHours = true;
        _currentContent = _cachedAfterHoursContent!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔥 Switched to Uncensored After-Hours Heat Cut!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_currentChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active chapter required for After-Hours cut.')),
      );
      return;
    }

    setState(() => _isLoadingAfterHours = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔥 Generating Uncensored After-Hours Heat Cut...')),
    );

    try {
      final res = await ApiService.generateAfterHoursCut(_currentChapterId!);
      final afterHoursText = res['after_hours_content'] ?? _currentContent;
      if (mounted) {
        setState(() {
          _isAfterHours = true;
          _isLoadingAfterHours = false;
          _cachedAfterHoursContent = afterHoursText;
          _currentContent = afterHoursText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔥 After-Hours Explicit Cut Active!'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAfterHours = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ==========================================
  // FEATURE 1: 🔄 "POV FLIP" (DUAL-LENS SCENE SWITCHER)
  // ==========================================

  Future<void> _togglePovFlip() async {
    if (_isPovFlipped) {
      setState(() {
        _isPovFlipped = false;
        if (_cachedStandardContent != null) {
          _currentContent = _cachedStandardContent!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched back to Canonical POV')),
      );
      return;
    }

    _cachedStandardContent = _currentContent;
    if (_cachedPovData != null) {
      setState(() {
        _isPovFlipped = true;
        _currentContent = _cachedPovData!['pov_prose'] ?? _currentContent;
      });
      _triggerHeartbeatHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Switched to ${_cachedPovData!['character_name'] ?? 'His'}\'s POV Lens!'),
          backgroundColor: Colors.cyan.shade800,
        ),
      );
      return;
    }

    if (_currentChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active chapter required for POV Flip.')),
      );
      return;
    }

    setState(() => _loadingPovFlip = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 Flipping Scene to His Perspective & Hidden Thoughts...')),
    );

    try {
      final res = await ApiService.generatePovFlip(_currentChapterId!);
      final povData = res['pov_data'] as Map<String, dynamic>?;
      if (mounted && povData != null) {
        setState(() {
          _cachedPovData = povData;
          _isPovFlipped = true;
          _loadingPovFlip = false;
          _currentContent = povData['pov_prose'] ?? _currentContent;
        });
        _triggerHeartbeatHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔄 Switched to ${povData['character_name'] ?? 'His'}\'s POV Lens!'),
            backgroundColor: Colors.cyan.shade800,
          ),
        );
      } else {
        setState(() => _loadingPovFlip = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPovFlip = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error flipping POV: $e')));
      }
    }
  }

  // ==========================================
  // FEATURE 3: ✍️ "MARGIN SCRIBBLES" (LIVE CO-AUTHORING)
  // ==========================================

  void _showMarginScribbleDialog({String? initialParagraph}) {
    final TextEditingController scribbleCtrl = TextEditingController();
    final sampleParagraph = initialParagraph ?? (_currentContent.length > 250 ? _currentContent.substring(_currentContent.length - 250) : _currentContent);

    final impulsePresets = [
      'Make him pull her close before she can step away',
      'Have him whisper his suppressed confession in her ear',
      'Spark intense jealousy with razor-sharp dialogue',
      'Make their hands touch as their breath catches',
      'Let his calm facade break with desperate longing',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13101E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.drive_file_rename_outline, color: Colors.amberAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✍️ Margin Scribble (Steer Scene)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent)),
                        Text('Scribble your desire in the margin to steer the narrative live.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Current Margin Scene:\n"${sampleParagraph.trim()}"',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Romantic Impulse Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: impulsePresets.map((p) => ActionChip(
                  backgroundColor: Colors.amber.shade900.withValues(alpha: 0.25),
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                  label: Text(p, style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                  onPressed: () {
                    scribbleCtrl.text = p;
                    setModalState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scribbleCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Or scribble your own custom desire (e.g. "Don\'t let him leave cold")...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadingMarginSteer ? null : () async {
                  final text = scribbleCtrl.text.trim();
                  if (text.isEmpty || _currentChapterId == null) return;
                  Navigator.pop(ctx);
                  _executeMarginSteer(sampleParagraph, text);
                },
                icon: _loadingMarginSteer 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_loadingMarginSteer ? 'Weaving into Scene...' : 'Weave Scribble into Scene ✍️'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeMarginSteer(String contextParagraph, String scribble) async {
    if (_currentChapterId == null) return;
    setState(() => _loadingMarginSteer = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✍️ Weaving "$scribble" into the story...'),
        backgroundColor: Colors.amber.shade900,
      ),
    );

    try {
      final res = await ApiService.steerChapterFromMargin(
        _currentChapterId!,
        paragraphContext: contextParagraph,
        readerScribble: scribble,
      );
      final steerResult = res['steer_result'] as Map<String, dynamic>?;
      if (mounted && steerResult != null) {
        final prose = steerResult['continuation_prose'] ?? '';
        setState(() {
          _loadingMarginSteer = false;
          _currentContent += '\n\n— ✍️ Reader Margin Scribble: "$scribble" —\n\n$prose';
        });
        _triggerHeartbeatHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Scene steered with your margin scribble!'),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        setState(() => _loadingMarginSteer = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMarginSteer = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error steering scene: $e')));
      }
    }
  }

  Future<void> _fetchChapterTeaser() async {
    if (_currentChapterId == null) return;
    setState(() => _loadingTeaser = true);
    try {
      final teaser = await ApiService.getChapterTeaser(_currentChapterId!);
      if (mounted) {
        setState(() {
          _chapterTeaser = teaser;
          _loadingTeaser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTeaser = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating teaser: $e')));
      }
    }
  }

  Widget _buildTeaserCard() {
    final textColor = _getTextColor();
    final cardColor = _getCardColor();

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.movie_filter, color: Colors.redAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Next On... Cinematic Teaser',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                    ),
                  ],
                ),
                if (_chapterTeaser == null)
                  ElevatedButton.icon(
                    onPressed: _loadingTeaser ? null : _fetchChapterTeaser,
                    icon: _loadingTeaser
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 14),
                    label: Text(_loadingTeaser ? 'Drafting...' : 'Reveal Teaser 🎬', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            if (_chapterTeaser != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chapterTeaser!['dramatic_quote'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.amberAccent,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _chapterTeaser!['stakes_summary'] ?? '',
                      style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.8), height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _chapterTeaser!['cliffhanger_level'] ?? '🔥 High Tension',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _fetchChapterTeaser,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Re-roll Teaser', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BATCH 4 FEATURE: 📜 THE CHARACTER'S PRIVATE DIARY
  // ==========================================

  Widget _buildCrossedOutText(String text, {double fontSize = 14, Color defaultColor = Colors.white}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'~~(.*?)~~');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(fontSize: fontSize, color: defaultColor, height: 1.5),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white38,
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.redAccent,
          decorationThickness: 2.0,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(fontSize: fontSize, color: defaultColor, height: 1.5),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<void> _fetchPrivateDiary() async {
    if (_currentChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active chapter required to open character diary.')),
      );
      return;
    }

    if (_cachedDiary != null) {
      _showPrivateDiarySheet();
      return;
    }

    setState(() => _loadingDiary = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unlocking character private journal...')),
    );

    try {
      final res = await ApiService.getChapterPrivateDiary(_currentChapterId!);
      if (mounted) {
        setState(() {
          _cachedDiary = res['diary'];
          _loadingDiary = false;
        });
        _showPrivateDiarySheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDiary = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not unlock diary: $e')));
      }
    }
  }

  void _showPrivateDiarySheet() {
    if (_cachedDiary == null) return;
    final diary = _cachedDiary!;
    final characterName = diary['character_name'] ?? 'Character';
    final dateStamp = diary['date_stamp'] ?? 'Late Night';
    final location = diary['location'] ?? 'Secluded Room';
    final rawConfession = diary['raw_confession'] ?? '';
    final hesitations = (diary['crossed_out_hesitations'] as List<dynamic>?) ?? [];
    final intensity = diary['emotional_intensity'] ?? 'Unguarded Vulnerability';
    final marginNote = diary['margin_note'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1108),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          maxChildSize: 0.94,
          minChildSize: 0.45,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1108),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 1.5),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(22),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('📜', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$characterName\'s Private Diary',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFDE68A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '$dateStamp • $location',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.pinkAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Tension & Intensity: $intensity',
                          style: const TextStyle(fontSize: 12, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Diary Paper Sheet
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28180E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8D5B2A).withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🖋️ Written by candlelight behind locked doors',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFD4AF37))),
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF3E2723), shape: BoxShape.circle),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF5D4037), height: 24),
                        _buildCrossedOutText(
                          rawConfession,
                          fontSize: 15,
                          defaultColor: const Color(0xFFFDF0CD),
                        ),
                        if (hesitations.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scratched-out Lines (Censored Hesitations):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                ),
                                const SizedBox(height: 6),
                                ...hesitations.map((h) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    '• "$h"',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white60,
                                      decoration: TextDecoration.lineThrough,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                        if (marginNote.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF331F10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📌 Margin note:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"$marginNote"',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFFFDE68A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.lock, size: 16),
                    label: const Text('Lock Diary & Return to Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF78350F),
                      foregroundColor: const Color(0xFFFDE68A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivateDiaryCard() {
    final textColor = _getTextColor();
    final cardColor = _getCardColor();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📜 Character\'s Private Diary Entry',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadingDiary ? null : _fetchPrivateDiary,
                  icon: _loadingDiary
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open, size: 14),
                  label: Text(_cachedDiary == null ? 'Unlock Diary' : 'Read Journal', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Discover what the male lead penned in secret right after this chapter occurred—raw feelings, crossed-out regrets, and ink-stained confessions.',
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FEATURE 2: SENSORY AMBIENT SOUNDSCAPES
  // ==========================================

  void _showAmbientSoundSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.tealAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Sensory Ambient Soundscapes',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const Spacer(),
                      if (_ambientService.isPlaying)
                        TextButton.icon(
                          onPressed: () {
                            _ambientService.stop();
                            setSheetState(() {});
                            setState(() {});
                          },
                          icon: const Icon(Icons.stop, color: Colors.redAccent, size: 16),
                          label: const Text('Mute', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Atmospheric sound loops & emotional soundtracks playing softly behind your novel.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  // Feature 6: Dynamic Story Mixtape & Sonic Mood Score
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade900.withValues(alpha: 0.4), Colors.purple.shade900.withValues(alpha: 0.4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Dynamic Chapter Sonic Mood',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                            ),
                            const Spacer(),
                            if (_cachedSonicScore == null)
                              ElevatedButton(
                                onPressed: _loadingSonicScore ? null : () async {
                                  if (_currentChapterId == null) return;
                                  setSheetState(() => _loadingSonicScore = true);
                                  try {
                                    final res = await ApiService.getSonicScore(_currentChapterId!);
                                    setSheetState(() {
                                      _cachedSonicScore = res;
                                      _loadingSonicScore = false;
                                    });
                                  } catch (e) {
                                    setSheetState(() => _loadingSonicScore = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(_loadingSonicScore ? 'Scoring...' : 'Analyze Chapter Score 🎧', style: const TextStyle(fontSize: 10)),
                              ),
                          ],
                        ),
                        if (_cachedSonicScore != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _cachedSonicScore!['soundtrack_title'] ?? 'Chapter Score',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_cachedSonicScore!['dominant_genre']} • ${_cachedSonicScore!['tempo']}',
                            style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                          ),
                          if (_cachedSonicScore!['music_director_note'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _cachedSonicScore!['music_director_note'],
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.white70),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final presetKey = _cachedSonicScore!['preset_key'] ?? 'piano';
                              final targetPreset = AmbientSoundService.presets.firstWhere(
                                (p) => p.id == presetKey,
                                orElse: () => AmbientSoundService.presets.first,
                              );
                              await _ambientService.playPreset(targetPreset);
                              setSheetState(() {});
                              setState(() {});
                            },
                            icon: const Icon(Icons.play_circle_fill, size: 16),
                            label: const Text('Play Recommended Chapter Score', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Volume Slider
                  Row(
                    children: [
                      const Icon(Icons.volume_down, size: 16, color: Colors.tealAccent),
                      Expanded(
                        child: Slider(
                          value: _ambientService.volume,
                          min: 0.0,
                          max: 1.0,
                          activeColor: Colors.tealAccent,
                          onChanged: (v) {
                            _ambientService.setVolume(v);
                            setSheetState(() {});
                            setState(() {});
                          },
                        ),
                      ),
                      Text('${(_ambientService.volume * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.tealAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Presets List
                  ...AmbientSoundService.presets.map((p) {
                    final isSelected = _ambientService.isPlaying && _ambientService.currentPreset?.id == p.id;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.white10,
                        child: Text(p.icon, style: const TextStyle(fontSize: 18)),
                      ),
                      title: Text(p.name, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(p.description, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      trailing: isSelected
                          ? const Icon(Icons.graphic_eq, color: Colors.tealAccent)
                          : const Icon(Icons.play_arrow, color: Colors.white38),
                      onTap: () async {
                        if (isSelected) {
                          await _ambientService.stop();
                        } else {
                          await _ambientService.playPreset(p);
                        }
                        setSheetState(() {});
                        setState(() {});
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // FEATURE 3: "WHAT-IF" ALTERNATE ROMANCE CUTS
  // ==========================================

  void _showWhatIfDialog() {
    final TextEditingController scenarioCtrl = TextEditingController();
    final presets = [
      'What if he pulled her back before she got into the rain?',
      'What if they gave in to temptation during the midnight blackout?',
      'What if she confessed her secret instead of running away?',
      'What if they were forced to share a single bed at the inn?',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF140E1B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('🔀 "What-If" Alternate Romance Cut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore a forbidden alternate path without changing your canon novel timeline.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: presets.map((p) => ActionChip(
                  backgroundColor: Colors.purple.shade900.withValues(alpha: 0.35),
                  label: Text(p, style: const TextStyle(fontSize: 11, color: Colors.pinkAccent)),
                  onPressed: () {
                    scenarioCtrl.text = p;
                    setModalState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scenarioCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Or describe your own crossroad scenario...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadingWhatIf ? null : () async {
                  if (scenarioCtrl.text.trim().isEmpty || _currentChapterId == null) return;
                  Navigator.pop(ctx);
                  _executeWhatIf(scenarioCtrl.text.trim());
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate Alternate Cut'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeWhatIf(String scenario) async {
    if (_currentChapterId == null) return;
    setState(() => _loadingWhatIf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔀 Generating alternate romance timeline...')),
    );

    try {
      final res = await ApiService.generateWhatIfVignette(_currentChapterId!, scenario: scenario);
      if (mounted) {
        setState(() {
          _whatIfVignette = res['vignette'];
          _loadingWhatIf = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alternate romance cut generated!'), backgroundColor: Colors.purple),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingWhatIf = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate what-if cut: $e')));
      }
    }
  }

  Widget _buildWhatIfCard() {
    final textColor = _getTextColor();
    final cardColor = _getCardColor();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Card(
        color: cardColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.purpleAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '🔀 "What-If" Alternate Romance Cut',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showWhatIfDialog,
                    icon: _loadingWhatIf
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 14),
                    label: Text(_whatIfVignette == null ? 'Explore Cut' : 'New Cut', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Explore what would happen if the leads took an alternate, passionate crossroad in this scene.',
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
              ),
              if (_whatIfVignette != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _whatIfVignette!['vignette_title'] ?? 'Alternate Cut',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.pinkAccent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '⚡ Divergence Point: "${_whatIfVignette!['divergence_point'] ?? ''}"',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _whatIfVignette!['alternate_prose'] ?? '',
                        style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
                      ),
                      if (_whatIfVignette!['emotional_aftermath'] != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🥀 Aftermath: ${_whatIfVignette!['emotional_aftermath']}',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MIND READER: CHARACTER SUBCONSCIOUS & INNER MONOLOGUE
  // ==========================================

  Future<void> _showSubconsciousSheet() async {
    if (_currentChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active chapter required to read character subconscious.')),
      );
      return;
    }

    if (_cachedSubconscious == null) {
      setState(() => _loadingSubconscious = true);
      try {
        final moments = await ApiService.getCharacterSubconscious(_currentChapterId!);
        if (mounted) {
          setState(() {
            _cachedSubconscious = moments;
            _loadingSubconscious = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loadingSubconscious = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reading subconscious: $e')));
          return;
        }
      }
    }

    if (!mounted || _cachedSubconscious == null || _cachedSubconscious!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🧠', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Character Mind Reader',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber),
                            ),
                            Text(
                              'Hidden subconscious thoughts, racing pulses, and unspoken truths.',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  ..._cachedSubconscious!.map((m) {
                    final item = m as Map<String, dynamic>;
                    final charName = item['character_name'] ?? 'Lead';
                    final spoken = item['spoken_dialogue'] ?? '';
                    final contextNote = item['spoken_context'] ?? '';
                    final subconscious = item['hidden_subconscious'] ?? '';
                    final tell = item['physical_tell'] ?? '';
                    final unspoken = item['unspoken_desire'] ?? '';
                    final vuln = (item['vulnerability_percentage'] ?? 85) as num;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('🎭 $charName', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 14)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('❤️ Vulnerability: $vuln%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                          if (contextNote.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('📍 $contextNote', style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🗣️ ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text('“$spoken”', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Inner Subconscious Monologue:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                          const SizedBox(height: 4),
                          Text(subconscious, style: const TextStyle(fontSize: 12, height: 1.45, color: Colors.white)),
                          if (tell.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💓 Physical Tell: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                                Expanded(child: Text(tell, style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic))),
                              ],
                            ),
                          ],
                          if (unspoken.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🔒 Unspoken Desire: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
                                Expanded(child: Text('“$unspoken”', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontStyle: FontStyle.italic))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMindReaderButtonCard() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade900.withValues(alpha: 0.35), Colors.purple.shade900.withValues(alpha: 0.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loadingSubconscious ? null : _showSubconsciousSheet,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🧠', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mind Reader: Inner Monologue',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to reveal characters’ hidden racing pulses, secret jealousy, and unspoken thoughts.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _loadingSubconscious
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent))
                    : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.amberAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppearanceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _getCardColor(),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textColor = _getTextColor();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  // Themes row
                  Text('Background Theme', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildThemeChip('🕯️ Candlelight', ReaderTheme.candlelight, const Color(0xFF241408), const Color(0xFFFEE685), setSheetState),
                      _buildThemeChip('AMOLED', ReaderTheme.amoled, Colors.black, Colors.white, setSheetState),
                      _buildThemeChip('Dark', ReaderTheme.dark, const Color(0xFF1E1E2E), Colors.white, setSheetState),
                      _buildThemeChip('Sepia', ReaderTheme.sepia, const Color(0xFFF7EFE2), const Color(0xFF4A3728), setSheetState),
                      _buildThemeChip('Light', ReaderTheme.light, const Color(0xFFFAFAFA), const Color(0xFF222222), setSheetState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Font Size
                  Row(
                    children: [
                      Text('Font Size: ${_fontSize.toInt()}pt', style: TextStyle(color: textColor)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: textColor),
                        onPressed: () {
                          if (_fontSize > 12) {
                            setSheetState(() => _fontSize -= 1);
                            setState(() => _fontSize -= 1);
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: textColor),
                        onPressed: () {
                          if (_fontSize < 34) {
                            setSheetState(() => _fontSize += 1);
                            setState(() => _fontSize += 1);
                          }
                        },
                      ),
                    ],
                  ),
                  // Font Family
                  Row(
                    children: [
                      Text('Font Family', style: TextStyle(color: textColor)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _fontFamily,
                        dropdownColor: _getCardColor(),
                        style: TextStyle(color: textColor),
                        items: ['Serif', 'Sans', 'Monospace'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => _fontFamily = val);
                            setState(() => _fontFamily = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
                        const SizedBox(width: 8),
                        Text('Tactile Heartbeat & Breath Haptics', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Text('Simulate physical heartbeat pulses during intense romantic scenes', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
                    value: _enableHeartbeatHaptics,
                    activeColor: Colors.pinkAccent,
                    onChanged: (val) {
                      setSheetState(() => _enableHeartbeatHaptics = val);
                      setState(() => _enableHeartbeatHaptics = val);
                      if (val) _triggerHeartbeatHaptic();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeChip(String label, ReaderTheme theme, Color bg, Color text, StateSetter setSheetState) {
    final isSelected = _readerTheme == theme;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _readerTheme = theme);
        setState(() => _readerTheme = theme);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(color: text, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_readerTheme) {
      case ReaderTheme.amoled:
        return Colors.black;
      case ReaderTheme.dark:
        return const Color(0xFF16161F);
      case ReaderTheme.sepia:
        return const Color(0xFFF7EFE2);
      case ReaderTheme.light:
        return const Color(0xFFFAFAFA);
      case ReaderTheme.candlelight:
        return const Color(0xFF140B04); // Deep smoky warm hearth
    }
  }

  Color _getCardColor() {
    switch (_readerTheme) {
      case ReaderTheme.amoled:
        return const Color(0xFF1E1E1E);
      case ReaderTheme.dark:
        return const Color(0xFF222233);
      case ReaderTheme.sepia:
        return const Color(0xFFEFE2CE);
      case ReaderTheme.light:
        return const Color(0xFFEEEEEE);
      case ReaderTheme.candlelight:
        return const Color(0xFF241408); // Warm dark amber hearth
    }
  }

  Color _getTextColor() {
    switch (_readerTheme) {
      case ReaderTheme.amoled:
      case ReaderTheme.dark:
        return const Color(0xFFE8E8E8);
      case ReaderTheme.sepia:
        return const Color(0xFF382918);
      case ReaderTheme.light:
        return const Color(0xFF1A1A1A);
      case ReaderTheme.candlelight:
        return const Color(0xFFFEE685); // Warm flickering golden amber
    }
  }

  Color _getDialogueColor() {
    switch (_readerTheme) {
      case ReaderTheme.amoled:
      case ReaderTheme.dark:
        return const Color(0xFFFFD54F);
      case ReaderTheme.sepia:
        return const Color(0xFF8B4513);
      case ReaderTheme.light:
        return const Color(0xFF1565C0);
      case ReaderTheme.candlelight:
        return const Color(0xFFF59E0B); // Vibrant molten honey
    }
  }

  TextStyle _getTextStyle() {
    TextStyle base;
    switch (_fontFamily) {
      case 'Monospace':
        base = const TextStyle(fontFamily: 'monospace');
        break;
      case 'Sans':
        base = const TextStyle(fontFamily: 'sans-serif');
        break;
      case 'Serif':
      default:
        base = const TextStyle(fontFamily: 'serif');
        break;
    }
    return base.copyWith(
      fontSize: _fontSize,
      height: _lineHeight,
      color: _getTextColor(),
      letterSpacing: 0.3,
    );
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    flutterTts.stop();
    final ch = _chapters[index];
    setState(() {
      _currentIndex = index;
      _currentTitle = ch['title'] ?? 'Chapter ${ch['chapter_number']}';
      _currentContent = _extractPlainText(ch['content'] ?? '');
      _currentChapterId = ch['id']?.toString();
      _choices = [];
      _selectedChoiceIndex = null;
      _isPlaying = false;
      _isAfterHours = false;
      _cachedStandardContent = null;
      _cachedAfterHoursContent = null;
      _chapterTeaser = null;
      _whatIfVignette = null;
      _cachedSubconscious = null;
      _isPovFlipped = false;
      _cachedPovData = null;
      _cachedSonicScore = null;
    });

    if (ch['choices_json'] != null) {
      try {
        final decoded = jsonDecode(ch['choices_json']);
        if (decoded is List && decoded.isNotEmpty) {
          setState(() {
            _choices = List<String>.from(decoded);
          });
          return;
        }
      } catch (_) {}
    }
    if (_currentStoryId != null && _currentChapterId != null) {
      _fetchChoices();
    }
  }

  void _submitChoice() {
    String choiceText = '';
    if (_selectedChoiceIndex != null && _selectedChoiceIndex! < _choices.length) {
      choiceText = _choices[_selectedChoiceIndex!];
    } else if (_customChoiceController.text.trim().isNotEmpty) {
      choiceText = _customChoiceController.text.trim();
    }

    if (choiceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or write a choice to continue the story.')),
      );
      return;
    }

    if (_currentStoryId != null) {
      context.push('/story/$_currentStoryId/director', extra: {
        'chapterCount': _currentChapterCount,
        'initialPrompt': 'Continue the story based on this choice: $choiceText',
        'selectedChoice': choiceText,
      });
    }
  }

  @override
  void dispose() {
    _flickerTimer?.cancel();
    _stopHeartbeatHaptics();
    _ambientService.stop();
    flutterTts.stop();
    _customChoiceController.dispose();
    super.dispose();
  }

  Widget _buildNovelBody() {
    final paragraphs = _currentContent.split(RegExp(r'\n\s*\n|\r\n\s*\r\n'));
    final textStyle = _getTextStyle();
    final dialogueColor = _getDialogueColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Action Bar for Novel Immersion: POV Flip & Margin Scribble
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _loadingPovFlip ? null : _togglePovFlip,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isPovFlipped ? Colors.cyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPovFlipped ? Colors.cyanAccent : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _loadingPovFlip
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                            : Icon(Icons.sync_alt, size: 14, color: _isPovFlipped ? Colors.cyanAccent : Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          _isPovFlipped ? '🔄 ${_cachedPovData?['character_name'] ?? 'His'} POV (Active)' : '🔄 Switch to His POV',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isPovFlipped ? Colors.cyanAccent : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showMarginScribbleDialog(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drive_file_rename_outline, size: 14, color: Colors.amberAccent),
                        SizedBox(width: 6),
                        Text(
                          '✍️ Whisper to Story',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // POV Flip Active Header Banner
        if (_isPovFlipped && _cachedPovData != null)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.shade900.withValues(alpha: 0.35), Colors.black54],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.cyanAccent, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cachedPovData!['pov_title'] ?? 'His Perspective Lens',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.cyanAccent),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💓 ${_cachedPovData!['heart_rate_bpm'] ?? 140} BPM',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_cachedPovData!['internal_emotion'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Inner State: ${_cachedPovData!['internal_emotion']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
                if (_cachedPovData!['unspoken_confession'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${_cachedPovData!['unspoken_confession']}"',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                  ),
                ],
              ],
            ),
          ),

        // Paragraphs of Novel with Floating Reactions
        ...paragraphs.asMap().entries.map((entry) {
          final index = entry.key;
          final para = entry.value;
          final trimmed = para.trim();
          if (trimmed.isEmpty) return const SizedBox.shrink();

          final isDialogue = trimmed.startsWith('"') || trimmed.startsWith('“') || trimmed.startsWith('\'');
          final paraReactions = _chapterReactions.where((r) => r['paragraph_index'] == index).toList();

          return Container(
            margin: EdgeInsets.only(bottom: _fontSize * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        trimmed,
                        style: textStyle.copyWith(
                          color: isDialogue ? dialogueColor : textStyle.color,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_reaction_outlined, size: 14, color: Colors.white24),
                      tooltip: 'Drop reaction',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showReactDialog(index, trimmed),
                    ),
                  ],
                ),
                if (paraReactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: paraReactions.map((r) {
                        final text = r['reaction_text'] as String?;
                        final emoji = r['emoji'] ?? '🔥';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 12)),
                              if (text != null && text.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  text,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),

        // Interactive Margin Scribble Trigger Card at end of scene
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.border_color, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Want to alter what happens here?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                    Text('Scribble a margin direction to steer the next lines in real time.', style: TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showMarginScribbleDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('✍️ Scribble', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoicesWidget() {
    if (_currentStoryId == null) return const SizedBox.shrink();

    final textColor = _getTextColor();
    final cardColor = _getCardColor();

    return Container(
      margin: const EdgeInsets.only(top: 36, bottom: 48),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: Colors.amber, size: 26),
              SizedBox(width: 10),
              Text(
                'What happens next?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the narrative path or write your own custom decision for the next chapter:',
            style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 16),
          if (_loadingChoices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 12),
                    Text('AI dreaming up next story choices...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else ...[
            ...List.generate(_choices.length, (index) {
              final isSelected = _selectedChoiceIndex == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedChoiceIndex = isSelected ? null : index;
                      _customChoiceController.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber.withValues(alpha: 0.2) : _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _choices[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _customChoiceController,
              onChanged: (text) {
                if (text.isNotEmpty && _selectedChoiceIndex != null) {
                  setState(() => _selectedChoiceIndex = null);
                }
              },
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Or write your own custom path...',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.edit_note, color: Colors.amber),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _getBackgroundColor(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitChoice,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Continue Story with Choice', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterNavigation() {
    if (_chapters.isEmpty) return const SizedBox.shrink();

    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < _chapters.length - 1;
    final textColor = _getTextColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: hasPrev ? () => _goToChapter(_currentIndex - 1) : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous Chapter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getCardColor(),
              foregroundColor: textColor,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          Text(
            '${_currentIndex + 1} / ${_chapters.length}',
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            onPressed: hasNext ? () => _goToChapter(_currentIndex + 1) : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Chapter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final textColor = _getTextColor();
    final wordCount = _currentContent.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final readTimeMinutes = (wordCount / 220).ceil();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
              title: Text(_currentTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              actions: [
                IconButton(
                  icon: _loadingPovFlip
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                        )
                      : Icon(
                          _isPovFlipped ? Icons.sync_alt : Icons.switch_account_outlined,
                          color: _isPovFlipped ? Colors.cyanAccent : textColor,
                        ),
                  tooltip: _isPovFlipped ? 'Switch Back to Main POV' : '🔄 POV Flip (His Perspective)',
                  onPressed: _loadingPovFlip ? null : _togglePovFlip,
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline, color: Colors.amberAccent),
                  tooltip: '✍️ Margin Scribble (Steer Scene)',
                  onPressed: () => _showMarginScribbleDialog(),
                ),
                IconButton(
                  icon: _isLoadingAfterHours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrangeAccent),
                        )
                      : Icon(
                          _isAfterHours ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                          color: _isAfterHours ? Colors.deepOrangeAccent : Colors.pinkAccent,
                        ),
                  tooltip: _isAfterHours ? '🔥 After-Hours Active (Tap for Standard)' : '🔥 Switch to After-Hours Cut',
                  onPressed: _isLoadingAfterHours ? null : _toggleAfterHours,
                ),
                IconButton(
                  icon: _loadingSubconscious
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                        )
                      : const Icon(Icons.remove_red_eye_outlined, color: Colors.amberAccent),
                  tooltip: '🧠 Mind Reader (Character Subconscious)',
                  onPressed: _loadingSubconscious ? null : _showSubconsciousSheet,
                ),
                IconButton(
                  icon: Icon(
                    _ambientService.isPlaying ? Icons.music_note : Icons.music_note_outlined,
                    color: _ambientService.isPlaying ? Colors.tealAccent : textColor,
                  ),
                  tooltip: _ambientService.isPlaying ? 'Sensory Ambient (Playing)' : 'Sensory Ambient Soundscapes',
                  onPressed: _showAmbientSoundSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.record_voice_over, color: Colors.pinkAccent),
                  tooltip: '💬 Mid-Scene Dialogue Whisper',
                  onPressed: _showWhisperDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.spatial_audio_off_outlined, color: Colors.purpleAccent),
                  tooltip: 'Full-Cast Audio Drama 🎙️',
                  onPressed: () {
                    flutterTts.stop();
                    AudioDramaSheet.show(
                      context,
                      rawContent: _currentContent,
                      chapterTitle: _currentTitle,
                      chapterNumber: widget.currentIndex != null ? widget.currentIndex! + 1 : 1,
                      storyTitle: _currentTitle,
                      coverUrl: widget.backgroundImage,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.stop_circle : Icons.headphones, color: _isPlaying ? Colors.redAccent : textColor),
                  tooltip: 'Audiobook Reader',
                  onPressed: _togglePlayback,
                ),
                IconButton(
                  icon: Icon(Icons.tune, color: textColor),
                  tooltip: 'Voice Settings',
                  onPressed: _showTtsSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.theater_comedy, color: Colors.purpleAccent),
                  tooltip: 'Visual Novel Mode',
                  onPressed: () {
                    context.push('/visual_novel', extra: {
                      'title': _currentTitle,
                      'content': _currentContent,
                      'backgroundImage': widget.backgroundImage,
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.format_size, color: textColor),
                  tooltip: 'Text & Theme Appearance',
                  onPressed: _showAppearanceSettings,
                ),
                IconButton(
                  icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: textColor),
                  tooltip: 'Toggle Fullscreen',
                  onPressed: () => setState(() => _fullscreen = !_fullscreen),
                ),
              ],
            ),
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTap: () => setState(() => _fullscreen = !_fullscreen),
            child: Container(
              color: bgColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // If Dual-Cast is playing, show live audio indicator banner
                        if (_isPlaying && _enableDualCast)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amberAccent, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.graphic_eq, color: Colors.amberAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '🎙️ Dual-Cast Audio Drama: $_currentSpeaker',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 20),
                                  onPressed: _togglePlayback,
                                  tooltip: 'Stop Audio Drama',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        // Chapter Title Header
                        Text(
                          _currentTitle,
                          style: TextStyle(
                            fontSize: _fontSize * 1.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: _fontFamily,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              '~ $readTimeMinutes min read • $wordCount words',
                              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
                            ),
                            if (_fullscreen) ...[
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => setState(() => _fullscreen = false),
                                icon: const Icon(Icons.fullscreen_exit, size: 14),
                                label: const Text('Exit Fullscreen', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 32),
                        // Story Content Body
                        _buildNovelBody(),
                        // Previous / Next Chapter Buttons
                        _buildChapterNavigation(),
                        // Mind Reader Button Card
                        _buildMindReaderButtonCard(),
                        // Cinematic Chapter Teasers & Cliffhangers
                        _buildTeaserCard(),
                        // "The Character's Private Diary" Entry Card
                        _buildPrivateDiaryCard(),
                        // "What-If" Alternate Romance Cuts
                        _buildWhatIfCard(),
                        // Interactive Next Chapter Choices
                        _buildChoicesWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Candlelight & Hearthglow warm flickering illumination layer
          if (_readerTheme == ReaderTheme.candlelight)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _candleFlicker,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.15,
                        colors: [
                          Colors.transparent,
                          Color(0x22F59E0B),
                          Color(0x66140B04),
                        ],
                        stops: [0.5, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWhisperDialog,
        icon: const Icon(Icons.record_voice_over, color: Colors.white, size: 20),
        label: const Text('💬 Whisper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink.shade700,
      ),
    );
  }
}
