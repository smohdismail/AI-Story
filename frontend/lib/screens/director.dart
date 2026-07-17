import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class DirectorScreen extends StatefulWidget {
  final String storyId;
  final int currentChapterCount;
  const DirectorScreen({super.key, required this.storyId, required this.currentChapterCount});

  @override
  State<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends State<DirectorScreen> {
  final _editorController = TextEditingController();
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false;

  void _generateText() async {
    if (_promptController.text.isEmpty) return;
    
    setState(() => _isGenerating = true);
    final prompt = _promptController.text;
    final contextText = _editorController.text.length > 2000 
        ? _editorController.text.substring(_editorController.text.length - 2000) 
        : _editorController.text;

    try {
      await for (final chunk in ApiService.generateChapter(widget.storyId, prompt, contextText)) {
        if (!mounted) break;
        setState(() {
          _editorController.text += chunk;
        });
      }
      // Finished streaming, now save it as a chapter if there were no errors
      if (mounted) {
        final textLower = _editorController.text.toLowerCase();
        if (textLower.contains('[ai system error:') || 
            textLower.contains('[system message:') ||
            textLower.contains('as an ai') ||
            textLower.contains('i cannot fulfill') ||
            textLower.contains('i am sorry') ||
            textLower.contains("i'm sorry,") ||
            textLower.contains('i cannot write') ||
            textLower.contains('i cannot generate')) {
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI Refusal or Error Detected. Try generating again.'), backgroundColor: Colors.red),
          );
          return;
        }

        setState(() => _isSaving = true);
        await ApiService.saveChapter(widget.storyId, {
          'chapter_number': widget.currentChapterCount + 1,
          'title': 'Chapter ${widget.currentChapterCount + 1}',
          'content': _editorController.text,
          'summary': prompt, // We can store the prompt used as the summary for now
          'status': 'published'
        });
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chapter Saved!')));
        context.pop(); // Go back to story details
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Director: Chapter ${widget.currentChapterCount + 1}'),
      ),
      body: Column(
        children: [
          // Main Editor Area (Takes up remaining space)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _editorController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 18, height: 1.6),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'The AI will generate the chapter here...',
                ),
              ),
            ),
          ),
          // AI Assistant Bottom Panel for Mobile
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Instructions for AI:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., "Write a slow-burn scene where they accidentally touch hands..."',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: (_isGenerating || _isSaving) ? null : _generateText,
                  icon: (_isGenerating || _isSaving)
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isSaving ? 'Saving Chapter...' : _isGenerating ? 'Generating...' : 'Generate Chapter'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
