import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class PrivateWhispersSheet extends StatefulWidget {
  final String storyId;
  final String storyTitle;

  const PrivateWhispersSheet({
    super.key,
    required this.storyId,
    this.storyTitle = 'Story',
  });

  static void show(
    BuildContext context,
    dynamic storyId, {
    String storyTitle = 'Story',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrivateWhispersSheet(
        storyId: storyId.toString(),
        storyTitle: storyTitle,
      ),
    );
  }

  @override
  State<PrivateWhispersSheet> createState() => _PrivateWhispersSheetState();
}

class _PrivateWhispersSheetState extends State<PrivateWhispersSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadWhispers();
  }

  Future<void> _loadWhispers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getPrivateWhispers(widget.storyId);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatar(dynamic avatar, String name) {
    if (avatar != null && avatar.toString().isNotEmpty) {
      final str = avatar.toString();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return Image.network(str, fit: BoxFit.cover, width: 42, height: 42, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      }
      try {
        final bytes = base64Decode(str);
        return Image.memory(bytes, fit: BoxFit.cover, width: 42, height: 42, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      } catch (_) {}
    }
    return _fallbackAvatar(name);
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      width: 42,
      height: 42,
      color: Colors.pink.shade900,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF13131B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
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
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.hearing, color: Colors.purpleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'EAVESDROP MODE • PRIVATE WHISPERS',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'What they say behind your back...',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.purpleAccent),
                  tooltip: 'Eavesdrop Again',
                  onPressed: _isLoading ? null : _loadWhispers,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 12),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.purpleAccent),
                        SizedBox(height: 16),
                        Text(
                          'You stepped out of the room...\nListening to their quiet whispers...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 8),
                            Text('Failed to listen in: $_errorMessage', style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadWhispers, child: const Text('Try Again')),
                          ],
                        ),
                      )
                    : _buildWhispersContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildWhispersContent() {
    final setting = _data?['scene_setting'] ?? 'Late night in the hallway after you walked away';
    final spiciness = _data?['spiciness_rating'] ?? 'Whispered Secrets';
    final consensus = _data?['consensus'] ?? '';
    final List<dynamic> dialogue = _data?['dialogue'] ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: [
        // Setting & Atmosphere Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.door_sliding_outlined, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spiciness,
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Dialogue Turns
        ...dialogue.map((turn) {
          final speaker = turn['speaker'] ?? 'Character';
          final role = turn['role'] ?? '';
          final tone = turn['tone'] ?? '';
          final message = turn['message'] ?? '';
          final avatar = turn['avatar_base64'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildAvatar(avatar, speaker),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1E2C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              speaker,
                              style: const TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            if (role.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text('• $role', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                            const Spacer(),
                            if (tone.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(tone, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Consensus Card
        if (consensus.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900.withValues(alpha: 0.3), Colors.pink.shade900.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: Colors.pinkAccent),
                    SizedBox(width: 8),
                    Text(
                      'THEIR UNANIMOUS CONSENSUS ABOUT YOU',
                      style: TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  consensus,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action button
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadWhispers,
            icon: const Icon(Icons.hearing, size: 18),
            label: const Text('Listen to Another Secret Whisper 🤫'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
