import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../streak_service.dart';

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
  bool _stopRequested = false;

  void _generateText() async {
    if (_promptController.text.isEmpty) return;
    
    setState(() {
      _isGenerating = true;
      _stopRequested = false;
      // We do NOT clear _editorController.text here, so Reroll/Continue can be flexible.
    });
    
    final prompt = _promptController.text;
    final contextText = _editorController.text.length > 2000 
        ? _editorController.text.substring(_editorController.text.length - 2000) 
        : _editorController.text;

    try {
      final prefs = await SharedPreferences.getInstance();
      final globalCustomRules = prefs.getString('global_custom_rules') ?? '';
      
      await for (final chunk in ApiService.generateChapter(
          widget.storyId, 
          prompt, 
          contextText, 
          globalCustomRules: globalCustomRules
      )) {
        if (!mounted || _stopRequested) break;
        setState(() {
          _editorController.text += chunk;
        });
      }
      
      if (_stopRequested) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generation stopped.')));
        }
        return; // Don't save
      }

      // Finished streaming, now save it as a chapter if there were no errors
      if (mounted) {
        final textLower = _editorController.text.toLowerCase();
        if (textLower.contains('[ai system error:') || 
            textLower.contains('[system message:') ||
            textLower.contains('[removed]') ||
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
        
        int wordCount = _editorController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        await StreakService.addWords(wordCount);

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
                const Text('Branching Choice / Next Chapter Focus:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Explicitly guide the AI (e.g., "The protagonist chooses the left path and discovers...")',
                  ),
                ),
                const SizedBox(height: 12),
                if (_isGenerating && !_isSaving)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _stopRequested = true),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Generation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _generateText,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isSaving ? 'Saving Chapter...' : 'Generate Chapter'),
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
