import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';
import '../pdf_export.dart';

class StoryDetailsScreen extends StatefulWidget {
  final String storyId;
  const StoryDetailsScreen({super.key, required this.storyId});

  @override
  State<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

class _StoryDetailsScreenState extends State<StoryDetailsScreen> {
  List<dynamic> chapters = [];
  Map<String, dynamic>? story;
  List<dynamic> characters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final storyData = await ApiService.getStory(widget.storyId);
      final charsData = await ApiService.getCharacters(widget.storyId);
      final chaptersData = await ApiService.getChapters(widget.storyId);
      setState(() {
        story = storyData;
        characters = charsData;
        chapters = chaptersData;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteChapter(int chapterNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Are you sure you want to delete Chapter $chapterNumber? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteChapter(widget.storyId, chapterNumber);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chapter deleted')));
          _loadData(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting chapter: $e')));
        }
      }
    }
  }

  Widget _buildParsedText(String text, BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.copyWith(fontSize: 16, height: 1.5);
    final italicStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
    
    final parts = text.split('*');
    final spans = <TextSpan>[];
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        spans.add(TextSpan(text: parts[i], style: baseStyle));
      } else {
        spans.add(TextSpan(text: parts[i], style: italicStyle));
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Story Details'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Chapters'),
              Tab(icon: Icon(Icons.people), text: 'Characters'),
            ],
          ),
          actions: [
          if (story != null && chapters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating PDF...')),
                );
                try {
                  await PdfExport.exportAndSharePdf(story!, characters, chapters);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating PDF: $e')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _loadData();
            },
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : chapters.isEmpty 
          ? const Center(child: Text("There is no chapter yet.", style: TextStyle(fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      title: Text(chapter['title'] ?? 'Chapter ${chapter['chapter_number']}'),
                      subtitle: Text('Chapter ${chapter['chapter_number']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              final result = await context.push('/story/${widget.storyId}/edit_chapter', extra: {
                                'chapterNumber': chapter['chapter_number'],
                                'chapterData': chapter,
                              });
                              if (result == true) {
                                _loadData();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteChapter(chapter['chapter_number']),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildParsedText(chapter['content'] ?? '', context),
                        )
                      ],
                    ),
                  );
                },
            ),
        ),
        _buildCharactersTab(),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/story/${widget.storyId}/director', extra: {'chapterCount': chapters.length});
          _loadData();
        },
        label: const Text('Create Chapter'),
        icon: const Icon(Icons.auto_awesome),
      ),
    ));
  }

  Widget _buildCharactersTab() {
    return Scaffold(
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : characters.isEmpty
          ? const Center(child: Text("No characters added yet.", style: TextStyle(fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: characters.length,
              itemBuilder: (context, index) {
                final char = characters[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(char['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Role: ${char['role'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Personality: ${char['personality'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Appearance: ${char['appearance'] ?? 'N/A'}'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCharacter(char['id']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_character_btn',
        onPressed: _showAddCharacterDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _deleteCharacter(String characterId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: const Text('Are you sure you want to delete this character?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteCharacter(widget.storyId, characterId);
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddCharacterDialog() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final personalityController = TextEditingController();
    final appearanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Character'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name (e.g., John Doe)')),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role (e.g., Protagonist, Brother)')),
              TextField(controller: personalityController, decoration: const InputDecoration(labelText: 'Personality (e.g., Grumpy, Sweet)')),
              TextField(controller: appearanceController, decoration: const InputDecoration(labelText: 'Appearance (e.g., Tall, green eyes)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await ApiService.createCharacter(widget.storyId, {
                  'name': nameController.text,
                  'role': roleController.text,
                  'personality': personalityController.text,
                  'appearance': appearanceController.text,
                });
                if (mounted) Navigator.pop(context);
                _loadData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
