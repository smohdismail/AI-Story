import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
                    Colors.black.withOpacity(0.85), // Darken the image heavily so text is visible
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
        ),
      ),
    );
  }
}
