import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../pdf_export.dart';
import '../utils/name_generator.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
  List<dynamic> worldItems = [];
  String charSearchQuery = '';
  String loreSearchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final storyData = await ApiService.getStory(widget.storyId);
      setState(() => story = storyData);
    } catch (e) {
      debugPrint('Error loading story: $e');
    }

    try {
      final charsData = await ApiService.getCharacters(widget.storyId);
      setState(() => characters = charsData);
    } catch (e) {
      debugPrint('Error loading characters: $e');
    }

    try {
      final chaptersData = await ApiService.getChapters(widget.storyId);
      setState(() => chapters = chaptersData);
    } catch (e) {
      debugPrint('Error loading chapters: $e');
    }

    try {
      final worldData = await ApiService.getWorldItems(widget.storyId);
      setState(() => worldItems = worldData);
    } catch (e) {
      debugPrint('Error loading world items: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading world items: $e. Did you restart the backend?')));
    }

    setState(() {
      isLoading = false;
    });
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

  Future<void> _forkStory() async {
    try {
      final newStory = await ApiService.branchStory(widget.storyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story Forked Successfully!')),
        );
        // Replace current route with the new story's route
        context.pushReplacement('/story/${newStory['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fork story: $e')),
        );
      }
    }
  }

  void _showStorySettingsDialog() {
    final TextEditingController rulesController = TextEditingController(text: story?['custom_rules'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Story Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set custom AI rules specifically for THIS story. These override your global rules.'),
              const SizedBox(height: 16),
              TextField(
                controller: rulesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Write entirely from the villain\'s perspective',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateStory(widget.storyId, {'custom_rules': rulesController.text});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story Rules Saved')));
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(icon: Icon(Icons.public), text: 'World Lore'),
            ],
          ),
          actions: [
          if (story != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showStoryInfoDialog,
            ),
          if (story != null && chapters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.book),
              tooltip: 'Export to EPUB',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating EPUB...')),
                );
                final bytes = await ApiService.downloadEpub(widget.storyId);
                if (bytes != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File('${dir.path}/${story!['title']}.epub');
                  await file.writeAsBytes(bytes);
                  await Share.shareXFiles([XFile(file.path)]);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to generate EPUB')),
                  );
                }
              },
            ),
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
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                _showStorySettingsDialog();
              } else if (value == 'fork') {
                _forkStory();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [Icon(Icons.settings), SizedBox(width: 8), Text('Story Settings')],
                  ),
                ),
                const PopupMenuItem(
                  value: 'fork',
                  child: Row(
                    children: [Icon(Icons.call_split), SizedBox(width: 8), Text('Fork Story')],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
        body: TabBarView(
          children: [
            _buildChaptersTab(),
            _buildCharactersTab(),
            _buildWorldTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.push('/story/${widget.storyId}/director', extra: {'chapterCount': chapters.length});
            _loadData();
          },
          label: const Text('Create Chapter'),
          icon: const Icon(Icons.auto_awesome),
        ),
      ),
    );
  }

  int _calculateWordCount() {
    int count = 0;
    for (var ch in chapters) {
      String text = ch['content'] ?? '';
      if (text.startsWith('[{')) {
        try {
          final doc = quill.Document.fromJson(jsonDecode(text));
          text = doc.toPlainText();
        } catch (_) {}
      }
      count += text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    }
    return count;
  }

  Widget _buildChaptersTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    
    int totalWords = _calculateWordCount();
    int readTimeMinutes = (totalWords / 250).ceil();
    bool isGeneratingCover = false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (story != null && story!['cover_base64'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(story!['cover_base64']),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (story != null)
                StatefulBuilder(
                  builder: (context, setStateCover) {
                    return OutlinedButton.icon(
                      onPressed: isGeneratingCover ? null : () async {
                        final confirm = await _confirmCreditUsage(context, 'generate a book cover');
                        if (!confirm) return;

                        setStateCover(() => isGeneratingCover = true);
                        try {
                          String prompt = "Book cover for a story titled '${story!['title']}'. Genre: ${story!['genre']}. Subgenre: ${story!['subgenre']}. Tone: ${story!['tone']}. ${story!['synopsis']}";
                          final res = await ApiService.generateImage(prompt);
                          if (res['base64_image'] != null) {
                            await ApiService.updateStory(widget.storyId, {'cover_base64': res['base64_image']});
                            _loadData();
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
                        } finally {
                          if (mounted) setStateCover(() => isGeneratingCover = false);
                        }
                      },
                      icon: isGeneratingCover ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.purple),
                      label: const Text('Generate AI Cover'),
                    );
                  }
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Chip(
                    avatar: const Icon(Icons.text_snippet, size: 16),
                    label: Text('$totalWords words'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.timer, size: 16),
                    label: Text('~ $readTimeMinutes min read'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: chapters.isEmpty 
            ? const Center(child: Text("There is no chapter yet.", style: TextStyle(fontSize: 18)))
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
            onReorder: (int oldIndex, int newIndex) async {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = chapters.removeAt(oldIndex);
                chapters.insert(newIndex, item);
                for (int i = 0; i < chapters.length; i++) {
                  chapters[i]['chapter_number'] = i + 1;
                }
              });
              try {
                final chapterIds = chapters.map((c) => c['id'] as String).toList();
                await ApiService.reorderChapters(widget.storyId, chapterIds);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reorder: $e')));
                _loadData();
              }
            },
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              return Card(
                key: ValueKey(chapter['id']),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(chapter['title'] ?? 'Chapter ${chapter['chapter_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Chapter ${chapter['chapter_number']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_book, color: Colors.purpleAccent),
                        tooltip: 'Zen Reader Mode',
                        onPressed: () {
                          String? bgImage;
                          if (characters.isNotEmpty) {
                            try {
                              bgImage = characters.firstWhere((c) => c['avatar_base64'] != null)['avatar_base64'];
                            } catch (_) {} // firstWhere throws if no element found
                          }
                          
                          context.push('/zen_reader', extra: {
                            'title': chapter['title'] ?? 'Chapter ${chapter['chapter_number']}',
                            'content': chapter['content'] ?? '',
                            'backgroundImage': bgImage,
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.translate, color: Colors.green),
                        tooltip: 'Translate Chapter',
                        onPressed: () => _showTranslateDialog(chapter['content'] ?? ''),
                      ),
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
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_getPlainText(chapter['content'] ?? ''), style: const TextStyle(height: 1.5)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getPlainText(String content) {
    if (content.startsWith('[{') && content.endsWith('}]')) {
      try {
        final List<dynamic> delta = jsonDecode(content);
        String plain = '';
        for (var op in delta) {
          if (op['insert'] is String) {
            plain += op['insert'];
          }
        }
        return plain;
      } catch (_) {}
    }
    return content;
  }

  Widget _buildCharactersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddCharacterDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Character'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showRelationshipMapDialog,
                  icon: const Icon(Icons.share),
                  label: const Text('Relationships'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                final session = await ApiService.createGroupChat(widget.storyId);
                if (context.mounted) {
                  context.push('/group_chat', extra: {
                    'storyId': widget.storyId,
                    'sessionId': session['id'],
                  });
                }
              } catch(e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            icon: const Icon(Icons.groups, color: Colors.white),
            label: const Text('Enter Tavern (Group Chat)', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.amber[800],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search characters...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => charSearchQuery = value),
          ),
        ),
        Expanded(
          child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : characters.isEmpty
              ? const Center(child: Text("No characters added yet.", style: TextStyle(fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: characters.where((c) => (c['name'] ?? '').toLowerCase().contains(charSearchQuery.toLowerCase())).length,
                  itemBuilder: (context, index) {
                    final filteredChars = characters.where((c) => (c['name'] ?? '').toLowerCase().contains(charSearchQuery.toLowerCase())).toList();
                    final char = filteredChars[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 50,
                                    maxWidth: 256,
                                    maxHeight: 256,
                                  );
                                  if (pickedFile != null) {
                                    final bytes = await pickedFile.readAsBytes();
                                    final base64Image = base64Encode(bytes);
                                    await ApiService.updateCharacter(
                                      widget.storyId,
                                      char['id'],
                                      {'avatar_base64': base64Image},
                                    );
                                    _loadData();
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  backgroundImage: (char['avatar_base64'] != null && char['avatar_base64'].isNotEmpty)
                                      ? MemoryImage(base64Decode(char['avatar_base64']))
                                      : null,
                                  child: (char['avatar_base64'] == null || char['avatar_base64'].isEmpty)
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                              ),
                              title: Text(char['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Text('${char['gender'] ?? 'N/A'} • ${char['role'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[400])),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      context.push('/character_chat', extra: {
                                        'characterId': char['id'],
                                        'characterName': char['name'] ?? 'Unknown',
                                        'backgroundImage': char['avatar_base64'],
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () async {
                                      bool confirm = await showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Character'),
                                          content: const Text('Are you sure?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                          ],
                                        ),
                                      ) ?? false;
                                      if (confirm) {
                                        await ApiService.deleteCharacter(widget.storyId, char['id']);
                                        _loadData();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (char['relationship_status'] != null && char['relationship_status'].toString().isNotEmpty) ...[
                              Text('Relationship: ${char['relationship_status']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                              const SizedBox(height: 8),
                            ],
                            const Text('Personality', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(char['personality'] ?? 'N/A', style: const TextStyle(height: 1.4)),
                            const SizedBox(height: 12),
                            const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(char['appearance'] ?? 'N/A', style: const TextStyle(height: 1.4)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWorldTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddWorldItemDialog(),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Add World Lore'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search world lore...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => loreSearchQuery = value),
          ),
        ),
        Expanded(
          child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : worldItems.isEmpty
              ? const Center(child: Text("No lore added yet.", style: TextStyle(fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: worldItems.where((w) => (w['title'] ?? '').toLowerCase().contains(loreSearchQuery.toLowerCase())).length,
                  itemBuilder: (context, index) {
                    final filteredLore = worldItems.where((w) => (w['title'] ?? '').toLowerCase().contains(loreSearchQuery.toLowerCase())).toList();
                    final item = filteredLore[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Category: ${item['category'] ?? 'N/A'}'),
                            const SizedBox(height: 4),
                            Text('${item['description'] ?? ''}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteWorldItem(item['id']),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

  Future<void> _deleteWorldItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete World Lore'),
        content: const Text('Are you sure you want to delete this item?'),
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
        await ApiService.deleteWorldItem(widget.storyId, itemId);
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddCharacterDialog() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final genderController = TextEditingController();
    final personalityController = TextEditingController();
    final appearanceController = TextEditingController();
    final relationshipController = TextEditingController();
    final dialogueStyleController = TextEditingController();
    String? base64Image;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Character'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (base64Image != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: MemoryImage(base64Decode(base64Image!)),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : () async {
                          setStateDialog(() => isUploading = true);
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                              maxWidth: 512,
                              maxHeight: 512,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setStateDialog(() {
                                base64Image = base64Encode(bytes);
                              });
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
                          } finally {
                            setStateDialog(() => isUploading = false);
                          }
                        },
                        icon: isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload),
                        label: const Text('Upload'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : () async {
                          if (appearanceController.text.isEmpty && nameController.text.isEmpty) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter appearance or name first!')));
                            return;
                          }
                          
                          final confirm = await _confirmCreditUsage(context, 'generate a character avatar');
                          if (!confirm) return;

                          setStateDialog(() => isUploading = true);
                          try {
                            String prompt = "Portrait of ${nameController.text}. ${appearanceController.text}";
                            final res = await ApiService.generateImage(prompt);
                            if (res['base64_image'] != null) {
                              setStateDialog(() {
                                base64Image = res['base64_image'];
                              });
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
                          } finally {
                            setStateDialog(() => isUploading = false);
                          }
                        },
                        icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                        label: const Text('AI Generate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.casino, color: Colors.purple),
                        tooltip: 'Generate Name',
                        onSelected: (value) {
                          if (value == 'Fantasy') {
                            nameController.text = NameGenerator.generateFantasyName();
                          } else if (value == 'Sci-Fi') {
                            nameController.text = NameGenerator.generateSciFiName();
                          } else {
                            nameController.text = NameGenerator.generateModernName();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(value: 'Fantasy', child: Text('Fantasy Name')),
                          const PopupMenuItem(value: 'Sci-Fi', child: Text('Sci-Fi Name')),
                          const PopupMenuItem(value: 'Modern', child: Text('Modern Name')),
                        ],
                      ),
                    ),
                  ),
                  TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role (e.g., Protagonist, Villain)')),
                  TextField(controller: genderController, decoration: const InputDecoration(labelText: 'Gender')),
                  TextField(controller: personalityController, decoration: const InputDecoration(labelText: 'Personality')),
                  TextField(controller: appearanceController, decoration: const InputDecoration(labelText: 'Appearance (e.g., Tall, green eyes)')),
                  TextField(controller: relationshipController, decoration: const InputDecoration(labelText: 'Relationship to User')),
                  TextField(controller: dialogueStyleController, decoration: const InputDecoration(labelText: 'Dialogue Style (e.g., Uses old English)')),
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
                      'gender': genderController.text,
                      'personality': personalityController.text,
                      'appearance': appearanceController.text,
                      'relationship_status': relationshipController.text,
                      'dialogue_style': dialogueStyleController.text,
                      if (base64Image != null) 'avatar_base64': base64Image,
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
          );
        }
      ),
    );
  }

  void _showAddWorldItemDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add World Lore'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name (e.g., The Silent City)',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.casino, color: Colors.purple),
                    tooltip: 'Generate Name',
                    onSelected: (value) {
                      if (value == 'Fantasy') {
                        nameController.text = NameGenerator.generateFantasyName();
                      } else if (value == 'Sci-Fi') {
                        nameController.text = NameGenerator.generateSciFiName();
                      } else {
                        nameController.text = NameGenerator.generateModernName();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(value: 'Fantasy', child: Text('Fantasy Name')),
                      const PopupMenuItem(value: 'Sci-Fi', child: Text('Sci-Fi Name')),
                      const PopupMenuItem(value: 'Modern', child: Text('Modern Name')),
                    ],
                  ),
                ),
              ),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (e.g., Location, Faction, Item)')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await ApiService.createWorldItem(widget.storyId, {
                  'name': nameController.text,
                  'category': categoryController.text,
                  'description': descriptionController.text,
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

  void _showStoryInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(story!['title'] ?? 'Story Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Synopsis:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(story!['synopsis'] ?? 'N/A'),
              const SizedBox(height: 8),
              const Text('Genre:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(story!['genre'] ?? 'N/A'),
              const SizedBox(height: 8),
              const Text('Subgenre:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(story!['subgenre'] ?? 'N/A'),
              const SizedBox(height: 8),
              const Text('Tone:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(story!['tone'] ?? 'N/A'),
              const Divider(),
              const Text('Story Stats:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Total Chapters: ${chapters.length}'),
              Text('Total Words: ${_calculateWordCount()}'),
              Text('Estimated Pages: ${(_calculateWordCount() / 250).ceil()} pages'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditStoryDialog();
            },
            child: const Text('Edit Story'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showEditStoryDialog() {
    final titleController = TextEditingController(text: story!['title']);
    final synopsisController = TextEditingController(text: story!['synopsis']);
    final genreController = TextEditingController(text: story!['genre']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Story Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: synopsisController, decoration: const InputDecoration(labelText: 'Synopsis'), maxLines: 3),
              TextField(controller: genreController, decoration: const InputDecoration(labelText: 'Genre')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              try {
                await ApiService.updateStory(widget.storyId, {
                  'title': titleController.text,
                  'synopsis': synopsisController.text,
                  'genre': genreController.text,
                });
                if (mounted) Navigator.pop(context);
                _loadData(); // Refresh UI
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating story: $e')));
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
  Future<bool> _confirmCreditUsage(BuildContext context, String action) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use AI Credits?'),
        content: Text('Are you sure you want to $action? This will cost API credits.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showTranslateDialog(String originalText) {
    final translator = GoogleTranslator();
    String targetLanguage = 'ur'; // Default to Urdu
    final Map<String, String> languages = {
      'Urdu': 'ur',
      'Spanish': 'es',
      'French': 'fr',
      'Hindi': 'hi',
      'Arabic': 'ar',
      'Chinese': 'zh-cn',
      'Japanese': 'ja',
    };

    showDialog(
      context: context,
      builder: (context) {
        String _selectedLang = 'Urdu';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Translate Chapter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _selectedLang,
                    isExpanded: true,
                    items: languages.keys.map((String lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLang = newValue!;
                        targetLanguage = languages[newValue]!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Translating is completely free and uses no API credits!'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    try {
                      // Translator sometimes fails on very large blocks, so we chunk it by paragraphs
                      final paragraphs = originalText.split('\n\n');
                      String translatedText = '';
                      for (var p in paragraphs) {
                        if (p.trim().isNotEmpty) {
                          var translation = await translator.translate(p, to: targetLanguage).timeout(const Duration(seconds: 15));
                          translatedText += translation.text + '\n\n';
                        }
                      }
                      
                      if (!context.mounted) return;
                      Navigator.pop(context); // close progress
                      
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Translated to $_selectedLang'),
                          content: SingleChildScrollView(
                            child: Text(translatedText),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                          ],
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Translation failed: $e')));
                    }
                  },
                  child: const Text('Translate'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showRelationshipMapDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Character Relationship Map'),
        content: SizedBox(
          width: double.maxFinite,
          child: characters.isEmpty
              ? const Text('No characters yet. Add characters to build relationships.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: characters.length,
                  itemBuilder: (context, index) {
                    final char = characters[index];
                    return ExpansionTile(
                      title: Text(char['name'] ?? 'Unknown'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Relationship to User: ${char['relationship_status'] ?? 'None'}'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Dialogue Style: ${char['dialogue_style'] ?? 'Normal'}'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditCharacterPersonalityDialog(char);
                          },
                          child: const Text('Edit Personality Specs'),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showEditCharacterPersonalityDialog(Map<String, dynamic> char) {
    final TextEditingController relController = TextEditingController(text: char['relationship_status'] ?? '');
    final TextEditingController diagController = TextEditingController(text: char['dialogue_style'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Persona: ${char['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: relController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Relationship to User',
                hintText: 'e.g. Hates John, secretly loves Mary',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: diagController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dialogue Style',
                hintText: 'e.g. Speaks in short, aggressive sentences',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateCharacter(widget.storyId, char['id'], {
                  'relationship_status': relController.text,
                  'dialogue_style': diagController.text,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
