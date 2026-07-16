import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  final _titleController = TextEditingController();
  final _synopsisController = TextEditingController();
  
  String _selectedGenre = 'Romance';
  String _selectedSubgenre = 'CEO Romance';
  String _selectedTone = 'Passionate';
  
  final _genres = ['Romance', 'Fantasy', 'Sci-Fi', 'Mystery'];
  final _subgenres = ['CEO Romance', 'Enemies to Lovers', 'Slow Burn', 'Mafia Romance', 'Historical Romance'];
  final _tones = ['Passionate', 'Dark', 'Lighthearted', 'Dramatic'];

  bool _isSaving = false;

  Future<void> _createStory() async {
    setState(() => _isSaving = true);
    try {
      final storyData = {
        'title': _titleController.text,
        'synopsis': _synopsisController.text,
        'genre': _selectedGenre,
        'subgenre': _selectedSubgenre,
        'tone': _selectedTone,
      };
      
      await ApiService.createStory(storyData);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Story')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Story Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _synopsisController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Synopsis / Premise', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGenre,
                  decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                  items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGenre = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSubgenre,
                  decoration: const InputDecoration(labelText: 'Subgenre / Romance Style', border: OutlineInputBorder()),
                  items: _subgenres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedSubgenre = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTone,
                  decoration: const InputDecoration(labelText: 'Tone / Emotional Intensity', border: OutlineInputBorder()),
                  items: _tones.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedTone = v!),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _createStory,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving ? const CircularProgressIndicator() : const Text('Initialize Story World', style: TextStyle(fontSize: 18)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
