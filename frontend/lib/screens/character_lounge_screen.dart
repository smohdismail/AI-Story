import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
            // Action Buttons Row 1: Chat & Selfie
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
            const SizedBox(height: 8),
            // Action Buttons Row 2: Date Night & Midnight Voicemail
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDateEncounterDialog(char),
                    icon: const Icon(Icons.nightlife, size: 16),
                    label: const Text('☕ Date Night', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMidnightVoicemailDialog(char),
                    icon: const Icon(Icons.mic, size: 16, color: Colors.pinkAccent),
                    label: const Text('🎙️ Voicemail', style: TextStyle(fontSize: 12, color: Colors.pinkAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.pinkAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDateEncounterDialog(Map<String, dynamic> char) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DateEncounterDialog(char: char),
    );
  }

  void _showMidnightVoicemailDialog(Map<String, dynamic> char) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MidnightVoicemailDialog(char: char),
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

// ==========================================
// FEATURE 2: DATE NIGHT & SECRET ENCOUNTERS
// ==========================================

class _DateEncounterDialog extends StatefulWidget {
  final Map<String, dynamic> char;
  const _DateEncounterDialog({required this.char});

  @override
  State<_DateEncounterDialog> createState() => _DateEncounterDialogState();
}

class _DateEncounterDialogState extends State<_DateEncounterDialog> {
  final TextEditingController _actionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedSetting = 'Midnight Rooftop with Wine & Starlight';
  bool _isLoading = false;
  final List<Map<String, dynamic>> _steps = [];

  final List<String> _settings = [
    'Midnight Rooftop with Wine & Starlight',
    'Rain-Drenched Hotel Suite after a Gala',
    'Motorcycle Ride to a Secluded Cliffside',
    'Slow Dance in an Empty Apartment',
    'Candlelit Underground Speakeasy Booth',
    'Secluded Beach House with Crashing Waves',
  ];

  final List<String> _suggestions = [
    'Take their hand and whisper...',
    'Step closer until you feel their breath...',
    'Pour two glasses and watch them quietly...',
    'Reach out to touch their hair...',
  ];

  @override
  void initState() {
    super.initState();
    _startInitialEncounter();
  }

  void _startInitialEncounter() {
    _sendEncounterStep('We arrive at the $_selectedSetting together in silence.');
  }

  Future<void> _sendEncounterStep(String actionText) async {
    if (actionText.trim().isEmpty) return;
    final charId = widget.char['id']?.toString() ?? '';
    setState(() {
      _steps.add({
        'type': 'user',
        'content': actionText.trim(),
      });
      _isLoading = true;
    });
    _actionController.clear();
    _scrollToBottom();

    try {
      final res = await ApiService.dateEncounterStep(
        charId,
        setting: _selectedSetting,
        userAction: actionText,
        history: _steps,
      );
      if (mounted) {
        setState(() {
          _steps.add({
            'type': 'scene',
            'prose': res['prose_narrative'] ?? '',
            'dialogue': res['character_dialogue'] ?? '',
            'reaction': res['character_reaction'] ?? '',
            'heat': res['intimacy_heat_score'] ?? 5,
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encounter error: $e')));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final charName = widget.char['name'] ?? 'Character';
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF140E1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.nightlife, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Night with $charName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text(_selectedSetting, style: const TextStyle(fontSize: 11, color: Colors.amber), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.location_on, color: Colors.amber),
                  tooltip: 'Change Date Setting',
                  onSelected: (val) {
                    setState(() {
                      _selectedSetting = val;
                      _steps.clear();
                    });
                    _startInitialEncounter();
                  },
                  itemBuilder: (ctx) => _settings.map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Suggestion Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => ActionChip(
                backgroundColor: Colors.purple.shade900.withValues(alpha: 0.4),
                label: Text(_suggestions[i], style: const TextStyle(fontSize: 11, color: Colors.pinkAccent)),
                onPressed: _isLoading ? null : () => _sendEncounterStep(_suggestions[i]),
              ),
            ),
          ),
          const Divider(height: 1),

          // Encounter Chat / Prose Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (ctx, i) {
                final step = _steps[i];
                if (step['type'] == 'user') {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12, left: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        step['content'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((step['prose'] ?? '').toString().isNotEmpty) ...[
                          Text(
                            step['prose'] ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if ((step['dialogue'] ?? '').toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$charName: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent, fontSize: 13)),
                                Expanded(
                                  child: Text(
                                    '“${step['dialogue']}”',
                                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if ((step['reaction'] ?? '').toString().isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.favorite, size: 12, color: Colors.orangeAccent),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  step['reaction'] ?? '',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orangeAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }
              },
            ),
          ),

          if (_isLoading) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent)),
                  const SizedBox(width: 8),
                  Text('$charName is responding to the moment...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],

          // Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _actionController,
                    decoration: InputDecoration(
                      hintText: 'Describe an intimate action or whispered dialogue...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (v) => _sendEncounterStep(v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.pinkAccent),
                  onPressed: _isLoading ? null : () => _sendEncounterStep(_actionController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// FEATURE 6: MIDNIGHT VOICEMAILS & WHISPERS
// ==========================================

class _MidnightVoicemailDialog extends StatefulWidget {
  final Map<String, dynamic> char;
  const _MidnightVoicemailDialog({required this.char});

  @override
  State<_MidnightVoicemailDialog> createState() => _MidnightVoicemailDialogState();
}

class _MidnightVoicemailDialogState extends State<_MidnightVoicemailDialog> {
  final FlutterTts _tts = FlutterTts();
  String _selectedMood = '🌙 2:14 AM - Can\'t sleep thinking about you';
  bool _isLoading = false;
  bool _isPlaying = false;
  Map<String, dynamic>? _voicemail;

  final List<String> _moods = [
    '🌙 2:14 AM - Can\'t sleep thinking about you',
    '🥀 11:45 PM - Hotel room confession',
    '⚡ 3:30 AM - Late-night longing after the argument',
    '🌧️ 1:15 AM - Missing your touch in the dark',
  ];

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _fetchVoicemail();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _fetchVoicemail() async {
    final charId = widget.char['id']?.toString() ?? '';
    setState(() {
      _isLoading = true;
      _isPlaying = false;
    });
    await _tts.stop();

    try {
      final res = await ApiService.generateMidnightVoicemail(charId, mood: _selectedMood);
      if (mounted) {
        setState(() {
          _voicemail = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voicemail error: $e')));
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
    } else {
      final text = _voicemail?['whisper_script']?.toString();
      if (text != null && text.isNotEmpty) {
        await _tts.setSpeechRate(0.38);
        await _tts.setPitch(0.95);
        setState(() => _isPlaying = true);
        await _tts.speak(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final charName = widget.char['name'] ?? 'Character';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF160F22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.mic, color: Colors.pinkAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Midnight Voicemail from $charName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mood Dropdown
          DropdownButtonFormField<String>(
            value: _selectedMood,
            dropdownColor: const Color(0xFF221634),
            decoration: InputDecoration(
              labelText: 'Voicemail Call Scenario',
              labelStyle: const TextStyle(color: Colors.amber, fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _moods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12, color: Colors.white)))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedMood = val);
                _fetchVoicemail();
              }
            },
          ),
          const SizedBox(height: 16),

          if (_isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.pinkAccent),
                    SizedBox(height: 12),
                    Text('Connecting midnight call & recording whisper...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ] else if (_voicemail != null) ...[
            // Voicemail Audio Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade900.withValues(alpha: 0.35), Colors.purple.shade900.withValues(alpha: 0.35)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isPlaying ? Colors.redAccent.withValues(alpha: 0.3) : Colors.pink.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.graphic_eq : Icons.voicemail,
                          color: _isPlaying ? Colors.redAccent : Colors.pinkAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _voicemail!['timestamp']?.toString() ?? 'Late Night',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                            Text(
                              'Tone: ${_voicemail!['emotional_state'] ?? 'Intimate whisper'}',
                              style: const TextStyle(fontSize: 11, color: Colors.pinkAccent),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _toggleAudio,
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
                        label: Text(_isPlaying ? 'Stop' : 'Listen', style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying ? Colors.redAccent : Colors.pink.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Whisper Transcript
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      '“${_voicemail!['whisper_script'] ?? ''}”',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
