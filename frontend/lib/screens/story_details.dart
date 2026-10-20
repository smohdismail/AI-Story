import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../pdf_export.dart';
import '../utils/name_generator.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../services/audiobook_service.dart';
import 'audiobook_player_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/romance_features_dialogs.dart';
import '../widgets/audio_drama_sheet.dart';

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
  List<dynamic> locations = [];
  List<dynamic> illustrations = [];
  String charSearchQuery = '';
  String loreSearchQuery = '';
  String locationSearchQuery = '';
  bool isLoading = true;
  Map<String, dynamic>? outlinePlan;
  bool isLoadingOutline = false;
  String selectedCoverStyle = 'Anime/Manga';
  bool isGeneratingCoverStyle = false;
  List<dynamic>? storyKeepsakes;
  bool isLoadingKeepsakes = false;
  Map<String, dynamic>? chemistryCurveData;
  bool isLoadingChemistryCurve = false;
  List<dynamic>? storyUnsentLetters;
  bool isLoadingUnsentLetters = false;
  final Set<String> _brokenWaxSeals = {};
  List<dynamic>? storyPolaroids;
  bool isLoadingPolaroids = false;
  Map<String, dynamic>? sensoryProfile;
  bool isLoadingSensoryProfile = false;
  List<dynamic>? scheduledLetters;
  bool isLoadingScheduledLetters = false;
  // Batch 4: 🪢 Red Thread of Fate
  List<dynamic>? storyRedThread;
  bool isLoadingRedThread = false;
  // Batch 4: 💌 Wax-Sealed Reply Dispatch
  bool isDispatchingWaxReply = false;
  Map<String, dynamic>? lastWaxReplyReaction;

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

    try {
      final locsData = await ApiService.getWorldLocations(widget.storyId);
      setState(() => locations = locsData);
    } catch (e) {
      debugPrint('Error loading world locations: $e');
    }

    try {
      final illData = await ApiService.getIllustrations(widget.storyId);
      setState(() => illustrations = illData);
    } catch (e) {
      debugPrint('Error loading illustrations: $e');
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


  void _autoExtractLore() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting world lore from chapters with AI...')));
    try {
      await ApiService.extractLore(widget.storyId);
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('World lore extracted successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error extracting lore: $e')));
    }
  }

  void _showPlotAnalyzerDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("AI Beta Reader analyzing plot consistency, pacing & characters...")),
          ],
        ),
      ),
    );

    try {
      final report = await ApiService.analyzePlot(widget.storyId);
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      final score = report['overall_score'] ?? 80;
      final pacing = report['pacing'] ?? 'Good';
      final characterConsistency = report['character_consistency'] ?? 'Consistent';
      final plotHoles = List<String>.from(report['plot_holes'] ?? []);
      final suggestions = List<String>.from(report['suggestions'] ?? []);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple),
              SizedBox(width: 8),
              Text('Plot & Pacing Report'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        '$score / 100',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: score >= 80 ? Colors.green : (score >= 60 ? Colors.amber : Colors.red),
                        ),
                      ),
                      const Text('Overall Story Health Score', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Divider(height: 24),
                const Text('Pacing Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                const SizedBox(height: 4),
                Text(pacing, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                const Text('Character Consistency', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                const SizedBox(height: 4),
                Text(characterConsistency, style: const TextStyle(fontSize: 14)),
                if (plotHoles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Plot Holes & Unresolved Hooks', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const SizedBox(height: 4),
                  ...plotHoles.map((hole) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('• $hole', style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                  )),
                ],
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('AI Writing Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const SizedBox(height: 4),
                  ...suggestions.map((sug) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('• $sug', style: const TextStyle(fontSize: 13)),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error analyzing plot: $e')));
      }
    }
  }

  void _togglePublishStory() async {
    try {
      final updated = await ApiService.publishStory(widget.storyId);
      final isPub = updated['is_published'] == true;
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPub 
              ? '🌐 Novel is now PUBLIC — Visible to all users in Community Feed!' 
              : '🔒 Novel is now PRIVATE — Strictly locked to your personal library.'),
            backgroundColor: isPub ? Colors.cyan.shade900 : Colors.deepOrange.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating visibility: $e')));
    }
  }

  void _showStoryTreeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Loading Story Tree..."),
          ],
        ),
      ),
    );

    try {
      final treeData = await ApiService.getStoryTree(widget.storyId);
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_tree, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Interactive Story Tree'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: treeData.isEmpty
              ? const Text('No chapter branches generated yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: treeData.length,
                  itemBuilder: (context, idx) {
                    final item = treeData[idx];
                    final isChoice = item['choice_prompt'] != null && item['choice_prompt'].toString().isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isChoice ? Colors.purple.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isChoice ? Colors.purpleAccent : Colors.cyan),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isChoice)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                '⚡ Choice Path: "${item['choice_prompt']}"',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Text(
                            'Chapter ${item['chapter_number']}: ${item['title']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (item['summary'] != null && item['summary'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(item['summary'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showRelationshipMatrixDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Loading Relationship Matrix..."),
          ],
        ),
      ),
    );

    try {
      var rels = await ApiService.getRelationships(widget.storyId);
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hub, color: Colors.pinkAccent),
                      SizedBox(width: 8),
                      Text('Relationship Matrix'),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                    tooltip: 'AI Auto-Analyze Dynamics',
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing character dynamics with AI...')));
                        final updated = await ApiService.analyzeRelationships(widget.storyId);
                        setDialogState(() {
                          rels = updated;
                        });
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: rels.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No character relationship dynamics recorded yet.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final updated = await ApiService.analyzeRelationships(widget.storyId);
                              setDialogState(() {
                                rels = updated;
                              });
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI Auto-Analyze Dynamics'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: rels.length,
                      itemBuilder: (context, idx) {
                        final rel = rels[idx];
                        final score = rel['sentiment_score'] ?? 0;
                        final color = score >= 50 ? Colors.green : (score >= 0 ? Colors.blue : (score >= -40 ? Colors.amber : Colors.red));
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Text('$score', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            title: Text('${rel['from_name']}  ➔  ${rel['to_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Chip(
                                  label: Text(rel['relationship_type'] ?? 'Acquaintance', style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (rel['notes'] != null && rel['notes'].toString().isNotEmpty)
                                  Text(rel['notes'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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

  void _showAiSuiteBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                      const SizedBox(width: 10),
                      Text('AI Story Tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_tree, color: Colors.cyanAccent),
                  title: const Text('Interactive Story Tree'),
                  subtitle: const Text('Visualize choices and chapter flowcharts'),
                  onTap: () {
                    Navigator.pop(context);
                    _showStoryTreeDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hub, color: Colors.pinkAccent),
                  title: const Text('Character Relationship Matrix'),
                  subtitle: const Text('View dynamics & affection scores'),
                  onTap: () {
                    Navigator.pop(context);
                    _showRelationshipMatrixDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics, color: Colors.purpleAccent),
                  title: const Text('AI Plot & Pacing Analyzer'),
                  subtitle: const Text('Scan plot holes & pacing consistency'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlotAnalyzerDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android, color: Colors.greenAccent),
                  title: const Text('Character Social Feed'),
                  subtitle: const Text('In-character status updates and posts'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSocialFeedDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share, color: Colors.cyanAccent),
                      const SizedBox(width: 10),
                      Text('Export Story', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.book, color: Colors.amber),
                  title: const Text('Export as EPUB'),
                  subtitle: const Text('Download e-book format for e-readers'),
                  onTap: () async {
                    Navigator.pop(context);
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
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: const Text('Export as PDF'),
                  subtitle: const Text('Generate printable PDF document with illustrations'),
                  onTap: () async {
                    Navigator.pop(context);
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _openZenReader(Map<String, dynamic> chapter) {
    String? bgImage;
    if (characters.isNotEmpty) {
      try {
        bgImage = characters.firstWhere((c) => c['avatar_base64'] != null)['avatar_base64'];
      } catch (_) {}
    }
    final int idx = chapters.indexOf(chapter);
    context.push('/zen_reader', extra: {
      'title': chapter['title'] ?? 'Chapter ${chapter['chapter_number']}',
      'content': chapter['content'] ?? '',
      'backgroundImage': bgImage,
      'storyId': widget.storyId,
      'chapterId': chapter['id'],
      'choicesJson': chapter['choices_json'],
      'chapterCount': chapters.length,
      'allChapters': chapters,
      'currentIndex': idx >= 0 ? idx : 0,
    });
  }

  Future<void> _editChapter(Map<String, dynamic> chapter) async {
    final result = await context.push('/story/${widget.storyId}/edit_chapter', extra: {
      'chapterNumber': chapter['chapter_number'],
      'chapterData': chapter,
    });
    if (result == true) {
      _loadData();
    }
  }

  void _illustrateChapterScene(Map<String, dynamic> chapter) async {
    String selectedStyle = 'photorealistic';
    final customPromptController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.palette, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('Multi-Style Art Studio'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chapter: ${chapter['title'] ?? 'Chapter ' + chapter['chapter_number'].toString()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Select Visual Art Style:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedStyle,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'photorealistic', child: Text('📸 Photorealistic')),
                  DropdownMenuItem(value: 'anime', child: Text('🎨 Anime / Manga')),
                  DropdownMenuItem(value: 'dark_fantasy', child: Text('🏰 Dark Fantasy')),
                  DropdownMenuItem(value: 'cyberpunk', child: Text('🏙️ Cyberpunk')),
                  DropdownMenuItem(value: 'oil_painting', child: Text('🖼️ Classic Oil Painting')),
                  DropdownMenuItem(value: '3d_render', child: Text('🎬 3D Render (Unreal 5)')),
                  DropdownMenuItem(value: 'comic_book', child: Text('💥 Comic Book Style')),
                ],
                onChanged: (val) => setDialogState(() => selectedStyle = val ?? 'photorealistic'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customPromptController,
                decoration: const InputDecoration(
                  labelText: 'Custom Prompt (Optional)',
                  hintText: 'Describe specific scene actions or mood...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Scene Illustration'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating scene illustration...')));
      try {
        await ApiService.illustrateScene(
          widget.storyId,
          chapterId: chapter['id'],
          customPrompt: customPromptController.text,
          style: selectedStyle,
        );
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Illustration generated successfully!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 15,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            story?['title'] ?? 'Story Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Chapters'),
              Tab(icon: Icon(Icons.route), text: 'Outline & Arc'),
              Tab(icon: Icon(Icons.people), text: 'Characters'),
              Tab(icon: Icon(Icons.forum), text: 'Conversations & Chats'),
              Tab(icon: Icon(Icons.palette), text: 'Visual & Manga Studio'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Keepsake Box'),
              Tab(icon: Icon(Icons.show_chart), text: 'Chemistry Curve'),
              Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Unsent Letters'),
              Tab(icon: Icon(Icons.photo_camera_back_outlined), text: 'Polaroids'),
              Tab(icon: Icon(Icons.flare_outlined), text: 'Sensory Profile'),
              Tab(icon: Icon(Icons.schedule_send_outlined), text: 'Midnight Letters'),
              Tab(icon: Icon(Icons.grain), text: 'Red Thread of Fate'),
              Tab(icon: Icon(Icons.public), text: 'World Lore'),
              Tab(icon: Icon(Icons.map), text: 'World Map'),
              Tab(icon: Icon(Icons.person), text: 'My Persona'),
            ],
          ),
          actions: [
            if (story != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                child: InkWell(
                  onTap: _togglePublishStory,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: story?['is_published'] == true 
                          ? Colors.cyan.withValues(alpha: 0.2) 
                          : Colors.deepOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: story?['is_published'] == true ? Colors.cyanAccent : Colors.deepOrangeAccent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          story?['is_published'] == true ? Icons.public : Icons.lock_outline,
                          size: 14,
                          color: story?['is_published'] == true ? Colors.cyanAccent : Colors.deepOrangeAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          story?['is_published'] == true ? 'Public' : 'Private',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: story?['is_published'] == true ? Colors.cyanAccent : Colors.deepOrangeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (story != null && chapters.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                tooltip: 'AI Story Tools',
                onPressed: _showAiSuiteBottomSheet,
              ),
            if (story != null && chapters.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.cyanAccent),
                tooltip: 'Export Story',
                onPressed: _showExportBottomSheet,
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'info') {
                  _showStoryInfoDialog();
                } else if (value == 'refresh') {
                  _loadData();
                } else if (value == 'settings') {
                  _showStorySettingsDialog();
                } else if (value == 'publish') {
                  _togglePublishStory();
                } else if (value == 'fork') {
                  _forkStory();
                } else if (value == 'delete') {
                  _deleteStoryBook();
                }
              },
              itemBuilder: (BuildContext context) {
                final isPublished = story?['is_published'] == true;
                return [
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [Icon(Icons.info_outline), SizedBox(width: 8), Text('Story Info')],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [Icon(Icons.refresh), SizedBox(width: 8), Text('Refresh Data')],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'publish',
                    child: Row(
                      children: [
                        Icon(isPublished ? Icons.public_off : Icons.public, color: isPublished ? Colors.amber : Colors.cyanAccent),
                        const SizedBox(width: 8),
                        Text(isPublished ? 'Unpublish Story' : 'Publish to Feed'),
                      ],
                    ),
                  ),
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
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete Story', style: TextStyle(color: Colors.red))],
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
            _buildOutlineTab(),
            _buildCharactersTab(),
            _buildConversationsTab(),
            _buildVisualStudioTab(),
            _buildKeepsakeBoxTab(),
            _buildChemistryCurveTab(),
            _buildUnsentLettersTab(),
            _buildPolaroidsTab(),
            _buildSensoryProfileTab(),
            _buildScheduledLettersTab(),
            _buildRedThreadTab(),
            _buildWorldTab(),
            _buildWorldMapTab(),
            _buildUserPersonaTab(),
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
                  if (chapters.isNotEmpty) ...[
                    ActionChip(
                      avatar: const Icon(Icons.headphones, size: 16, color: Colors.amber),
                      label: const Text('Play Audio 🎧', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                      onPressed: () {
                        AudiobookService.instance.startPlaylist(
                          chapters.cast<Map<String, dynamic>>(),
                          0,
                          storyTitle: story?['title'],
                          coverUrl: story?['cover_image_url'],
                        );
                        AudiobookPlayerScreen.show(context);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.theater_comedy, size: 16, color: Colors.purpleAccent),
                      label: const Text('Audio Drama 🎙️', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.purple.withValues(alpha: 0.15),
                      side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                      onPressed: () {
                        final firstChap = chapters.first;
                        AudioDramaSheet.show(
                          context,
                          rawContent: firstChap['content'] ?? '',
                          chapterTitle: firstChap['title'] ?? 'Chapter 1',
                          chapterNumber: firstChap['chapter_number'] ?? 1,
                          storyTitle: story?['title'],
                          coverUrl: story?['cover_image_url'],
                          characters: characters,
                        );
                      },
                    ),
                  ],
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
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ExpansionTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                  title: Text(
                    chapter['title'] ?? 'Chapter ${chapter['chapter_number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Chapter ${chapter['chapter_number']} • ${_getChapterWordCount(chapter)} words',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_book, color: Colors.amber),
                        tooltip: 'Zen Reader Mode',
                        onPressed: () => _openZenReader(chapter),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) {
                          if (action == 'drama') {
                            AudioDramaSheet.show(
                              context,
                              rawContent: chapter['content'] ?? '',
                              chapterTitle: chapter['title'] ?? 'Chapter ${chapter['chapter_number']}',
                              chapterNumber: chapter['chapter_number'],
                              storyTitle: story?['title'],
                              coverUrl: story?['cover_image_url'],
                              characters: characters,
                            );
                          }
                          if (action == 'read') _openZenReader(chapter);
                          if (action == 'edit') _editChapter(chapter);
                          if (action == 'manga') _showMangaComicDialog(chapter);
                          if (action == 'illustrate') _illustrateChapterScene(chapter);
                          if (action == 'pillow_talk') _showPillowTalkDialog(chapter);
                          if (action == 'translate') _showTranslateDialog(chapter['content'] ?? '');
                          if (action == 'delete') _deleteChapter(chapter['chapter_number']);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'read',
                            child: Row(children: [Icon(Icons.menu_book, color: Colors.amber, size: 20), SizedBox(width: 10), Text('Zen Reader Mode')]),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text('Edit Chapter')]),
                          ),
                          const PopupMenuItem(
                            value: 'manga',
                            child: Row(children: [Icon(Icons.auto_stories, color: Colors.cyanAccent, size: 20), SizedBox(width: 10), Text('Generate Manga Comic')]),
                          ),
                          const PopupMenuItem(
                            value: 'illustrate',
                            child: Row(children: [Icon(Icons.palette, color: Colors.purpleAccent, size: 20), SizedBox(width: 10), Text('Illustrate Scene')]),
                          ),
                          const PopupMenuItem(
                            value: 'pillow_talk',
                            child: Row(children: [Icon(Icons.bed, color: Colors.pinkAccent, size: 20), SizedBox(width: 10), Text('Pillow Talk Epilogue')]),
                          ),
                          const PopupMenuItem(
                            value: 'translate',
                            child: Row(children: [Icon(Icons.translate, color: Colors.green, size: 20), SizedBox(width: 10), Text('Translate Chapter')]),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 10), Text('Delete Chapter', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.menu_book, size: 16, color: Colors.amber),
                            label: const Text('Read'),
                            onPressed: () => _openZenReader(chapter),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.bed, size: 16, color: Colors.pinkAccent),
                            label: const Text('Pillow Talk'),
                            onPressed: () => _showPillowTalkDialog(chapter),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.edit, size: 16, color: Colors.blue),
                            label: const Text('Edit'),
                            onPressed: () => _editChapter(chapter),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.auto_stories, size: 16, color: Colors.cyanAccent),
                            label: const Text('Manga'),
                            onPressed: () => _showMangaComicDialog(chapter),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.palette, size: 16, color: Colors.purpleAccent),
                            label: const Text('Illustrate'),
                            onPressed: () => _illustrateChapterScene(chapter),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.translate, size: 16, color: Colors.green),
                            label: const Text('Translate'),
                            onPressed: () => _showTranslateDialog(chapter['content'] ?? ''),
                          ),
                        ],
                      ),
                    ),
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

  int _getChapterWordCount(Map<String, dynamic> chapter) {
    String text = _getPlainText(chapter['content'] ?? '');
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
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
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await context.push('/character_image_studio', extra: {
                      'storyId': widget.storyId,
                    });
                    if (res == true) {
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                  label: const Text('Create Character (AI Studio)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.purple[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _showAddCharacterDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Manual'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _showRelationshipMapDialog,
                icon: const Icon(Icons.share),
                tooltip: 'Relationships',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                final session = await ApiService.getActiveGroupChat(widget.storyId);
                if (context.mounted) {
                  context.push('/group_chat', extra: {
                    'storyId': widget.storyId,
                    'sessionId': session['id'].toString(),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: OutlinedButton.icon(
            onPressed: _updateAllCharacterChemistry,
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            label: const Text('❤️‍🔥 Dynamic Chemistry & Passion Gauge', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: Colors.pinkAccent, width: 1.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => TensionDialSheet.show(context, widget.storyId),
                  icon: const Icon(Icons.tune, size: 16, color: Colors.amber),
                  label: const Text('Tension Dial 🖤', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => DestinyTarotDialog.show(context, widget.storyId),
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.purpleAccent),
                  label: const Text('Destiny Tarot 🔮', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ClimaxMilestoneDialog.show(context, widget.storyId),
                  icon: const Icon(Icons.ring_volume, size: 16, color: Colors.pinkAccent),
                  label: const Text('Proposal Climax 💍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[900]?.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => NarrativeTimelineSheet.show(context, widget.storyId),
                  icon: const Icon(Icons.link, size: 16, color: Colors.blueAccent),
                  label: const Text('Story Timeline 🔗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900]?.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                    final avatar = char['avatar_base64'];
                    final charName = char['name'] ?? 'Unknown Character';
                    final role = char['role'] ?? 'Lead';
                    final gender = char['gender'] ?? 'N/A';
                    final relationship = char['relationship_status'];
                    final activeWardrobe = char['active_wardrobe'];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      color: const Color(0xFF161522),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. TOP HEADER: Large Avatar + Name + Badges + PopupMenu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 90,
                                      maxWidth: 1080,
                                      maxHeight: 1080,
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
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.6), width: 2),
                                      image: (avatar != null && avatar.toString().isNotEmpty)
                                          ? DecorationImage(
                                              image: (avatar.toString().startsWith('http')
                                                  ? NetworkImage(avatar.toString())
                                                  : MemoryImage(base64Decode(avatar.toString()))) as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: Colors.purple[900]?.withValues(alpha: 0.4),
                                    ),
                                    child: (avatar == null || avatar.toString().isEmpty)
                                        ? const Icon(Icons.person, color: Colors.white70, size: 30)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        charName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 19,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
                                            ),
                                            child: Text(
                                              role,
                                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              gender,
                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ),
                                          if (relationship != null && relationship.toString().isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: Colors.pink.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.35)),
                                              ),
                                              child: Text(
                                                relationship.toString(),
                                                style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white60),
                                  color: const Color(0xFF221F33),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (val) async {
                                    if (val == 'studio') {
                                      final res = await context.push('/character_image_studio', extra: {
                                        'storyId': widget.storyId,
                                        'existingCharacter': char,
                                      });
                                      if (res == true) _loadData();
                                    } else if (val == 'edit') {
                                      _showEditCharacterDialog(char);
                                    } else if (val == 'delete') {
                                      bool confirm = await showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Character'),
                                          content: Text('Are you sure you want to delete $charName?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                          ],
                                        ),
                                      ) ?? false;
                                      if (confirm) {
                                        await ApiService.deleteCharacter(widget.storyId, char['id']);
                                        _loadData();
                                      }
                                    }
                                  },
                                  itemBuilder: (c) => [
                                    const PopupMenuItem(
                                      value: 'studio',
                                      child: Row(
                                        children: [
                                          Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 18),
                                          SizedBox(width: 8),
                                          Text('AI Image Studio'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.amber, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 2. ACTION BUTTONS ROW (Chat, Routine, Voicemails, Wardrobe)
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      context.push('/character_chat', extra: {
                                        'characterId': char['id'],
                                        'characterName': charName,
                                        'backgroundImage': char['avatar_base64'],
                                      });
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                                    label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    onPressed: () => LiveRoutineSheet.show(context, char, onInteraction: _loadData),
                                    icon: const Icon(Icons.access_time, size: 15, color: Colors.amberAccent),
                                    label: const Text('Routine ☕', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber[900]?.withValues(alpha: 0.6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () => CharacterVoicemailsSheet.show(context, char),
                                  icon: const Icon(Icons.mic, color: Colors.tealAccent, size: 18),
                                  tooltip: 'Midnight Voicemails',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  onPressed: () => WardrobeClosetSheet.show(context, char, onEquipped: _loadData),
                                  icon: const Icon(Icons.checkroom, color: Colors.purpleAccent, size: 18),
                                  tooltip: 'Wardrobe Closet',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.purple.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),

                            // 3. Active Wardrobe tag (if equipped)
                            if (activeWardrobe != null && activeWardrobe.toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.checkroom, size: 14, color: Colors.purpleAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Attire: $activeWardrobe',
                                        style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // 4. Dynamic Chemistry & Passion Gauge
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1929),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.favorite, color: Colors.pinkAccent, size: 15),
                                          SizedBox(width: 6),
                                          Text('Chemistry & Bond Gauge', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                                        child: Text(char['romantic_status'] ?? 'Guarded', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('🔥 Passion', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                      const Spacer(),
                                      Text('${char['passion_level'] ?? 50}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ((char['passion_level'] ?? 50) as int) / 100.0,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text('🥀 Vulnerability', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                      const Spacer(),
                                      Text('${char['vulnerability_level'] ?? 30}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ((char['vulnerability_level'] ?? 30) as int) / 100.0,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 5. Personality & Appearance details
                            if (char['personality'] != null && char['personality'].toString().isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.psychology, size: 14, color: Colors.amberAccent),
                                        SizedBox(width: 5),
                                        Text('Personality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      char['personality'] ?? 'N/A',
                                      style: const TextStyle(height: 1.35, fontSize: 13, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            if (char['appearance'] != null && char['appearance'].toString().isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.face, size: 14, color: Colors.cyanAccent),
                                        SizedBox(width: 5),
                                        Text('Appearance & Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      char['appearance'] ?? 'N/A',
                                      style: const TextStyle(height: 1.35, fontSize: 13, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddWorldItemDialog(),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Lore'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _autoExtractLore,
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                  label: const Text('AI Auto-Extract'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.purple[800],
                  ),
                ),
              ),
            ],
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
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final res = await context.push('/character_image_studio', extra: {
                        'storyId': widget.storyId,
                      });
                      if (res == true) {
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.purple[900]!, Colors.amber[900]!]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Open AI Character Image Studio (Prompt, Regenerate & Details)',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
                        ],
                      ),
                    ),
                  ),
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
                              imageQuality: 90,
                              maxWidth: 1080,
                              maxHeight: 1080,
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

  void _showEditCharacterDialog(Map<String, dynamic> char) {
    final nameController = TextEditingController(text: char['name'] ?? '');
    final roleController = TextEditingController(text: char['role'] ?? '');
    final genderController = TextEditingController(text: char['gender'] ?? '');
    final personalityController = TextEditingController(text: char['personality'] ?? '');
    final appearanceController = TextEditingController(text: char['appearance'] ?? '');
    final relationshipController = TextEditingController(text: char['relationship_status'] ?? '');
    final dialogueStyleController = TextEditingController(text: char['dialogue_style'] ?? '');
    String? base64Image = char['avatar_base64'];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Character'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (base64Image != null && base64Image!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: (base64Image!.startsWith('http')
                            ? NetworkImage(base64Image!)
                            : MemoryImage(base64Decode(base64Image!))) as ImageProvider,
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
                              imageQuality: 90,
                              maxWidth: 1080,
                              maxHeight: 1080,
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
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteCharacter(char['id']);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  try {
                    final updateData = <String, dynamic>{
                      'name': nameController.text.trim(),
                      'role': roleController.text.trim(),
                      'gender': genderController.text.trim(),
                      'personality': personalityController.text.trim(),
                      'appearance': appearanceController.text.trim(),
                      'relationship_status': relationshipController.text.trim(),
                      'dialogue_style': dialogueStyleController.text.trim(),
                    };
                    if (base64Image != null) {
                      updateData['avatar_base64'] = base64Image;
                    }
                    await ApiService.updateCharacter(widget.storyId, char['id'], updateData);
                    if (mounted) Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save Changes'),
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
    final customRulesController = TextEditingController(text: story!['custom_rules'] ?? '');
    
    final tonesList = [
      '🎭 Comedy & Banter (Witty Banter, Romantic Comedy, Slapstick & Humor)',
      '⚡ High Action & Adventure (Action-Packed, High-Stakes Battles, Martial Arts)',
      '❤️‍🔥 Flirty & Flattery (Flirty & Charming, Playful Teasing, Sweet Seduction)',
      '🖤 Dark & Taboo (Dark Fantasy, Taboo Romance, Gritty Realism, Gothic)',
      '🕵️ Mystery & Thriller (Suspenseful, Psychological Thriller, Noir Detective)',
      '🌸 Wholesome & Slice of Life (Cozy & Comforting, Heartfelt, Sweet & Vanilla)',
      '👑 Royal & High Society (Palace Intrigue, Aristocratic Court Drama, Throne Rivals)',
      '🐉 Epic Fantasy & Mythology (Magic & Sorcery, Gods & Deities, Dragon Realm)',
      '🚀 Sci-Fi & Cyberpunk (Futuristic Cyberpunk, Space Opera, AI Romance)',
      '🐺 Supernatural & Shifters (Alpha Pack, Vampire Clan, Demon/Angel Wars)',
      '🗡️ Revenge & Anti-Hero (Vengeance Arc, Dark Mastermind, Betrayal & Power)',
      '🏫 Academy & Campus (Magic Academy, Elite University, Campus Rivalry)',
      '💋 Mafia & Underworld (Dark Mafia Empire, Crime Syndicate, Obsession)',
      '🏝️ Isekai & Reincarnation (Transmigration, Reborn as Villainess, LitRPG)',
      '💍 Arranged Marriage & Forced Proximity (Contract Marriage, Trapped Together)',
      '🔥 Erotic & Dynamic Roles (Dominant/Submissive, Master/Servant, Bondage)',
      '⏳ Time Travel & Timelines (Time Loop, Butterfly Effect, Time Paradox)',
      '🦸 Superhero & Vigilante (Superpowers, Secret Identity, Masked Vigilante)',
      '⛵ Pirates & High Seas (Pirate Crew, High Seas Adventure, Siren Mythos)',
      '🎪 Horror & Survival (Supernatural Horror, Zombie Apocalypse, Deadly Game)',
      'Passionate',
      'Dark & Steamy',
    ];

    String selectedTone = story!['tone'] ?? tonesList.first;
    if (!tonesList.contains(selectedTone)) {
      tonesList.insert(0, selectedTone);
    }

    // Parse existing nsfw_preferences
    final existingNsfw = story!['nsfw_preferences'] ?? '';
    final nsfwController = TextEditingController(text: existingNsfw);
    
    String romancePacing = 'Slow Burn';
    String dynamicRole = 'Balanced';
    String sensoryDetail = 'High Sensual Focus';
    String intimacyLevel = story!['intimacy_level'] ?? 'explicit';
    bool jealousyTrigger = story!['jealousy_trigger'] ?? false;
    String povMode = story!['pov_mode'] ?? 'Standard';

    final intimacyLabels = {
      'mild': '🌸 Mild Romance',
      'passionate': '🔥 Passionate & Sensual',
      'explicit': '🔞 Explicit Uncensored',
    };

    final povOptions = [
      'Standard',
      'Dual-POV Alternating (His & Her)',
      'First Person (Male Lead)',
      'First Person (Female Lead)',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Row(
              children: [
                Icon(Icons.palette, color: Colors.amber),
                SizedBox(width: 8),
                Text('Story Settings & Themes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 8),
                  TextField(controller: synopsisController, decoration: const InputDecoration(labelText: 'Synopsis'), maxLines: 3),
                  const SizedBox(height: 8),
                  TextField(controller: genreController, decoration: const InputDecoration(labelText: 'Genre')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedTone,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '🎭 Story Theme & Mood Preset'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: tonesList.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setDialogState(() => selectedTone = val!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: povOptions.contains(povMode) ? povMode : 'Standard',
                    decoration: const InputDecoration(labelText: '🎭 Point of View (POV) Style'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: povOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) => setDialogState(() => povMode = val!),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.pinkAccent,
                    title: const Text('⚡ Dynamic Jealousy & Rivalry', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Introduce protective jealousy, rival suitors, and possessive tension', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    value: jealousyTrigger,
                    onChanged: (val) => setDialogState(() => jealousyTrigger = val),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: customRulesController, decoration: const InputDecoration(labelText: 'Custom AI Story Rules'), maxLines: 2),
                  const Divider(color: Colors.white24, height: 24),
                  const Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.pinkAccent, size: 20),
                      SizedBox(width: 6),
                      Text('🔞 NSFW & Erotic Trope Preferences', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: intimacyLevel,
                    decoration: const InputDecoration(labelText: '🔥 Intimacy & Heat Intensity Slider / Setting'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: intimacyLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (val) => setDialogState(() => intimacyLevel = val!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: romancePacing,
                    decoration: const InputDecoration(labelText: 'Romance & Tension Pacing'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: ['Slow Burn', 'Instant Passion', 'Teasing & Tension', 'Balanced']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) => setDialogState(() => romancePacing = val!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: dynamicRole,
                    decoration: const InputDecoration(labelText: 'Character Dynamics'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: ['Dominant / Submissive', 'Sworn Enemies to Lovers', 'Equals / Switch', 'Playful Rivalry']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setDialogState(() => dynamicRole = val!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: sensoryDetail,
                    decoration: const InputDecoration(labelText: 'Sensory Detail Focus'),
                    dropdownColor: const Color(0xFF2C2C3E),
                    items: ['High Sensual Focus', 'Action & Plot Focus', 'Balanced']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setDialogState(() => sensoryDetail = val!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nsfwController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Custom Kinks, Tropes & Erotic Preferences',
                      hintText: 'e.g. Forbidden romance, secret encounters, intense emotional dialogue, dominant heroine...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  try {
                    final combinedNsfw = 'Pacing: $romancePacing\nDynamics: $dynamicRole\nDetail: $sensoryDetail\nCustom Tropes: ${nsfwController.text.trim()}';
                    await ApiService.updateStory(widget.storyId, {
                      'title': titleController.text,
                      'synopsis': synopsisController.text,
                      'genre': genreController.text,
                      'tone': selectedTone,
                      'custom_rules': customRulesController.text,
                      'nsfw_preferences': combinedNsfw,
                      'intimacy_level': intimacyLevel,
                      'jealousy_trigger': jealousyTrigger,
                      'pov_mode': povMode,
                    });
                    if (mounted) Navigator.pop(context);
                    _loadData(); // Refresh UI
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating story: $e')));
                  }
                },
                child: const Text('Save Settings', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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

  Widget _buildUserPersonaTab() {
    final hasStoryPersona = (story?['user_persona_name'] != null && story!['user_persona_name'].toString().trim().isNotEmpty) ||
        (story?['user_persona_personality'] != null && story!['user_persona_personality'].toString().trim().isNotEmpty) ||
        (story?['user_persona_appearance'] != null && story!['user_persona_appearance'].toString().trim().isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin, size: 28, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              hasStoryPersona ? 'Story Protagonist Persona' : 'Global Persona (Fallback)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showEditUserPersonaDialog,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(hasStoryPersona ? 'Edit Persona' : 'Set Custom Persona'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (!hasStoryPersona) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This story currently relies on your global account persona. Tap "Set Custom Persona" above to define a custom role/persona for this story!',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildPersonaDetailRow('Character Name', story?['user_persona_name'] ?? ''),
                  const SizedBox(height: 12),
                  _buildPersonaDetailRow('Age', story?['user_persona_age']?.toString() ?? ''),
                  const SizedBox(height: 12),
                  _buildPersonaDetailRow('Appearance', story?['user_persona_appearance'] ?? ''),
                  const SizedBox(height: 12),
                  _buildPersonaDetailRow('Personality', story?['user_persona_personality'] ?? ''),
                  const SizedBox(height: 12),
                  _buildPersonaDetailRow('Backstory / Role in Story', story?['user_persona_backstory'] ?? ''),
                  if (hasStoryPersona) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _clearStoryPersona,
                      icon: const Icon(Icons.clear, color: Colors.red),
                      label: const Text('Reset to Global Persona', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value.trim().isEmpty ? 'Not set' : value, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Future<void> _showEditUserPersonaDialog() async {
    final nameCtrl = TextEditingController(text: story?['user_persona_name'] ?? '');
    final ageCtrl = TextEditingController(text: story?['user_persona_age']?.toString() ?? '');
    final appearanceCtrl = TextEditingController(text: story?['user_persona_appearance'] ?? '');
    final personalityCtrl = TextEditingController(text: story?['user_persona_personality'] ?? '');
    final backstoryCtrl = TextEditingController(text: story?['user_persona_backstory'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Story User Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Character Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appearanceCtrl,
                decoration: const InputDecoration(labelText: 'Appearance', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: personalityCtrl,
                decoration: const InputDecoration(labelText: 'Personality Traits', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: backstoryCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Backstory / Role in Story', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updateData = {
                'user_persona_name': nameCtrl.text.trim(),
                'user_persona_age': int.tryParse(ageCtrl.text.trim()),
                'user_persona_appearance': appearanceCtrl.text.trim(),
                'user_persona_personality': personalityCtrl.text.trim(),
                'user_persona_backstory': backstoryCtrl.text.trim(),
              };
              try {
                await ApiService.updateStory(widget.storyId, updateData);
                _loadData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating persona: $e')));
              }
            },
            child: const Text('Save Persona'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearStoryPersona() async {
    final updateData = {
      'user_persona_name': null,
      'user_persona_age': null,
      'user_persona_appearance': null,
      'user_persona_personality': null,
      'user_persona_backstory': null,
    };
    try {
      await ApiService.updateStory(widget.storyId, updateData);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteStoryBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story Book'),
        content: Text('Are you sure you want to delete "${story?['title'] ?? 'this story'}"? All chapters and characters will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteStory(widget.storyId);
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting story: $e')));
      }
    }
  }



  Widget _buildArtGalleryTab() {
    if (illustrations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.palette_outlined, size: 64, color: Colors.purpleAccent),
              const SizedBox(height: 16),
              const Text(
                'No Scene Artwork Yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to the Chapters tab and tap the 🎨 palette icon on any chapter to generate visual novel artwork!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _illustrateChapterScene({}),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Illustrate Story Cover Scene'),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: illustrations.length,
      itemBuilder: (context, index) {
        final item = illustrations[index];
        final String imgUrl = item['image_base64'] ?? '';
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _viewFullIllustration(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imgUrl.startsWith('http')
                    ? Image.network(imgUrl, fit: BoxFit.cover)
                    : Image.memory(base64Decode(imgUrl), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      item['caption'] ?? 'Scene Artwork',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewFullIllustration(Map<String, dynamic> item) {
    final String imgUrl = item['image_base64'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                imgUrl.startsWith('http')
                    ? Image.network(imgUrl, fit: BoxFit.contain)
                    : Image.memory(base64Decode(imgUrl), fit: BoxFit.contain),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['caption'] ?? 'Scene Artwork',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ApiService.deleteIllustration(widget.storyId, item['id']);
                      _loadData();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldMapTab() {
    final filteredLocs = locations.where((l) {
      final name = (l['name'] ?? '').toString().toLowerCase();
      final region = (l['region'] ?? '').toString().toLowerCase();
      final desc = (l['description'] ?? '').toString().toLowerCase();
      final q = locationSearchQuery.toLowerCase();
      return name.contains(q) || region.contains(q) || desc.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search locations...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => locationSearchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddLocationDialog,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredLocs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No world locations added yet.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showAddLocationDialog,
                      child: const Text('Pin Your First Location'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredLocs.length,
                itemBuilder: (context, index) {
                  final loc = filteredLocs[index];
                  final name = loc['name'] ?? 'Unnamed Location';
                  final region = loc['region'] ?? 'Unknown Region';
                  final desc = loc['description'] ?? '';
                  final tags = (loc['character_tags'] as List<dynamic>?)?.join(', ') ?? '';

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.deepPurpleAccent),
                                ),
                                child: Text(
                                  region,
                                  style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              desc,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 14, color: Colors.amberAccent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Tags: $tags',
                                    style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Delete Location',
                                onPressed: () => _deleteWorldLocation(loc['id'].toString()),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.bolt, size: 16),
                                label: const Text('Start Scene Here'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pinkAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final promptText = 'Starting scene at location: "$name" ($region).\nSetting: $desc\nKey characters present: ${tags.isNotEmpty ? tags : "Main cast"}';
                                  await context.push('/story/${widget.storyId}/director', extra: {
                                    'chapterCount': chapters.length,
                                    'initialPrompt': promptText,
                                  });
                                  _loadData();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddLocationDialog() async {
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController(text: 'Kingdom / City');
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add World Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Location Name', hintText: 'e.g. Castle Ravenhold'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: regionCtrl,
                decoration: const InputDecoration(labelText: 'Region / Category', hintText: 'e.g. Northern Reaches, Tavern, Dungeon'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description & Atmosphere', hintText: 'Atmospheric details, history, sensory descriptions...'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagsCtrl,
                decoration: const InputDecoration(labelText: 'Associated Characters (Comma separated)', hintText: 'e.g. Lord Malakor, Lyra'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Location'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final tagsList = tagsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        final newLoc = await ApiService.createWorldLocation(widget.storyId, {
          'name': nameCtrl.text.trim(),
          'region': regionCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'character_tags': tagsList,
        });
        setState(() {
          locations.insert(0, newLoc);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location pinned to map!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding location: $e')));
      }
    }
  }

  Future<void> _deleteWorldLocation(String locationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: const Text('Are you sure you want to remove this location from the map?'),
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
        await ApiService.deleteWorldLocation(widget.storyId, locationId);
        setState(() {
          locations.removeWhere((l) => l['id'].toString() == locationId);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location deleted.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting location: $e')));
      }
    }
  }

  Future<void> _showSocialFeedDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Loading character social feed...'),
          ],
        ),
      ),
    );

    try {
      List<dynamic> posts = await ApiService.getSocialFeed(widget.storyId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF181824),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_android, color: Colors.greenAccent, size: 28),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Character Social Feed 📱', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                          icon: const Icon(Icons.add_a_photo, size: 16),
                          label: const Text('New Post'),
                          onPressed: () async {
                            try {
                              final newPost = await ApiService.generateSocialPost(widget.storyId);
                              posts.insert(0, newPost);
                              setSheetState(() {});
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating post: $e')));
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    if (posts.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.post_add, color: Colors.grey, size: 48),
                              const SizedBox(height: 12),
                              const Text('No character posts yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final newPost = await ApiService.generateSocialPost(widget.storyId);
                                    posts.insert(0, newPost);
                                    setSheetState(() {});
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                child: const Text('Generate First Post'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: posts.length,
                          itemBuilder: (context, idx) {
                            final post = posts[idx];
                            final charName = post['character_name'] ?? 'Character';
                            final content = post['content'] ?? '';
                            final likes = post['likes_count'] ?? 0;
                            final comments = (post['comments'] as List<dynamic>?) ?? [];
                            final commentCtrl = TextEditingController();

                            return Card(
                              color: const Color(0xFF252538),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.pinkAccent,
                                          child: Text(charName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(charName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.pinkAccent),
                                          label: const Text('DM', style: TextStyle(color: Colors.pinkAccent)),
                                          onPressed: () {
                                            if (post['character_id'] != null) {
                                              Navigator.pop(ctx);
                                              context.push('/character_chat/${post['character_id']}', extra: {'characterName': charName});
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(content, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                                          onPressed: () async {
                                            try {
                                              final res = await ApiService.likeSocialPost(post['id'].toString());
                                              post['likes_count'] = res['likes_count'];
                                              setSheetState(() {});
                                            } catch (_) {}
                                          },
                                        ),
                                        Text('$likes likes', style: const TextStyle(color: Colors.white70)),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.mode_comment_outlined, color: Colors.cyanAccent, size: 20),
                                        const SizedBox(width: 4),
                                        Text('${comments.length} comments', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                    if (comments.isNotEmpty) ...[
                                      const Divider(color: Colors.white12),
                                      ...comments.map((c) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(text: '${c['author_name']}: ', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                                              TextSpan(text: c['content'] ?? '', style: const TextStyle(color: Colors.white70)),
                                            ],
                                          ),
                                        ),
                                      )),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: commentCtrl,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: const InputDecoration(
                                              hintText: 'Add a comment...',
                                              hintStyle: TextStyle(color: Colors.white38),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.send, color: Colors.cyanAccent, size: 20),
                                          onPressed: () async {
                                            if (commentCtrl.text.trim().isNotEmpty) {
                                              try {
                                                final newComment = await ApiService.commentSocialPost(post['id'].toString(), commentCtrl.text.trim());
                                                comments.add(newComment);
                                                commentCtrl.clear();
                                                setSheetState(() {});
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading social feed: $e')));
      }
    }
  }

  Future<void> _showMangaComicDialog(Map<String, dynamic> chapter) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating Manga Comic panels...'),
          ],
        ),
      ),
    );

    try {
      final res = await ApiService.generateMangaComic(chapter['id'].toString());
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final title = res['chapter_title'] ?? 'Manga Comic Page';
      final panels = (res['panels'] as List<dynamic>?) ?? [];

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF101018),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories, color: Colors.amber, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16),
                if (panels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No panels generated.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: panels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        final p = panels[idx];
                        final pNum = p['panel_number'] ?? (idx + 1);
                        final speaker = p['speaker_name'] ?? 'Narration';
                        final dialogue = p['dialogue'] ?? '';
                        final visual = p['visual_description'] ?? '';
                        final imageUrl = p['image_url'] as String?;

                        return Card(
                          color: const Color(0xFF181824),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.white24, width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Panel Top Tag & Speaker
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: const Color(0xFF222234),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                      child: Text('PANEL $pNum', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    Text(speaker, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              // Manga Art Image
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: Colors.black54,
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.black45,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        visual,
                                        style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              // Dialogue & Action Description
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (visual.isNotEmpty) ...[
                                      Text(
                                        visual,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (dialogue.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '"$dialogue"',
                                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating manga comic: $e')));
      }
    }
  }

  Future<void> _showPillowTalkDialog(Map<String, dynamic> chapter) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.pinkAccent),
            SizedBox(width: 20),
            Text('Writing Pillow Talk epilogue...'),
          ],
        ),
      ),
    );

    try {
      final res = await ApiService.generatePillowTalk(chapter['id'].toString());
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final epilogueTitle = res['epilogue_title'] ?? '🥀 Pillow Talk & Afterglow';
      final content = res['content'] ?? '';

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF161622),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bed, color: Colors.pinkAccent, size: 26),
                          const SizedBox(width: 8),
                          Text(epilogueTitle, style: const TextStyle(color: Colors.pinkAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  SelectableText(
                    content,
                    style: const TextStyle(fontSize: 16, height: 1.8, color: Color(0xFFE8E8E8), fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.add),
                    label: const Text('Append to Chapter Content', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final updated = '${chapter['content'] ?? ''}\n\n---\n### 🥀 Pillow Talk & Afterglow Epilogue\n\n$content';
                      await ApiService.updateChapter(widget.storyId, chapter['chapter_number'], {'content': updated});
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pillow Talk epilogue appended to chapter!')));
                        _loadData();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating pillow talk: $e')));
      }
    }
  }

  Future<void> _updateAllCharacterChemistry() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analyzing character chemistry & romantic vulnerability with AI...')),
    );
    try {
      final res = await ApiService.updateCharacterChemistry(widget.storyId);
      if (mounted) {
        final count = res['updated'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully updated romantic chemistry for $count characters!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating chemistry: $e')));
      }
    }
  }

  Future<void> _fetchOutlinePlan() async {
    setState(() => isLoadingOutline = true);
    try {
      final plan = await ApiService.getStoryOutlinePlan(widget.storyId);
      if (mounted) {
        setState(() {
          outlinePlan = plan;
          isLoadingOutline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingOutline = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating outline: $e')));
      }
    }
  }

  Widget _buildOutlineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with Arc Progress
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.route, color: Colors.purpleAccent, size: 24),
                          SizedBox(width: 8),
                          Text('4-Act Novel Arc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: isLoadingOutline ? null : _fetchOutlinePlan,
                        icon: isLoadingOutline 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 14),
                        label: Text(outlinePlan == null ? 'Analyze Arc' : 'Refresh Arc', style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Phase: ${outlinePlan?['current_act'] ?? 'Act I: Inciting Chemistry & The First Spark'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
                  ),
                  if (outlinePlan?['editor_advice'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '💡 Editor Insight: "${outlinePlan!['editor_advice']}"',
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4 Acts Breakdown
          if (outlinePlan != null && outlinePlan!['acts'] != null) ...[
            const Text('Narrative Progression Stages:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...(outlinePlan!['acts'] as List<dynamic>).map((act) {
              final status = (act['status'] ?? 'upcoming').toString().toLowerCase();
              final isCompleted = status.contains('complete');
              final isActive = status.contains('active');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isActive ? Colors.amber : isCompleted ? Colors.green.shade400 : Colors.white12,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    isCompleted ? Icons.check_circle : isActive ? Icons.radio_button_checked : Icons.circle_outlined,
                    color: isCompleted ? Colors.green : isActive ? Colors.amber : Colors.grey,
                  ),
                  title: Text(
                    act['act_name'] ?? 'Act',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isActive ? Colors.amber : Colors.white,
                    ),
                  ),
                  subtitle: Text(act['description'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Chapter Synopsis Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chapter Synopses (${chapters.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Word count / summaries', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 8),
          if (chapters.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No chapters written yet. Start by creating Chapter 1!'),
              ),
            )
          else
            ...chapters.map((ch) {
              final rawContent = ch['content']?.toString() ?? '';
              final words = rawContent.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
              final summary = ch['summary']?.toString() ?? (rawContent.length > 150 ? '${rawContent.substring(0, 150)}...' : rawContent);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ch. ${ch['chapter_number']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ch['title'] ?? 'Chapter',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('$words words', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.isNotEmpty ? summary : 'No summary recorded.',
                        style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),

          // Future Chapter Planner
          const Row(
            children: [
              Icon(Icons.wb_twilight, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 6),
              Text('Future Chapter Planner & Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          if (outlinePlan != null && outlinePlan!['upcoming_chapters'] != null) ...[
            ...(outlinePlan!['upcoming_chapters'] as List<dynamic>).map((futureCh) {
              final title = futureCh['suggested_title'] ?? 'Upcoming Chapter';
              final hook = futureCh['hook'] ?? '';
              final syn = futureCh['synopsis'] ?? '';
              final tension = futureCh['tension_rating'] ?? '🔥 High Tension';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: const Color(0xFF1B1B26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orangeAccent),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tension, style: const TextStyle(fontSize: 11, color: Colors.orange)),
                          ),
                        ],
                      ),
                      if (hook.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('"$hook"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white)),
                      ],
                      const SizedBox(height: 6),
                      Text(syn, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final prompt = 'Write next chapter ($title): $syn. Key hook: $hook';
                            await context.push('/story/${widget.storyId}/director', extra: {
                              'chapterCount': chapters.length,
                              'initialPrompt': prompt,
                            });
                            _loadData();
                          },
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Write in Director ➔', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Tap below to have the AI plan your next 2-3 chapter outlines, hooks, and romantic conflicts.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetchOutlinePlan,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Draft Next Chapter Outlines with AI'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationsTab() {
    final scenarios = [
      {'title': '🍷 Late-Night Dinner & Wine', 'desc': 'Uninhibited conversation, heavy eye contact, guards down.'},
      {'title': '⛈️ Trapped in a Rainstorm', 'desc': 'Soaked through in close quarters, shared body heat.'},
      {'title': '⚡ A Jealous Confrontation', 'desc': 'Territorial friction, unspoken feelings forced to the surface.'},
      {'title': '☕ The Morning After', 'desc': 'Tender whispers, teasing breakfast banter, lingering aftermath.'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1-on-1 Chats Section
          const Row(
            children: [
              Icon(Icons.chat_bubble, color: Colors.pinkAccent, size: 20),
              SizedBox(width: 8),
              Text('Direct Character Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Private 1-on-1 chat threads with characters in this story world.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 12),
          if (characters.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Create characters in this story to begin chatting.'),
              ),
            )
          else
            ...characters.map((char) {
              final name = char['name'] ?? 'Character';
              final role = char['role'] ?? 'Lead';
              final status = char['romantic_status'] ?? 'Guarded';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink.shade900,
                    child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$role • $status', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/character_chat', extra: {
                        'characterId': char['id'],
                        'characterName': name,
                        'backgroundImage': char['avatar_url'],
                      });
                    },
                    icon: const Icon(Icons.chat, size: 14),
                    label: const Text('Chat', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),

          // Group Chat Scenarios
          const Row(
            children: [
              Icon(Icons.groups, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text('Romantic Group Chat Scenarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Put characters into intense shared group conversations and watch their chemistry ignite.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 12),
          ...scenarios.map((sc) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                title: Text(sc['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber)),
                subtitle: Text(sc['desc']!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                trailing: ElevatedButton(
                  onPressed: () async {
                    if (characters.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add characters to this story first!')));
                      return;
                    }
                    try {
                      final session = await ApiService.getActiveGroupChat(widget.storyId);
                      if (mounted) {
                        context.push('/group_chat', extra: {
                          'storyId': widget.storyId,
                          'sessionId': session['id'].toString(),
                        });
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting group chat: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text('Start 👥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVisualStudioTab() {
    final styles = ['Anime/Manga', 'Oil Painting', 'Dark Fantasy', 'Photorealistic'];
    final coverUrl = story?['cover_image_url'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Book Cover Studio
          const Row(
            children: [
              Icon(Icons.palette, color: Colors.cyanAccent, size: 22),
              SizedBox(width: 8),
              Text('Multi-Style Book Cover Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Switch visual art styles and generate stunning high-resolution novel covers.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 12),
          // Style Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: styles.map((st) {
                final isSel = selectedCoverStyle == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(st),
                    selected: isSel,
                    selectedColor: Colors.cyan.shade700,
                    onSelected: (val) {
                      if (val) setState(() => selectedCoverStyle = st);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Cover display
          Center(
            child: Container(
              width: 180,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (coverUrl != null && coverUrl.isNotEmpty)
                    ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCoverPlaceholder())
                    : _buildCoverPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isGeneratingCoverStyle ? null : () async {
              setState(() => isGeneratingCoverStyle = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generating novel cover in $selectedCoverStyle style...')),
              );
              try {
                final res = await ApiService.generateStoryCover(widget.storyId, style: selectedCoverStyle);
                if (mounted) {
                  setState(() {
                    story?['cover_image_url'] = res['cover_image_url'];
                    isGeneratingCoverStyle = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New book cover generated and set! 🎨')),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => isGeneratingCoverStyle = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            icon: isGeneratingCoverStyle 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(isGeneratingCoverStyle ? 'Painting Cover...' : 'Generate Cover in $selectedCoverStyle Style'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Manga Comic Strip Gallery
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_stories, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text('Manga Comic Strips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (chapters.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showMangaComicDialog(chapters.first),
                  icon: const Icon(Icons.visibility, size: 14, color: Colors.amber),
                  label: const Text('Open Comic Strip', style: TextStyle(fontSize: 12, color: Colors.amber)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Turn key scenes and romantic climaxes into 4-panel black & white manga pages with dialogue speech bubbles.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 10),
          if (chapters.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Write chapters to create manga comics.')))
          else
            ...chapters.map((ch) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.collections_bookmark, color: Colors.amber),
                  title: Text(ch['title'] ?? 'Chapter ${ch['chapter_number']}'),
                  trailing: OutlinedButton(
                    onPressed: () => _showMangaComicDialog(ch),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                    child: const Text('View Manga 🎌', style: TextStyle(fontSize: 11, color: Colors.amber)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),

          // Section 3: Scene Illustrations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.image, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Scene Illustrations Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text('${illustrations.length} arts', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 10),
          _buildArtGalleryTab(),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: Colors.deepPurple.shade900,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 50, color: Colors.white54),
            SizedBox(height: 8),
            Text('No Cover Art', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FEATURE 3: THE KEEPSAKE BOX
  // ==========================================

  Future<void> _fetchStoryKeepsakes() async {
    setState(() => isLoadingKeepsakes = true);
    try {
      final res = await ApiService.getStoryKeepsakes(widget.storyId);
      if (mounted) {
        setState(() {
          storyKeepsakes = res;
          isLoadingKeepsakes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingKeepsakes = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load keepsakes: $e')));
      }
    }
  }

  void _showKeepsakeDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1424),
        title: Row(
          children: [
            Text(item['icon']?.toString() ?? '🕯️', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item['name']?.toString() ?? 'Story Keepsake',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.people, size: 14, color: Colors.pinkAccent),
                    label: Text(item['characters_involved']?.toString() ?? 'The Leads', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                  Chip(
                    avatar: const Icon(Icons.auto_stories, size: 14, color: Colors.amber),
                    label: Text(item['chapter_context']?.toString() ?? 'Chapter Context', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                  Chip(
                    avatar: const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                    label: Text(item['emotional_weight']?.toString() ?? 'High Weight', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('The Moment It Was Exchanged:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '“${item['moment_exchanged']?.toString() ?? ''}”',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, height: 1.4, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Secret Internal Reflection:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item['character_reflection']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Box', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepsakeBoxTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keepsake Box Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade900.withValues(alpha: 0.4), Colors.pink.shade900.withValues(alpha: 0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🕯️', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The Keepsake Box',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Emotional physical tokens exchanged between the leads throughout the novel.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isLoadingKeepsakes ? null : _fetchStoryKeepsakes,
                  icon: isLoadingKeepsakes
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.inventory_2, size: 16),
                  label: Text(storyKeepsakes == null ? 'Open Box' : 'Scan', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoadingKeepsakes) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 12),
                    Text('Unlocking keepsakes and memories from your chapters...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (storyKeepsakes == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.amber.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('The Keepsake Box is closed.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('Tap "Open Box" above to collect tokens, gifts, and letters exchanged across the novel.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ] else if (storyKeepsakes!.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No emotional keepsakes discovered yet in your chapters.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ] else ...[
            Text('Discovered Mementos (${storyKeepsakes!.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: storyKeepsakes!.length,
              itemBuilder: (ctx, i) {
                final item = storyKeepsakes![i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.25)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showKeepsakeDetailDialog(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.amber.shade900.withValues(alpha: 0.4),
                                child: Text(item['icon']?.toString() ?? '💍', style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name']?.toString() ?? 'Memento',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['characters_involved']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.pink.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['chapter_context']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 10, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '“${item['moment_exchanged']?.toString() ?? ''}”',
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showKeepsakeDetailDialog(item),
                                icon: const Icon(Icons.auto_stories, size: 14, color: Colors.pinkAccent),
                                label: const Text('Read Secret Reflection', style: TextStyle(fontSize: 11, color: Colors.pinkAccent)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FEATURE 5: ROMANTIC HEAT & TENSION CURVE
  // ==========================================

  Future<void> _fetchChemistryCurve() async {
    setState(() => isLoadingChemistryCurve = true);
    try {
      final res = await ApiService.getChemistryCurve(widget.storyId);
      if (mounted) {
        setState(() {
          chemistryCurveData = res;
          isLoadingChemistryCurve = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingChemistryCurve = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load chemistry curve: $e')));
      }
    }
  }

  Widget _buildChemistryCurveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Studio Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900.withValues(alpha: 0.4), Colors.deepOrange.shade900.withValues(alpha: 0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📈', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Novel Chemistry & Heat Curve',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrangeAccent),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Visual emotional waveform tracking tension, angst, and romantic intimacy across every chapter.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isLoadingChemistryCurve ? null : _fetchChemistryCurve,
                  icon: isLoadingChemistryCurve
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.show_chart, size: 16),
                  label: Text(chemistryCurveData == null ? 'Analyze' : 'Refresh', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoadingChemistryCurve) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.deepOrangeAccent),
                    SizedBox(height: 12),
                    Text('Analyzing novel emotional waveform & heat peaks...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (chemistryCurveData == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.show_chart, size: 64, color: Colors.deepOrange.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Chemistry Curve not generated yet.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('Tap "Analyze" above to map the slow-burn tension and heat levels for every chapter.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Pacing Insights Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pacing Health: ${chemistryCurveData!['pacing_health'] ?? 'Balanced'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🔥 Peak Heat: Ch ${chemistryCurveData!['highest_heat_chapter'] ?? '1'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
                          ),
                        ),
                      ],
                    ),
                    if (chemistryCurveData!['editor_recommendation'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '💡 Editor Guidance: "${chemistryCurveData!['editor_recommendation']}"',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purpleAccent, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    const Text('⚡ Tension & Friction', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.deepOrangeAccent, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    const Text('🔥 Intimacy & Heat', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chapter Waveform Cards
            Builder(
              builder: (ctx) {
                final chaptersList = (chemistryCurveData!['chapters_analysis'] as List<dynamic>? ?? []);
                if (chaptersList.isEmpty) {
                  return const Center(child: Text('No chapter analyses returned.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: chaptersList.length,
                  itemBuilder: (ctx, i) {
                    final item = chaptersList[i] as Map<String, dynamic>;
                    final chNum = item['chapter_number'] ?? (i + 1);
                    final title = item['title'] ?? 'Chapter $chNum';
                    final pov = item['pov_character'] ?? '';
                    final tension = ((item['tension_score'] ?? 5) as num).clamp(0, 10).toDouble();
                    final heat = ((item['heat_score'] ?? 2) as num).clamp(0, 10).toDouble();
                    final event = item['romantic_event']?.toString() ?? '';
                    final verdict = item['chemistry_verdict']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Ch $chNum: $title',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const Spacer(),
                                if (pov.toString().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'POV: $pov',
                                      style: const TextStyle(fontSize: 10, color: Colors.cyanAccent),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Tension Metric Bar
                            Row(
                              children: [
                                const Text('⚡ Tension:', style: TextStyle(fontSize: 11, color: Colors.purpleAccent)),
                                const Spacer(),
                                Text('${tension.toInt()}/10', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: tension / 10.0,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Heat Metric Bar
                            Row(
                              children: [
                                const Text('🔥 Heat:', style: TextStyle(fontSize: 11, color: Colors.deepOrangeAccent)),
                                const Spacer(),
                                Text('${heat.toInt()}/10', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: heat / 10.0,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrangeAccent),
                                minHeight: 6,
                              ),
                            ),
                            if (event.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                event,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                            if (verdict.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.pink.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Verdict: $verdict',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.pinkAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FEATURE 1: UNSENT LETTERS & BURN-AFTER-READING
  // ==========================================

  Widget _buildCrossedOutText(String text, {double fontSize = 14, Color defaultColor = Colors.white}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'~~(.*?)~~');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(fontSize: fontSize, color: defaultColor, height: 1.5),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white38,
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.redAccent,
          decorationThickness: 2.0,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(fontSize: fontSize, color: defaultColor, height: 1.5),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  Future<void> _fetchUnsentLetters() async {
    setState(() => isLoadingUnsentLetters = true);
    try {
      final res = await ApiService.getUnsentLetters(widget.storyId);
      if (mounted) {
        setState(() {
          storyUnsentLetters = res;
          isLoadingUnsentLetters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingUnsentLetters = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load unsent letters: $e')));
      }
    }
  }

  void _showLetterDialog(Map<String, dynamic> letter) {
    final letterId = letter['id']?.toString() ?? UniqueKey().toString();
    setState(() {
      _brokenWaxSeals.add(letterId);
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1424),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Text('💌', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter['letter_title']?.toString() ?? 'Unsent Letter',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  Text(
                    '${letter['author_name'] ?? 'Author'} ➔ ${letter['recipient_name'] ?? 'Recipient'}',
                    style: const TextStyle(fontSize: 12, color: Colors.pinkAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 14, color: Colors.amber),
                    label: Text(letter['time_context']?.toString() ?? 'Secret Moment', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                  Chip(
                    avatar: const Icon(Icons.local_fire_department, size: 14, color: Colors.deepOrangeAccent),
                    label: Text(letter['burn_status']?.toString() ?? 'Unsent', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: _buildCrossedOutText(
                  letter['letter_body']?.toString() ?? '',
                  fontSize: 14,
                  defaultColor: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.white38),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Crossed-out lines show moments of hesitation before the thought was censored.',
                      style: TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔥 The note was consigned to ash. Its secrets remain between the pages.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent, size: 16),
            label: const Text('Consign to Ash', style: TextStyle(color: Colors.deepOrangeAccent)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showWaxSealReplyDialog(
                recipientName: letter['author_name']?.toString() ?? 'Character',
              );
            },
            icon: const Icon(Icons.history_edu, size: 16),
            label: const Text('Wax-Sealed Reply 💌'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fold & Keep', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BATCH 4 FEATURE: 💌 WAX-SEALED REPLY DISPATCH
  // ==========================================

  void _showWaxSealReplyDialog({String? recipientName}) {
    String selectedRecipient = recipientName ?? (characters.isNotEmpty ? (characters.first['name'] ?? 'Male Lead') : 'Character');
    String selectedStationery = 'Parchment';
    String selectedWax = 'Crimson';
    final replyController = TextEditingController();
    double stampProgress = 0.0;
    Timer? stampTimer;

    final quickReplies = [
      'I found your note under the door. You didn\'t have to cross out what you truly felt...',
      'I am still awake too. Don\'t walk away without saying goodbye tomorrow.',
      'I heard every word you didn\'t have the courage to say out loud.',
      'Meet me on the balcony when the rain stops. No masks, no secrets.',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF19111E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Color waxColor;
            switch (selectedWax) {
              case 'Imperial Gold':
                waxColor = const Color(0xFFD4AF37);
                break;
              case 'Rose Gold':
                waxColor = const Color(0xFFB76E79);
                break;
              case 'Crimson':
              default:
                waxColor = const Color(0xFFB71C1C);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: waxColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Text('💌', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Wax-Sealed Reply Dispatch',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Send an intimate, physical-style letter back to $selectedRecipient',
                                style: const TextStyle(fontSize: 12, color: Colors.pinkAccent),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Choose Stationery
                    const Text('Stationery Style:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['Parchment', 'Midnight Silk', 'Black Gold'].map((s) {
                        final isSel = selectedStationery == s;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () => setSheetState(() => selectedStationery = s),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? Colors.amber.withValues(alpha: 0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSel ? Colors.amber : Colors.white24),
                                ),
                                child: Center(
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel ? Colors.amber : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Choose Wax Stamp Color
                    const Text('Wax Seal Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        {'name': 'Crimson', 'color': const Color(0xFFB71C1C)},
                        {'name': 'Imperial Gold', 'color': const Color(0xFFD4AF37)},
                        {'name': 'Rose Gold', 'color': const Color(0xFFB76E79)},
                      ].map((w) {
                        final name = w['name'] as String;
                        final color = w['color'] as Color;
                        final isSel = selectedWax == name;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () => setSheetState(() => selectedWax = name),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isSel ? 0.35 : 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSel ? color : Colors.white24, width: isSel ? 2 : 1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                        color: isSel ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Quick replies
                    const Text('Romantic Whisper Templates:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickReplies.map((r) => ActionChip(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        label: Text(r, style: const TextStyle(fontSize: 11, color: Colors.pinkAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          replyController.text = r;
                          setSheetState(() {});
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: replyController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Pour your unfiltered thoughts into this letter...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Interactive Hold to Melt & Stamp Ritual
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTapDown: (_) {
                              HapticFeedback.mediumImpact();
                              stampProgress = 0.0;
                              stampTimer?.cancel();
                              stampTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
                                setSheetState(() {
                                  stampProgress += 0.05;
                                  if (stampProgress >= 1.0) {
                                    stampProgress = 1.0;
                                    t.cancel();
                                    HapticFeedback.heavyImpact();
                                  }
                                });
                              });
                            },
                            onTapUp: (_) {
                              stampTimer?.cancel();
                              if (stampProgress < 1.0) {
                                setSheetState(() {
                                  stampProgress = 0.0;
                                });
                              }
                            },
                            onTapCancel: () {
                              stampTimer?.cancel();
                              setSheetState(() {
                                stampProgress = 0.0;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: waxColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: waxColor.withValues(alpha: stampProgress > 0 ? 0.8 : 0.4),
                                    blurRadius: stampProgress > 0 ? 18 : 8,
                                    spreadRadius: stampProgress * 4,
                                  ),
                                ],
                                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (stampProgress > 0 && stampProgress < 1.0)
                                    CircularProgressIndicator(
                                      value: stampProgress,
                                      strokeWidth: 3,
                                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  Icon(
                                    stampProgress >= 1.0 ? Icons.check : Icons.touch_app,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stampProgress >= 1.0
                                ? '✨ Wax Seal Melted & Stamped!'
                                : 'Press & Hold Stamp to Melt Wax Seal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: stampProgress >= 1.0 ? Colors.amberAccent : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: (replyController.text.trim().isEmpty || stampProgress < 0.95)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              _dispatchWaxReply(
                                recipientName: selectedRecipient,
                                stationery: selectedStationery,
                                waxColor: selectedWax,
                                userReply: replyController.text.trim(),
                              );
                            },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Dispatch Sealed Letter to Character 🕊️'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: waxColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _dispatchWaxReply({
    required String recipientName,
    required String stationery,
    required String waxColor,
    required String userReply,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(width: 18),
            Expanded(child: Text('Courier delivering your wax-sealed letter...')),
          ],
        ),
      ),
    );

    try {
      final res = await ApiService.sendWaxSealedReply(
        widget.storyId,
        recipientName: recipientName,
        stationery: stationery,
        waxColor: waxColor,
        userReply: userReply,
      );

      if (mounted) {
        Navigator.pop(context); // close loader
        final reaction = (res['reaction'] as Map<String, dynamic>?) ?? {};
        setState(() {
          lastWaxReplyReaction = reaction;
        });

        _showWaxReplyReactionDialog(reaction, recipientName);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deliver reply: $e')));
      }
    }
  }

  void _showWaxReplyReactionDialog(Map<String, dynamic> reaction, String characterName) {
    final immediateReaction = reaction['character_immediate_reaction'] ?? 'Stunned into breathless silence.';
    final speech = reaction['dialogue_response'] ?? '';
    final emotion = reaction['emotional_shift'] ?? 'Vulnerable';
    final token = reaction['physical_keepsake_reaction'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E101E),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$characterName Received Your Letter!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '💓 Emotional Shift: $emotion',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Immediate Reaction:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                immediateReaction,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white),
              ),
              if (speech.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '"$speech"',
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.amberAccent, height: 1.4),
                  ),
                ),
              ],
              if (token.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '🕊️ $token',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white60),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
            child: const Text('Keep in Keepsake Tray'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BATCH 4 FEATURE: 🪢 THE RED THREAD OF FATE
  // ==========================================

  Future<void> _fetchRedThread() async {
    setState(() => isLoadingRedThread = true);
    try {
      final res = await ApiService.getRedThreadCrossings(widget.storyId);
      if (mounted) {
        setState(() {
          storyRedThread = res;
          isLoadingRedThread = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingRedThread = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to trace red thread: $e')));
      }
    }
  }

  Widget _buildRedThreadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A0E17), Color(0xFF1E0A12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🪢', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Red Thread of Fate',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Uncover secret past near-miss encounters where the leads brushed shoulders years before Chapter 1 without ever speaking.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isLoadingRedThread ? null : _fetchRedThread,
                  icon: isLoadingRedThread
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.grain, size: 16),
                  label: Text(storyRedThread == null ? 'Trace Thread' : 'Re-trace', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoadingRedThread) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 12),
                    Text('Tracing fateful knots across past timelines...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (storyRedThread == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.gesture, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('The Red Thread has not yet been traced for this story.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchRedThread,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Trace Past Encounters'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text('Fateful Crossroads & Near-Misses (${storyRedThread!.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...List.generate(storyRedThread!.length, (index) {
              final crossing = storyRedThread![index] as Map<String, dynamic>;
              final timeframe = crossing['timeframe'] ?? 'Past Encounter';
              final title = crossing['encounter_title'] ?? 'The Silent Crossing';
              final location = crossing['location'] ?? 'Unknown City';
              final prose = crossing['near_miss_prose'] ?? '';
              final item = crossing['linking_item_or_token'] ?? '';
              final irony = crossing['poetic_irony'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline thread line with glowing node
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 8),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        if (index < storyRedThread!.length - 1)
                          Container(
                            width: 2,
                            height: 120,
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Encounter Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B0E14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    timeframe,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 $location',
                              style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              prose,
                              style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white70),
                            ),
                            if (item.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🔗 Shared Token: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(fontSize: 11, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (irony.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '✨ "$irony"',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white54),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildUnsentLettersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade900.withValues(alpha: 0.4), Colors.purple.shade900.withValues(alpha: 0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('💌', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unsent Letters & Burn Notes',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Secret letters written at 3:00 AM full of unfiltered longing, self-censorship, and crossed-out fears.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoadingUnsentLetters ? null : _fetchUnsentLetters,
                      icon: isLoadingUnsentLetters
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.mail_outline, size: 16),
                      label: Text(storyUnsentLetters == null ? 'Open Tray' : 'Scan', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => _showWaxSealReplyDialog(),
                      icon: const Icon(Icons.history_edu, size: 14, color: Colors.amberAccent),
                      label: const Text('Reply 💌', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amberAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoadingUnsentLetters) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 12),
                    Text('Unsealing character drawers and nightstands...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (storyUnsentLetters == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.mark_email_unread_outlined, size: 64, color: Colors.redAccent.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Letter tray has not been opened yet.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('Tap "Open Tray" to discover the secret confessions and unsent notes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ] else if (storyUnsentLetters!.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No unsent letters found yet. Write more chapters to uncover secret letters!', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ] else ...[
            Text('Discovered Letters (${storyUnsentLetters!.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: storyUnsentLetters!.length,
              itemBuilder: (ctx, i) {
                final letter = storyUnsentLetters![i] as Map<String, dynamic>;
                final letterId = letter['id']?.toString() ?? 'letter-$i';
                final isSealBroken = _brokenWaxSeals.contains(letterId);
                final author = letter['author_name'] ?? 'Author';
                final recipient = letter['recipient_name'] ?? 'Recipient';
                final title = letter['letter_title'] ?? 'Secret Note';
                final timeContext = letter['time_context'] ?? 'Midnight';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isSealBroken ? Colors.redAccent.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _showLetterDialog(letter);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSealBroken ? Colors.grey.shade800 : Colors.red.shade800,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSealBroken ? Colors.transparent : Colors.red.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    isSealBroken ? '✉️' : '🏮',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$author ➔ $recipient',
                                      style: const TextStyle(fontSize: 12, color: Colors.pinkAccent),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSealBroken ? Colors.white10 : Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isSealBroken ? 'Seal Broken' : 'Wax Sealed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSealBroken ? Colors.white60 : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  timeContext,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  _showLetterDialog(letter);
                                },
                                icon: Icon(isSealBroken ? Icons.mark_email_read : Icons.lock_open, size: 14, color: Colors.redAccent),
                                label: Text(isSealBroken ? 'Read Note' : 'Break Wax Seal & Read', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FEATURE 4: CANDID POLAROID ALBUM
  // ==========================================

  Future<void> _fetchPolaroids() async {
    setState(() => isLoadingPolaroids = true);
    try {
      final res = await ApiService.getPolaroids(widget.storyId);
      if (mounted) {
        setState(() {
          storyPolaroids = res;
          isLoadingPolaroids = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingPolaroids = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load polaroids: $e')));
      }
    }
  }

  void _showPolaroidDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1424),
        title: Row(
          children: [
            const Icon(Icons.photo_camera, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item['title']?.toString() ?? 'Candid Snapshot',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.location_on, size: 14, color: Colors.cyanAccent),
                    label: Text(item['location']?.toString() ?? 'Unknown Location', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                  Chip(
                    avatar: const Icon(Icons.calendar_today, size: 14, color: Colors.amber),
                    label: Text(item['date_caption']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white10,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Polaroid Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade900, Colors.indigo.shade900, Colors.pink.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.white70, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            item['visual_prompt']?.toString() ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item['date_caption']?.toString() ?? '',
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Why This Memory Matters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item['memory_reflection']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back to Album', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildPolaroidsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.shade900.withValues(alpha: 0.4), Colors.indigo.shade900.withValues(alpha: 0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📸', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Candid Polaroid Album',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Spontaneous snapshots, quiet morning coffee moments, and rainy passenger seat memories.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isLoadingPolaroids ? null : _fetchPolaroids,
                  icon: isLoadingPolaroids
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.photo_library, size: 16),
                  label: Text(storyPolaroids == null ? 'Develop' : 'Refresh', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoadingPolaroids) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 12),
                    Text('Developing vintage candid polaroids in darkroom...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (storyPolaroids == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: Colors.cyan.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Polaroid album is empty.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('Tap "Develop" to generate candid snapshots of intimate moments between the leads.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ] else if (storyPolaroids!.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No polaroids captured yet. Progress the story to develop new memories!', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ] else ...[
            Text('Developed Memories (${storyPolaroids!.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.76,
              ),
              itemCount: storyPolaroids!.length,
              itemBuilder: (ctx, i) {
                final item = storyPolaroids![i] as Map<String, dynamic>;
                final title = item['title']?.toString() ?? 'Memory';
                final dateCaption = item['date_caption']?.toString() ?? '';
                final location = item['location']?.toString() ?? '';
                final rotDeg = ((item['rotation_deg'] ?? ((i % 3) - 1)) as num).toDouble();

                return Transform.rotate(
                  angle: rotDeg * 0.02,
                  child: GestureDetector(
                    onTap: () => _showPolaroidDialog(item),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade900,
                                    Colors.indigo.shade900,
                                    Colors.pink.shade900,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.white70, size: 24),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (location.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '📍 $location',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateCaption.isNotEmpty ? dateCaption : title,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FEATURE 4: 🕯️ SENSORY OLFACTORY & AESTHETIC PROFILE
  // ==========================================

  Widget _buildSensoryProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900.withValues(alpha: 0.4), Colors.amber.shade900.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Text('🕯️', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sensory Olfactory & Aesthetic Profile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fragrance pyramid, signature wardrobe textures & atmospheric palette.',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLoadingSensoryProfile ? null : () async {
                    setState(() => isLoadingSensoryProfile = true);
                    try {
                      final p = await ApiService.getSensoryProfile(widget.storyId);
                      setState(() {
                        sensoryProfile = p;
                        isLoadingSensoryProfile = false;
                      });
                    } catch (e) {
                      setState(() => isLoadingSensoryProfile = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: isLoadingSensoryProfile
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.auto_awesome, size: 14),
                  label: Text(isLoadingSensoryProfile ? 'Analyzing...' : (sensoryProfile == null ? 'Generate' : 'Refresh'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (sensoryProfile == null && !isLoadingSensoryProfile)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.spa_outlined, size: 48, color: Colors.amber.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No sensory profile generated yet.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    const Text('Tap "Generate" to distill the scent pyramid, wardrobe textures, and color mood of your novel leads.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (sensoryProfile != null) ...[
            // Fragrance & Scent Story
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🧴 Signature Fragrance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text(sensoryProfile!['fragrance_name'] ?? 'Nocturne', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amberAccent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (sensoryProfile!['perfume_pyramid'] is Map) ...[
                    // Top Notes
                    _buildNoteRow('Top Notes (First Impression)', (sensoryProfile!['perfume_pyramid']['top_notes'] as List?) ?? [], Colors.cyanAccent),
                    const SizedBox(height: 8),
                    // Heart Notes
                    _buildNoteRow('Heart Notes (Core Emotion)', (sensoryProfile!['perfume_pyramid']['heart_notes'] as List?) ?? [], Colors.pinkAccent),
                    const SizedBox(height: 8),
                    // Base Notes
                    _buildNoteRow('Base Notes (Lingering Intimacy)', (sensoryProfile!['perfume_pyramid']['base_notes'] as List?) ?? [], Colors.amberAccent),
                    const SizedBox(height: 12),
                    if (sensoryProfile!['perfume_pyramid']['scent_story'] != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '“${sensoryProfile!['perfume_pyramid']['scent_story']}”',
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, height: 1.4, color: Colors.white),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Signature Wardrobe & Textures
            if (sensoryProfile!['signature_wardrobe'] is List) ...[
              const Text('👔 Signature Wardrobe & Physical Textures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 8),
              ...((sensoryProfile!['signature_wardrobe'] as List).map((w) {
                final item = w as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.checkroom, color: Colors.pinkAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['item'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(item['texture'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              })),
              const SizedBox(height: 16),
            ],

            // Atmospheric Color Palette
            if (sensoryProfile!['atmospheric_palette'] is List) ...[
              const Text('🎨 Atmospheric Aesthetic Palette', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (sensoryProfile!['atmospheric_palette'] as List).map((c) {
                    final colorItem = c as Map<String, dynamic>;
                    final hexStr = colorItem['hex']?.toString().replaceAll('#', '') ?? '1E293B';
                    final colorVal = Color(int.tryParse('0xFF$hexStr') ?? 0xFF1E293B);
                    return Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorVal,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(colorItem['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                          Text(colorItem['mood'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white70)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tactile Sensations
            if (sensoryProfile!['tactile_sensations'] is List) ...[
              const Text('⚡ Tactile Sensations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 8),
              ...((sensoryProfile!['tactile_sensations'] as List).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.amberAccent, fontSize: 14)),
                    Expanded(child: Text(t.toString(), style: const TextStyle(fontSize: 12, color: Colors.white70))),
                  ],
                ),
              ))),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNoteRow(String title, List<dynamic> notes, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: notes.map((n) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(n.toString(), style: TextStyle(fontSize: 11, color: color)),
          )).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // FEATURE 5: ⏰ SCHEDULED REAL-TIME LETTERS & MIDNIGHT NOTES
  // ==========================================

  Widget _buildScheduledLettersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade900.withValues(alpha: 0.4), Colors.pink.shade900.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Text('💌', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled Midnight Letters',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.pinkAccent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Authentic time-stamped messages & audio whispers from your leads.',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isLoadingScheduledLetters ? null : () async {
                    setState(() => isLoadingScheduledLetters = true);
                    try {
                      final l = await ApiService.getScheduledLetters(widget.storyId);
                      setState(() {
                        scheduledLetters = l;
                        isLoadingScheduledLetters = false;
                      });
                    } catch (e) {
                      setState(() => isLoadingScheduledLetters = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: isLoadingScheduledLetters
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.schedule, size: 14),
                  label: Text(isLoadingScheduledLetters ? 'Fetching...' : (scheduledLetters == null ? 'Retrieve' : 'Refresh'), style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (scheduledLetters == null && !isLoadingScheduledLetters)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.mark_email_unread_outlined, size: 48, color: Colors.pink.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No midnight letters received yet.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    const Text('Tap "Retrieve" to sync private letters written by characters at late-night hours.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (scheduledLetters != null) ...[
            ...scheduledLetters!.map((item) {
              final letter = item as Map<String, dynamic>;
              final timeStr = letter['timestamp_display'] ?? '11:45 PM';
              final charName = letter['character_name'] ?? 'Lead';
              final locStr = letter['location_context'] ?? '';
              final bodyText = letter['message_text'] ?? '';
              final whisperText = letter['audio_whisper_text'] ?? bodyText;
              final vuln = letter['vulnerability_score'] ?? 90;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1626),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('⏰ $timeStr', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Text(charName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        const Spacer(),
                        Text('💔 $vuln% Vulnerability', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                      ],
                    ),
                    if (locStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('📍 $locStr', style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                    const Divider(height: 20, color: Colors.white12),
                    Text(
                      bodyText,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final tts = FlutterTts();
                            await tts.setSpeechRate(0.38);
                            await tts.setPitch(0.92);
                            await tts.speak(whisperText);
                          },
                          icon: const Icon(Icons.volume_up, size: 16),
                          label: const Text('Listen to Whisper', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}




