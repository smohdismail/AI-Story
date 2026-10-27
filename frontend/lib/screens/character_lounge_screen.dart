import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../api.dart';
import '../widgets/private_whispers_sheet.dart';
import '../widgets/character_memory_vault_sheet.dart';
import '../widgets/vintage_mailbox_sheet.dart';
import '../widgets/shared_dream_sheet.dart';
import '../widgets/domestic_bliss_sheet.dart';

class CharacterLoungeScreen extends StatefulWidget {
  const CharacterLoungeScreen({super.key});

  @override
  State<CharacterLoungeScreen> createState() => _CharacterLoungeScreenState();
}

class _CharacterLoungeScreenState extends State<CharacterLoungeScreen> {
  List<dynamic> _characters = [];
  bool _isLoading = true;
  bool _isOwner = false;
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
      final prof = await ApiService.getMyProfile();
      if (mounted) setState(() => _isOwner = prof['is_owner'] == true);
    } catch (_) {}
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
      if (!_isOwner && c['is_published'] == false && c['is_own'] != true) {
        continue;
      }
      final t = c['story_title']?.toString();
      if (t != null && t.isNotEmpty) titles.add(t);
    }
    return titles.toList();
  }

  List<dynamic> get _filteredCharacters {
    return _characters.where((c) {
      if (!_isOwner && c['is_published'] == false && c['is_own'] != true) {
        return false;
      }
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
          if (_isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
              child: Tooltip(
                message: '👑 Owner Master Mode: Full Access to ALL Platform Characters',
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
                      Text('ALL CHARACTERS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
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
                          if (char['is_published'] == false) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, size: 9, color: Colors.deepOrangeAccent),
                                  SizedBox(width: 2),
                                  Text('Private', style: TextStyle(fontSize: 9, color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
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
                        'avatarBase64': avatar ?? char['avatar_base64'],
                        'backgroundImage': char['background_base64'] ?? avatar ?? char['avatar_base64'],
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
            const SizedBox(height: 8),
            // Action Button Row 3: Midnight Phone Call
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMidnightPhoneCallDialog(char),
                icon: const Icon(Icons.phone_in_talk, size: 16),
                label: const Text('📲 Midnight Phone Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Action Button Row 4: Memory Vault & Feelings + Private Whispers
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => CharacterMemoryVaultSheet.show(
                      context,
                      characterId: char['id'].toString(),
                      characterName: name,
                      avatarBase64: char['avatar_base64']?.toString(),
                      storyId: char['story_id']?.toString(),
                    ),
                    icon: const Icon(Icons.psychology, size: 16, color: Colors.cyanAccent),
                    label: const Text('🧠 Memory Vault & Feelings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2538),
                      side: const BorderSide(color: Colors.cyanAccent, width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (char['story_id'] != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => PrivateWhispersSheet.show(context, char['story_id'].toString()),
                    icon: const Icon(Icons.record_voice_over, color: Colors.purpleAccent, size: 18),
                    tooltip: 'Eavesdrop Whispers',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.purple.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Action Button Row 5: Mailbox, Dreamworld & Domestic Bliss
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => VintageMailboxSheet.show(
                      context,
                      characterId: char['id'].toString(),
                      characterName: name,
                      avatarBase64: char['avatar_base64']?.toString(),
                    ),
                    icon: const Icon(Icons.markunread_mailbox, size: 14, color: Colors.amber),
                    label: const Text('📬 Mailbox', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900.withValues(alpha: 0.25),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => SharedDreamSheet.show(
                      context,
                      characterId: char['id'].toString(),
                      characterName: name,
                      avatarBase64: char['avatar_base64']?.toString(),
                    ),
                    icon: const Icon(Icons.nightlight_round, size: 14, color: Colors.purpleAccent),
                    label: const Text('🌙 Dream', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade900.withValues(alpha: 0.25),
                      side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => DomesticBlissSheet.show(
                      context,
                      characterId: char['id'].toString(),
                      characterName: name,
                      avatarBase64: char['avatar_base64']?.toString(),
                    ),
                    icon: const Icon(Icons.cottage, size: 14, color: Colors.orangeAccent),
                    label: const Text('🏡 Bliss', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade900.withValues(alpha: 0.25),
                      side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
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

  void _showMidnightPhoneCallDialog(Map<String, dynamic> char) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MidnightPhoneCallDialog(char: char),
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

// ==========================================
// FEATURE 2: 📲 MIDNIGHT PHONE CALL DIALOG
// ==========================================

class _MidnightPhoneCallDialog extends StatefulWidget {
  final Map<String, dynamic> char;
  const _MidnightPhoneCallDialog({required this.char});

  @override
  State<_MidnightPhoneCallDialog> createState() => _MidnightPhoneCallDialogState();
}

class _MidnightPhoneCallDialogState extends State<_MidnightPhoneCallDialog> with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _callStatus = 'ringing'; // 'ringing', 'connected', 'ended'
  int _callSeconds = 0;
  Timer? _callTimer;
  int _turn = 1;

  Map<String, dynamic>? _callData;
  bool _isSpeaking = false;
  bool _isLoadingResponse = false;
  final TextEditingController _customWhisperCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseController.dispose();
    _tts.stop();
    _customWhisperCtrl.dispose();
    super.dispose();
  }

  void _answerCall() async {
    final charId = widget.char['id']?.toString() ?? '';
    setState(() {
      _callStatus = 'connected';
      _isLoadingResponse = true;
    });

    _startTimer();

    try {
      final res = await ApiService.startMidnightPhoneCall(charId);
      if (mounted) {
        setState(() {
          _callData = res['call_data'] as Map<String, dynamic>?;
          _isLoadingResponse = false;
        });
        _speakCharacterSpeech();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingResponse = false);
      }
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _callSeconds++);
      }
    });
  }

  String _formatCallDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _speakCharacterSpeech() async {
    final text = _callData?['clean_tts_text']?.toString() ?? _callData?['character_speech']?.toString();
    if (text != null && text.isNotEmpty) {
      await _tts.setSpeechRate(0.36);
      await _tts.setPitch(0.92);
      setState(() => _isSpeaking = true);
      await _tts.speak(text);
    }
  }

  void _sendWhisper(String whisper) async {
    final charId = widget.char['id']?.toString() ?? '';
    setState(() {
      _isLoadingResponse = true;
      _turn++;
    });
    await _tts.stop();

    try {
      final res = await ApiService.respondMidnightPhoneCall(charId, whisper: whisper, turn: _turn);
      if (mounted) {
        setState(() {
          _callData = res['call_data'] as Map<String, dynamic>?;
          _isLoadingResponse = false;
        });
        _speakCharacterSpeech();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingResponse = false);
      }
    }
  }

  void _hangUp() {
    _callTimer?.cancel();
    _tts.stop();
    setState(() => _callStatus = 'ended');
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Widget _buildAvatar() {
    final avatar = widget.char['avatar_base64'];
    final name = widget.char['name'] ?? 'Character';
    if (avatar != null && avatar.toString().isNotEmpty) {
      try {
        final bytes = base64Decode(avatar);
        return CircleAvatar(radius: 46, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return CircleAvatar(
      radius: 46,
      backgroundColor: Colors.teal.shade800,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.char['name'] ?? 'Character';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // Caller Avatar & Pulse
          ScaleTransition(
            scale: _callStatus == 'ringing' ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _callStatus == 'connected' ? Colors.tealAccent : (_callStatus == 'ended' ? Colors.redAccent : Colors.cyanAccent),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_callStatus == 'connected' ? Colors.tealAccent : Colors.cyanAccent).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: _buildAvatar(),
            ),
          ),
          const SizedBox(height: 16),

          // Caller Name & Call Status
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            _callStatus == 'ringing'
                ? 'Incoming Call • 2:34 AM...'
                : (_callStatus == 'connected' ? _formatCallDuration(_callSeconds) : 'Call Ended'),
            style: TextStyle(
              fontSize: 13,
              color: _callStatus == 'connected' ? Colors.tealAccent : Colors.white70,
              fontWeight: _callStatus == 'connected' ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          // Ambient sound indicator
          if (_callStatus == 'connected' && _callData != null && _callData!['ambient_description'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🎧 ${_callData!['ambient_description']}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Main Call Content Area
          Expanded(
            child: _callStatus == 'ringing'
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.nightlight_round, size: 36, color: Colors.cyanAccent),
                        const SizedBox(height: 12),
                        Text(
                          '$name is calling in the quiet of the night...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white60),
                        ),
                      ],
                    ),
                  )
                : (_callStatus == 'ended'
                    ? const Center(
                        child: Text('Call Ended', style: TextStyle(color: Colors.white38, fontSize: 16)),
                      )
                    : ListView(
                        children: [
                          // Character speech bubble
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
                            ),
                            child: _isLoadingResponse
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)),
                                          SizedBox(width: 10),
                                          Text('Listening to the line...', style: TextStyle(fontSize: 12, color: Colors.white60)),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isSpeaking ? Icons.graphic_eq : Icons.volume_up,
                                            size: 16,
                                            color: Colors.tealAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _callData?['emotional_tone'] ?? 'Intimate whisper',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: Icon(_isSpeaking ? Icons.stop : Icons.replay, size: 16, color: Colors.white70),
                                            onPressed: _speakCharacterSpeech,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _callData?['character_speech'] ?? '“...”',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.white,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Whisper response choices
                          const Text('Whisper back softly:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                          const SizedBox(height: 8),
                          if (_callData != null && _callData!['whisper_options'] is List)
                            ...(_callData!['whisper_options'] as List).map((opt) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: _isLoadingResponse ? null : () => _sendWhisper(opt.toString()),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.cyanAccent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            opt.toString(),
                                            style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                          // Custom whisper text input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customWhisperCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Whisper your own words...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.white10,
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.tealAccent),
                                onPressed: () {
                                  final text = _customWhisperCtrl.text.trim();
                                  if (text.isNotEmpty) {
                                    _customWhisperCtrl.clear();
                                    _sendWhisper(text);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      )),
          ),

          const SizedBox(height: 16),

          // Bottom Call Control Buttons
          if (_callStatus == 'ringing')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 6),
                      const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // Answer Button
                GestureDetector(
                  onTap: _answerCall,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.call, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 6),
                      const Text('Answer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            )
          else if (_callStatus == 'connected')
            GestureDetector(
              onTap: _hangUp,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 6),
                  const Text('Hang Up', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

