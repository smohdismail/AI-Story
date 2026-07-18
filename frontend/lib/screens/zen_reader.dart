import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_tts/flutter_tts.dart';

class ZenReaderScreen extends StatefulWidget {
  final String title;
  final String content;
  final String? backgroundImage;

  const ZenReaderScreen({
    super.key,
    required this.title,
    required this.content,
    this.backgroundImage,
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

  @override
  void dispose() {
    flutterTts.stop();
    _quillController.dispose();
    super.dispose();
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
                  image: MemoryImage(base64Decode(widget.backgroundImage!)),
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
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: DefaultTextStyle(
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
