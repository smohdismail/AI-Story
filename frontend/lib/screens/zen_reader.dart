import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_tts/flutter_tts.dart';
import '../api.dart';

class ZenReaderScreen extends StatefulWidget {
  final String title;
  final String content;
  final String? backgroundImage;
  final String? storyId;
  final String? chapterId;
  final String? choicesJson;
  final int? chapterCount;

  const ZenReaderScreen({
    super.key,
    required this.title,
    required this.content,
    this.backgroundImage,
    this.storyId,
    this.chapterId,
    this.choicesJson,
    this.chapterCount,
  });

  @override
  State<ZenReaderScreen> createState() => _ZenReaderScreenState();
}

class _ZenReaderScreenState extends State<ZenReaderScreen> {
  double _fontSize = 20.0;
  String _fontFamily = 'Serif';
  late quill.QuillController _quillController;
  
  final FlutterTts flutterTts = FlutterTts();
  bool _isPlaying = false;
  double _ttsSpeed = 0.5;
  double _ttsPitch = 1.0;

  List<String> _choices = [];
  bool _loadingChoices = false;
  int? _selectedChoiceIndex;
  final TextEditingController _customChoiceController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.content.startsWith('[{') && widget.content.endsWith('}]')) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.content));
        _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (e) {
        final doc = quill.Document()..insert(0, widget.content);
        _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      }
    } else {
      final doc = quill.Document()..insert(0, widget.content);
      _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
    }
    
    _initTts();
    _loadChoices();
  }

  void _loadChoices() async {
    if (widget.choicesJson != null && widget.choicesJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.choicesJson!);
        if (decoded is List) {
          setState(() {
            _choices = List<String>.from(decoded);
          });
          return;
        }
      } catch (_) {}
    }

    if (widget.storyId != null && widget.chapterId != null) {
      _fetchChoices();
    }
  }

  Future<void> _fetchChoices() async {
    setState(() => _loadingChoices = true);
    try {
      final choices = await ApiService.generateChapterChoices(widget.storyId!, widget.chapterId!);
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
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await flutterTts.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      String plainText = _quillController.document.toPlainText();
      if (plainText.trim().isNotEmpty) {
        setState(() {
          _isPlaying = true;
        });
        await flutterTts.speak(plainText);
      }
    }
  }

  void _showTtsSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Audiobook Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.speed),
                      const SizedBox(width: 16),
                      const Text('Speed'),
                      Expanded(
                        child: Slider(
                          value: _ttsSpeed,
                          min: 0.1,
                          max: 2.0,
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
                      const Icon(Icons.record_voice_over),
                      const SizedBox(width: 16),
                      const Text('Pitch'),
                      Expanded(
                        child: Slider(
                          value: _ttsPitch,
                          min: 0.5,
                          max: 2.0,
                          onChanged: (val) {
                            setSheetState(() => _ttsPitch = val);
                            setState(() => _ttsPitch = val);
                            flutterTts.setPitch(val);
                          },
                        ),
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

    if (widget.storyId != null) {
      context.push('/story/${widget.storyId}/director', extra: {
        'chapterCount': widget.chapterCount ?? 0,
        'initialPrompt': 'Continue the story based on this choice: $choiceText',
        'selectedChoice': choiceText,
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _quillController.dispose();
    _customChoiceController.dispose();
    super.dispose();
  }

  Widget _buildChoicesWidget() {
    if (widget.storyId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 32, bottom: 48),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                'What happens next?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your story path or write your own custom decision:',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingChoices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('AI generating story choices...'),
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _choices[index],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
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
                  setState(() {
                    _selectedChoiceIndex = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Or write your own custom choice...',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitChoice,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Continue Story with Choice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            tooltip: 'Audiobook Mode',
            onPressed: _togglePlayback,
          ),
          IconButton(
            icon: const Icon(Icons.settings_voice),
            tooltip: 'Voice Settings',
            onPressed: _showTtsSettings,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.font_download),
            onSelected: (value) {
              setState(() {
                _fontFamily = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'Serif', child: Text('Serif')),
              const PopupMenuItem(value: 'Sans', child: Text('Sans-Serif')),
              const PopupMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () {
              setState(() {
                if (_fontSize > 12) _fontSize -= 2;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () {
              setState(() {
                if (_fontSize < 36) _fontSize += 2;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: widget.backgroundImage != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: widget.backgroundImage!.startsWith('http')
                      ? NetworkImage(widget.backgroundImage!)
                      : MemoryImage(base64Decode(widget.backgroundImage!)) as ImageProvider,
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.85),
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontFamily: _fontFamily,
                      height: 1.8,
                    ),
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      config: const quill.QuillEditorConfig(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  _buildChoicesWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
