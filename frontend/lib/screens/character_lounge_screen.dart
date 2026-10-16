import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class CharacterLoungeScreen extends StatefulWidget {
  const CharacterLoungeScreen({super.key});

  @override
  State<CharacterLoungeScreen> createState() => _CharacterLoungeScreenState();
}

class _CharacterLoungeScreenState extends State<CharacterLoungeScreen> {
  List<dynamic> _characters = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedStoryFilter;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);
    try {
      final chars = await ApiService.getAllUserCharacters();
      if (mounted) {
        setState(() {
          _characters = chars;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> get _storyTitles {
    final titles = <String>{};
    for (var c in _characters) {
      final t = c['story_title']?.toString();
      if (t != null && t.isNotEmpty) titles.add(t);
    }
    return titles.toList();
  }

  List<dynamic> get _filteredCharacters {
    return _characters.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final role = (c['role'] ?? '').toString().toLowerCase();
      final story = (c['story_title'] ?? '').toString();
      final matchesSearch = _searchQuery.isEmpty || 
          name.contains(_searchQuery.toLowerCase()) || 
          role.contains(_searchQuery.toLowerCase());
      final matchesStory = _selectedStoryFilter == null || story == _selectedStoryFilter;
      return matchesSearch && matchesStory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.forum, color: Colors.pinkAccent),
            SizedBox(width: 8),
            Text('Character Lounge', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Characters',
            onPressed: _loadCharacters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search characters by name or role...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_storyTitles.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _selectedStoryFilter,
                    hint: const Text('All Stories', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Stories', style: TextStyle(fontSize: 12))),
                      ..._storyTitles.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedStoryFilter = v),
                  ),
                ],
              ],
            ),
          ),
          // Character List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                : _filteredCharacters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No characters found yet.',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create stories and characters to start chatting with them!',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredCharacters.length,
                        itemBuilder: (ctx, i) {
                          final char = _filteredCharacters[i];
                          return _buildCharacterCard(char);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> char) {
    final name = char['name'] ?? 'Character';
    final role = char['role'] ?? 'Lead';
    final storyTitle = char['story_title'] ?? 'Novel';
    final avatar = char['avatar_url'];
    final passion = (char['passion_level'] ?? 50) as int;
    final vulnerability = (char['vulnerability_level'] ?? 30) as int;
    final status = char['romantic_status'] ?? 'Guarded';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.pink.shade900,
                  child: ClipOval(
                    child: _buildAvatarImage(avatar, name),
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.menu_book, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              storyTitle,
                              style: const TextStyle(fontSize: 11, color: Colors.amber),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chemistry Bars
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🔥 Passion', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                          const Spacer(),
                          Text('$passion%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: passion / 100.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🥀 Vulnerability', style: TextStyle(fontSize: 11, color: Colors.pinkAccent)),
                          const Spacer(),
                          Text('$vulnerability%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: vulnerability / 100.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/character_chat', extra: {
                        'characterId': char['id'],
                        'characterName': name,
                        'backgroundImage': avatar,
                      });
                    },
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('1-on-1 Chat', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Requesting selfie from $name...')));
                      await ApiService.requestSelfie(char['id']);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie generated! Open chat to view.')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selfie error: $e')));
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 16, color: Colors.amber),
                  label: const Text('Selfie 📸', style: TextStyle(fontSize: 12, color: Colors.amber)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(dynamic avatar, String name) {
    if (avatar != null && avatar.toString().isNotEmpty) {
      final str = avatar.toString();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return Image.network(
          str,
          fit: BoxFit.cover,
          width: 52,
          height: 52,
          errorBuilder: (_, __, ___) => _fallbackAvatarText(name),
        );
      }
      try {
        final bytes = base64Decode(str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 52,
          height: 52,
          errorBuilder: (_, __, ___) => _fallbackAvatarText(name),
        );
      } catch (_) {}
    }
    return _fallbackAvatarText(name);
  }

  Widget _fallbackAvatarText(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
