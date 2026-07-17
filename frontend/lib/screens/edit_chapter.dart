import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class EditChapterScreen extends StatefulWidget {
  final String storyId;
  final int chapterNumber;
  final Map<String, dynamic> chapterData;

  const EditChapterScreen({
    super.key,
    required this.storyId,
    required this.chapterNumber,
    required this.chapterData,
  });

  @override
  State<EditChapterScreen> createState() => _EditChapterScreenState();
}

class _EditChapterScreenState extends State<EditChapterScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chapterData['title'] ?? 'Chapter ');
    _contentController = TextEditingController(text: widget.chapterData['content'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveChapter() async {
    setState(() => _isSaving = true);
    try {
      final updatedData = {
        'title': _titleController.text,
        'content': _contentController.text,
        'chapter_number': widget.chapterNumber,
        'summary': widget.chapterData['summary'] ?? '',
        'status': 'published'
      };
      await ApiService.updateChapter(widget.storyId, widget.chapterNumber, updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chapter updated!')));
        context.pop(true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Chapter'),
        actions: [
          IconButton(
            icon: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveChapter,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Chapter Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Chapter content...',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
