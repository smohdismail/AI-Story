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
  bool isOwner = false;
  String? errorMessage;

  bool isFolderView = false;
  String? selectedGenre;
  String? selectedSubgenre;
  Map<String, dynamic>? streakInfo;
  String _privacyFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await StreakService.getStreakInfo();
    try {
      final prof = await ApiService.getMyProfile();
      if (mounted) {
        setState(() {
          isOwner = prof['is_owner'] == true;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        streakInfo = info;
      });
    }
    _loadStories();
  }

  Future<void> _loadStories() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }
    try {
      final data = await ApiService.getStories();
      if (mounted) {
        setState(() {
          stories = data;
          isLoading = false;
          errorMessage = null;
        });
      }
    } on UnauthenticatedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.go('/auth');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
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
        actions: [
          if (isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
              child: Tooltip(
                message: '👑 Owner Master Mode: Full Access to ALL Stories (Public & Private)',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.amber, Colors.deepOrange]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.amberAccent, blurRadius: 4, spreadRadius: 0.5),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.black, size: 14),
                      SizedBox(width: 4),
                      Text('OWNER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(isFolderView ? Icons.grid_view : Icons.folder_copy, color: Colors.amberAccent),
            tooltip: isFolderView ? 'Switch to All Stories Grid' : 'Switch to Genre Folders View',
            onPressed: () {
              setState(() {
                isFolderView = !isFolderView;
                selectedGenre = null;
                selectedSubgenre = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.public, color: Colors.cyanAccent),
            tooltip: 'Community Feed',
            onPressed: () {
              context.push('/community');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Persona',
            onPressed: () {
              context.push('/persona');
            },
          ),
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
      body: RefreshIndicator(
        onRefresh: _loadStories,
        child: Column(
          children: [
            if (streakInfo != null) _buildStreakBanner(),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null && stories.isEmpty
                  ? _buildErrorView()
                  : stories.isEmpty 
                    ? const Center(child: Text("No stories yet. Click + to create one."))
                    : _buildBodyContent(),
            ),
          ],
        ),
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

  Widget _buildContinueReadingCard(Map<String, dynamic> story) {
    final title = story['title'] ?? 'Untitled Novel';
    final genre = story['genre'] ?? 'Romance';
    final subgenre = story['subgenre'] ?? 'Fiction';
    final coverBase64 = story['cover_base64'];
    final coverUrl = story['cover_image_url'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E1A47),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/story/${story['id']}');
            _loadStories();
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Cover preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 58,
                    height: 80,
                    color: Colors.black38,
                    child: coverBase64 != null
                        ? Image.memory(
                            base64Decode(coverBase64),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Colors.amber),
                          )
                        : (coverUrl != null && coverUrl.isNotEmpty)
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Colors.amber),
                              )
                            : const Icon(Icons.book, color: Colors.amber, size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                // Story Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_circle_fill, size: 14, color: Colors.amber),
                          const SizedBox(width: 5),
                          Text(
                            'CONTINUE READING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.amber.shade300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$genre • $subgenre',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Resume Chapter ➔',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (!isFolderView) {
      final latestStory = stories.isNotEmpty ? stories.first : null;
      final filteredStories = stories.where((s) {
        if (_privacyFilter == 'private') return s['is_published'] != true;
        if (_privacyFilter == 'public') return s['is_published'] == true;
        return true;
      }).toList();

      final privateCount = stories.where((s) => s['is_published'] != true).length;
      final publicCount = stories.where((s) => s['is_published'] == true).length;

      return Column(
        children: [
          if (latestStory != null) _buildContinueReadingCard(latestStory),
          // Privacy Filter Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All (${stories.length})', style: const TextStyle(fontSize: 12)),
                  selected: _privacyFilter == 'all',
                  onSelected: (_) => setState(() => _privacyFilter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.public, size: 14, color: Colors.cyanAccent),
                  label: Text('Public ($publicCount)', style: const TextStyle(fontSize: 12)),
                  selected: _privacyFilter == 'public',
                  selectedColor: Colors.cyan.shade900,
                  onSelected: (_) => setState(() => _privacyFilter = 'public'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.lock, size: 14, color: Colors.deepOrangeAccent),
                  label: Text('Private ($privateCount)', style: const TextStyle(fontSize: 12)),
                  selected: _privacyFilter == 'private',
                  selectedColor: Colors.deepOrange.shade900,
                  onSelected: (_) => setState(() => _privacyFilter = 'private'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildStoriesGrid(filteredStories)),
        ],
      );
    }

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
      return _buildStoriesGrid(subgenreStories);
    }
  }

  Widget _buildStoriesGrid(List<dynamic> targetStories) {
    if (targetStories.isEmpty) {
      return const Center(child: Text("No stories found in this section."));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: targetStories.length,
      itemBuilder: (context, index) {
        final story = targetStories[index];
        final isPublic = story['is_published'] == true;
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: story['cover_base64'] != null
                          ? Image.memory(
                              base64Decode(story['cover_base64']),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.deepPurple.shade800,
                              child: const Icon(Icons.book, size: 64, color: Colors.white54),
                            ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPublic ? Colors.cyanAccent : Colors.deepOrangeAccent,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPublic ? Icons.public : Icons.lock,
                                size: 10,
                                color: isPublic ? Colors.cyanAccent : Colors.deepOrangeAccent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isPublic ? 'Public' : 'Private',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isPublic ? Colors.cyanAccent : Colors.deepOrangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          story['title'] ?? 'Untitled',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete Story',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteStory(story),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    story['synopsis'] ?? 'No summary available.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (story['genre'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0, top: 2.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${story['genre']}${story['subgenre'] != null ? ' • ${story['subgenre']}' : ''}',
                        style: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteStory(Map<String, dynamic> story) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story Book'),
        content: Text('Are you sure you want to delete "${story['title']}"? All chapters and characters in this story will be permanently removed.'),
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
        await ApiService.deleteStory(story['id']);
        _loadStories();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting story: $e')));
      }
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

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Stories',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unable to connect to backend server.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _loadStories();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.login),
                  label: const Text('Re-login'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await context.push('/settings');
                _loadStories();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Check Server Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
