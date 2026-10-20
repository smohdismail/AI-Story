import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';

class SharedDreamSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const SharedDreamSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.avatarBase64,
  });

  static void show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? avatarBase64,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SharedDreamSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<SharedDreamSheet> createState() => _SharedDreamSheetState();
}

class _SharedDreamSheetState extends State<SharedDreamSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _dreams = [];
  Map<String, dynamic>? _selectedDream;
  bool _isDreaming = false;

  @override
  void initState() {
    super.initState();
    _loadDreams();
  }

  Future<void> _loadDreams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getCharacterSharedDreams(widget.characterId);
      setState(() {
        _dreams = list;
        _isLoading = false;
        if (list.isNotEmpty) {
          _selectedDream = list.first;
        }
      });

      // If no dream recorded yet, auto-generate the first shared dream!
      if (list.isEmpty) {
        _dreamTogether();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _dreamTogether() async {
    HapticFeedback.heavyImpact();
    setState(() => _isDreaming = true);

    try {
      final res = await ApiService.dreamTogether(widget.characterId);
      if (res['dream'] != null) {
        setState(() {
          _dreams.insert(0, res['dream']);
          _selectedDream = res['dream'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dream error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDreaming = false);
    }
  }

  Widget _buildAvatarImage(dynamic avatar, String name) {
    if (avatar != null && avatar.toString().isNotEmpty) {
      final str = avatar.toString();
      if (str.startsWith('http')) {
        return Image.network(str, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      }
      try {
        final bytes = base64Decode(str);
        return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      } catch (_) {}
    }
    return _fallbackAvatar(name);
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      color: Colors.indigo.shade900,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0C091A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0xFF321356), blurRadius: 28, spreadRadius: 4),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.nightlight_round, color: Colors.purpleAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shared Dreams & Astral Reverie 🌙',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Subconscious Dreamscapes with ${widget.characterName}',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isDreaming ? null : _dreamTogether,
                  icon: _isDreaming
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent))
                      : const Icon(Icons.auto_awesome, size: 14, color: Colors.purpleAccent),
                  label: const Text('Dream', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade900.withValues(alpha: 0.4),
                    foregroundColor: Colors.purpleAccent,
                    side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: _isLoading || _isDreaming
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.purpleAccent),
                        SizedBox(height: 14),
                        Text(
                          'Entering the Astral Dream Realm together...',
                          style: TextStyle(color: Colors.purpleAccent, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : _selectedDream == null
                    ? const Center(child: Text('No dreams shared yet.', style: TextStyle(color: Colors.white54)))
                    : _buildDreamContent(_selectedDream!),
          ),
        ],
      ),
    );
  }

  Widget _buildDreamContent(Map<String, dynamic> dream) {
    final title = dream['dream_realm_title'] ?? 'The Starfall Ocean';
    final atmosphere = dream['surreal_atmosphere'] ?? '';
    final narrative = dream['dream_narrative'] ?? '';
    final secret = dream['shared_secret_unlocked'] ?? '';
    final morningMsg = dream['morning_after_message'] ?? '';
    final avatar = widget.avatarBase64;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dream Realm Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF23103A), Color(0xFF130E26), Color(0xFF0C192E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.shade900.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Lunar Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.purpleAccent, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.6), blurRadius: 12),
                        ],
                      ),
                      child: ClipOval(child: _buildAvatarImage(avatar, widget.characterName)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dream['created_at'] ?? 'Under the midnight stars',
                            style: const TextStyle(fontSize: 11, color: Colors.purpleAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (atmosphere.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.blur_on, size: 14, color: Colors.tealAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            atmosphere,
                            style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Dream Narrative
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131024),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 15, color: Colors.amberAccent),
                    SizedBox(width: 8),
                    Text(
                      'The Dream Encounter',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  narrative,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14.5,
                    height: 1.8,
                    color: Color(0xFFE4DCF5),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Subconscious Secret Revealed
          if (secret.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade900.withValues(alpha: 0.35), const Color(0xFF26102D)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.vpn_key, size: 15, color: Colors.pinkAccent),
                      SizedBox(width: 8),
                      Text(
                        'Subconscious Secret Unlocked 🗝️',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    secret,
                    style: const TextStyle(fontSize: 13.5, color: Colors.white, fontStyle: FontStyle.italic, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Morning-After Message
          if (morningMsg.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101928),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, size: 15, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Morning-After Message from ${widget.characterName} ☀️',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    morningMsg,
                    style: const TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
