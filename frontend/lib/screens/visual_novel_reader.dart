import 'package:flutter/material.dart';

class VisualNovelReaderScreen extends StatefulWidget {
  final String title;
  final String content;
  final String? backgroundImage;

  const VisualNovelReaderScreen({
    super.key,
    required this.title,
    required this.content,
    this.backgroundImage,
  });

  @override
  State<VisualNovelReaderScreen> createState() => _VisualNovelReaderScreenState();
}

class _VisualNovelReaderScreenState extends State<VisualNovelReaderScreen> {
  final List<Map<String, String>> _dialogueLines = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  void _parseContent() {
    final rawLines = widget.content.split('\n');
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        final speaker = parts[0].trim();
        final text = parts.sublist(1).join(':').trim();
        _dialogueLines.add({'speaker': speaker, 'text': text});
      } else {
        _dialogueLines.add({'speaker': 'Narrator', 'text': trimmed});
      }
    }

    if (_dialogueLines.isEmpty) {
      _dialogueLines.add({'speaker': 'Narrator', 'text': widget.content});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScene = _dialogueLines[_currentIndex];
    final speaker = currentScene['speaker'] ?? 'Narrator';
    final text = currentScene['text'] ?? '';
    final isNarrator = speaker.toLowerCase() == 'narrator';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_currentIndex + 1} / ${_dialogueLines.length}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.backgroundImage != null && widget.backgroundImage!.isNotEmpty
              ? Image.network(
                  widget.backgroundImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E2E)),
                )
              : Container(color: const Color(0xFF1E1E2E)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex < _dialogueLines.length - 1) {
                  setState(() => _currentIndex++);
                }
              },
              child: Card(
                color: Colors.black.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isNarrator ? Colors.amber : Colors.purpleAccent, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isNarrator ? Colors.amber[800] : Colors.purple[800],
                            child: Icon(
                              isNarrator ? Icons.auto_stories : Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            speaker,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isNarrator ? Colors.amberAccent : Colors.purpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Text(
                        text,
                        style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentIndex > 0)
                            TextButton.icon(
                              onPressed: () => setState(() => _currentIndex--),
                              icon: const Icon(Icons.arrow_back, color: Colors.grey),
                              label: const Text('Prev', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            const SizedBox(),
                          TextButton.icon(
                            onPressed: () {
                              if (_currentIndex < _dialogueLines.length - 1) {
                                setState(() => _currentIndex++);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            icon: Icon(
                              _currentIndex < _dialogueLines.length - 1 ? Icons.arrow_forward : Icons.check_circle,
                              color: Colors.amberAccent,
                            ),
                            label: Text(
                              _currentIndex < _dialogueLines.length - 1 ? 'Next (Tap Screen)' : 'Finish',
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
