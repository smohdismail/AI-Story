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
      setState(() {
        isLoading = false;
      });
      print('Error loading data: $e');
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
        title: const Text('Story Chapters'),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text('Chapter ${chapter['chapter_number']}'),
                    subtitle: Text(chapter['title'] ?? 'Untitled Chapter'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          chapter['content'] ?? '',
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/story/${widget.storyId}/director', extra: {'chapterCount': chapters.length}),
        label: const Text('Create Chapter'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
