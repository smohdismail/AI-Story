import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _editorController = TextEditingController();
  final _promptController = TextEditingController();
  bool _isGenerating = false;

  void _generateText() async {
    if (_promptController.text.isEmpty) return;
    
    setState(() => _isGenerating = true);
    final prompt = _promptController.text;
    final contextText = _editorController.text.length > 2000 
        ? _editorController.text.substring(_editorController.text.length - 2000) 
        : _editorController.text;

    try {
      await for (final chunk in ApiService.generateChapter(prompt, contextText)) {
        if (!mounted) break;
        setState(() {
          _editorController.text += chunk;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Writing Workspace'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Chapter'),
            onPressed: () {},
          )
        ],
      ),
      body: Row(
        children: [
          // Main Editor Area
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _editorController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 18, height: 1.6),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start writing your story here, or use the AI assistant to generate the next chapter...',
                ),
              ),
            ),
          ),
          // AI Assistant Sidebar
          Container(
            width: 350,
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('AI Director', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                const Text('Instructions for AI:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., "Write a slow-burn romantic scene where they accidentally touch hands at the coffee shop. Make it highly emotional and dramatic."',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateText,
                  icon: _isGenerating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Scene'),
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
