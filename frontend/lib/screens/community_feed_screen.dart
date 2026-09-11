import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  List<dynamic> _publicStories = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() => _isLoading = true);
    try {
      final feed = await ApiService.getCommunityFeed();
      if (mounted) {
        setState(() {
          _publicStories = feed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading feed: $e')));
      }
    }
  }

  void _likeStory(String storyId, int index) async {
    try {
      final res = await ApiService.likeStory(storyId);
      if (mounted) {
        setState(() {
          _publicStories[index]['likes_count'] = res['likes_count'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _forkStory(String storyId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloning public story...')));
      final newStory = await ApiService.branchStory(storyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story cloned to your library!')));
        context.push('/story/${newStory['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cloning story: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _publicStories.where((s) {
      final title = (s['title'] ?? '').toString().toLowerCase();
      final genre = (s['genre'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || genre.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.public, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Community Story Hub'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFeed,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search community stories & genres...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                ? const Center(child: Text('No community stories published yet.', style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final story = filtered[idx];
                      final cover = story['cover_base64'];
                      final likes = story['likes_count'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cover != null && cover.toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(cover),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          story['title'] ?? 'Untitled',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(story['genre'] ?? 'Fiction', style: const TextStyle(fontSize: 12)),
                                        backgroundColor: Colors.purple.withValues(alpha: 0.2),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    story['synopsis'] ?? 'No synopsis provided.',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.favorite, color: Colors.redAccent),
                                            onPressed: () => _likeStory(story['id'], idx),
                                          ),
                                          Text('$likes Likes', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _forkStory(story['id']),
                                            icon: const Icon(Icons.alt_route, size: 18),
                                            label: const Text('Fork / Clone'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => context.push('/story/${story['id']}'),
                                            icon: const Icon(Icons.menu_book, size: 18),
                                            label: const Text('Read'),
                                          ),
                                        ],
                                      ),
                                    ],
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
    );
  }
}
