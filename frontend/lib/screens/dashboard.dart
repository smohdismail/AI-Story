import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';
import 'dart:convert';
import '../streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> stories = [];
  bool isLoading = true;

  String? selectedGenre;
  String? selectedSubgenre;
  Map<String, dynamic>? streakInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await StreakService.getStreakInfo();
    setState(() {
      streakInfo = info;
    });
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiService.getStories();
      setState(() {
        stories = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading stories: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    String title = 'My Stories Library';
    if (selectedSubgenre != null) {
      title = selectedSubgenre!;
    } else if (selectedGenre != null) {
      title = selectedGenre!;
    }

    return Scaffold(
      appBar: AppBar(
        leading: (selectedGenre != null || selectedSubgenre != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    if (selectedSubgenre != null) {
                      selectedSubgenre = null;
                    } else if (selectedGenre != null) {
                      selectedGenre = null;
                    }
                  });
                },
              )
            : null,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/create');
              _loadStories();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (streakInfo != null) _buildStreakBanner(),
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : stories.isEmpty 
                ? const Center(child: Text("No stories yet. Click + to create one."))
                : _buildBodyContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create');
          _loadStories();
        },
        label: const Text('New Story'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStreakBanner() {
    int streak = streakInfo!['streak'];
    int words = streakInfo!['dailyWords'];
    int goal = streakInfo!['dailyGoal'];
    double progress = (words / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: streak > 0 ? Colors.orange : Colors.grey, size: 28),
                  const SizedBox(width: 8),
                  Text('$streak Day Streak', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text('$words / $goal words', style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white30,
            color: progress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (selectedGenre == null) {
      // Level 1: Genres
      final genres = stories.map((s) => s['genre'] as String? ?? 'Unknown').toSet().toList();
      genres.sort();
      return _buildGrid(
        items: genres,
        icon: Icons.folder,
        onTap: (item) => setState(() => selectedGenre = item),
      );
    } else if (selectedSubgenre == null) {
      // Level 2: Subgenres within Genre
      final genreStories = stories.where((s) => s['genre'] == selectedGenre).toList();
      final subgenres = genreStories.map((s) => s['subgenre'] as String? ?? 'Unknown').toSet().toList();
      subgenres.sort();
      return _buildGrid(
        items: subgenres,
        icon: Icons.folder_open,
        onTap: (item) => setState(() => selectedSubgenre = item),
      );
    } else {
      // Level 3: Stories within Subgenre
      final subgenreStories = stories.where((s) => s['genre'] == selectedGenre && s['subgenre'] == selectedSubgenre).toList();
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: subgenreStories.length,
        itemBuilder: (context, index) {
          final story = subgenreStories[index];
          return Card(
            elevation: 4,
            child: InkWell(
              onTap: () async {
                await context.push('/story/${story['id']}');
                _loadStories();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: story['cover_base64'] != null
                      ? Image.memory(
                          base64Decode(story['cover_base64']),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(
                          color: Colors.deepPurple.shade800,
                          child: const Icon(Icons.book, size: 64, color: Colors.white54),
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      story['title'] ?? 'Untitled',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      story['synopsis'] ?? 'No summary available.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildGrid({required List<String> items, required IconData icon, required Function(String) onTap}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: InkWell(
            onTap: () => onTap(items[index]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  items[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
