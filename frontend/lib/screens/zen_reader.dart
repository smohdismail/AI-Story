import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import '../api.dart';

enum ReaderTheme {
  amoled,
  dark,
  sepia,
  light,
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
      if (mounted) setState(() => _isPlaying = false);
    });
    flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await flutterTts.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (_currentContent.trim().isNotEmpty) {
        if (mounted) setState(() => _isPlaying = true);
        await flutterTts.setSpeechRate(_ttsSpeed);
        await flutterTts.setPitch(_ttsPitch);
        await flutterTts.speak(_currentContent);
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
                  const SizedBox(height: 12),
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
                      label: Text(_isPlaying ? 'Stop Reading' : 'Start Reading Aloud'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
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
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        // Check if paragraph is dialogue (starts with quotation mark)
        final isDialogue = trimmed.startsWith('"') || trimmed.startsWith('“') || trimmed.startsWith('\'');

        return Container(
          margin: EdgeInsets.only(bottom: _fontSize * 0.9),
          child: SelectableText(
            trimmed,
            style: textStyle.copyWith(
              color: isDialogue ? dialogueColor : textStyle.color,
              fontStyle: isDialogue ? FontStyle.normal : FontStyle.normal,
            ),
          ),
        );
      }).toList(),
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
      body: GestureDetector(
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
                    // Interactive Next Chapter Choices
                    _buildChoicesWidget(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
