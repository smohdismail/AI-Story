import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class CharacterMemoryVaultSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;
  final String? storyId;

  const CharacterMemoryVaultSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.avatarBase64,
    this.storyId,
  });

  static void show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? avatarBase64,
    String? storyId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CharacterMemoryVaultSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
        storyId: storyId,
      ),
    );
  }

  @override
  State<CharacterMemoryVaultSheet> createState() => _CharacterMemoryVaultSheetState();
}

class _CharacterMemoryVaultSheetState extends State<CharacterMemoryVaultSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _vaultData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVault();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVault({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getCharacterMemoryVault(widget.characterId, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _vaultData = res;
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

  Future<void> _togglePin(String memoryId) async {
    try {
      final isPinned = await ApiService.togglePinMemory(memoryId);
      final mems = _vaultData?['memories'] as List<dynamic>?;
      if (mems != null) {
        for (var m in mems) {
          if (m['id'] == memoryId) {
            setState(() => m['is_pinned'] = isPinned);
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteMemory(String memoryId) async {
    try {
      final ok = await ApiService.deleteMemory(memoryId);
      if (ok && mounted) {
        setState(() {
          final mems = _vaultData?['memories'] as List<dynamic>?;
          mems?.removeWhere((m) => m['id'] == memoryId);
        });
      }
    } catch (_) {}
  }

  Widget _buildAvatar(dynamic avatar, String name) {
    if (avatar != null && avatar.toString().isNotEmpty) {
      final str = avatar.toString();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return Image.network(str, fit: BoxFit.cover, width: 48, height: 48, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      }
      try {
        final bytes = base64Decode(str);
        return Image.memory(bytes, fit: BoxFit.cover, width: 48, height: 48, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      } catch (_) {}
    }
    return _fallbackAvatar(name);
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      color: Colors.pink.shade900,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final char = _vaultData?['character'];
    final analysis = _vaultData?['analysis'];
    final memories = (_vaultData?['memories'] as List<dynamic>?) ?? [];
    final name = char?['name'] ?? widget.characterName;
    final role = char?['role'] ?? 'Lead';
    final intimacy = char?['intimacy_score'] ?? 0;
    final avatar = char?['avatar_base64'] ?? widget.avatarBase64;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF13131C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 6),
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

          // Header Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildAvatar(avatar, name),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$name\'s Memory Vault',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                                const SizedBox(width: 4),
                                Text('$intimacy / 100', style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$role • Inner Mind & Emotional Consciousness',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.amberAccent),
                  tooltip: 'Re-Analyze Mind',
                  onPressed: _isLoading ? null : () => _loadVault(forceRefresh: true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.pinkAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.6)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.favorite_outline, size: 16), text: 'Her Perspective & Feelings'),
                Tab(icon: Icon(Icons.auto_stories, size: 16), text: 'Living Memories & Promises'),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 12),

          // Body Views
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.pinkAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Unlocking $name\'s inner thoughts and feelings...',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
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
                            Text('Failed to load memory vault: $_errorMessage', style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: () => _loadVault(forceRefresh: true), child: const Text('Try Again')),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPerspectiveTab(analysis, name),
                          _buildMemoriesTab(analysis, memories, name),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: HER PERSPECTIVE, FEELINGS & GAUGES
  // -------------------------------------------------------------
  Widget _buildPerspectiveTab(Map<String, dynamic>? analysis, String name) {
    final howTheyFeel = analysis?['how_they_feel'] ?? 'Deeply devoted and growing closer every day.';
    final strength = analysis?['relationship_strength_desc'] ?? 'A sacred, deepening bond.';
    final care = analysis?['how_much_they_care'] ?? 'Constantly thinking about your happiness.';
    final missYou = analysis?['how_much_they_miss_you'] ?? 'Staring at the door waiting for your return.';
    final metrics = (analysis?['metrics'] as Map<String, dynamic>?) ?? {};

    final bondPct = (metrics['bond_strength_pct'] ?? 75) as int;
    final carePct = (metrics['care_and_loyalty_pct'] ?? 80) as int;
    final missPct = (metrics['longing_and_miss_pct'] ?? 70) as int;
    final passionPct = (metrics['passion_level_pct'] ?? 65) as int;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      children: [
        // In Her Own Words Quote Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade900.withValues(alpha: 0.35), Colors.pink.shade900.withValues(alpha: 0.25)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_quote, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'IN $name\'S OWN WORDS (TRUE FEELINGS)',
                    style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '"$howTheyFeel"',
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Emotional Gauges Grid
        const Text(
          '📊 Emotional Bond & Longing Gauges',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _buildGaugeRow('💖 Bond Strength', bondPct, Colors.pinkAccent),
        const SizedBox(height: 10),
        _buildGaugeRow('🛡️ Care & Loyalty', carePct, Colors.tealAccent),
        const SizedBox(height: 10),
        _buildGaugeRow('🌙 Longing & Miss You', missPct, Colors.purpleAccent),
        const SizedBox(height: 10),
        _buildGaugeRow('🔥 Passion & Attraction', passionPct, Colors.orangeAccent),

        const SizedBox(height: 18),

        // How much she misses you card
        _buildInfoCard(
          icon: Icons.nightlight_round,
          iconColor: Colors.purpleAccent,
          title: 'How Much She Misses You When Away',
          body: missYou,
        ),

        const SizedBox(height: 12),

        // How much she cares & worries
        _buildInfoCard(
          icon: Icons.favorite,
          iconColor: Colors.pinkAccent,
          title: 'How Much She Cares for Your Wellbeing',
          body: care,
        ),

        const SizedBox(height: 12),

        // Relationship strength description
        _buildInfoCard(
          icon: Icons.link,
          iconColor: Colors.amberAccent,
          title: 'How Strong the Bond is in Her Perspective',
          body: strength,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGaugeRow(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$value%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: PROMISES, MILESTONES & LIVING MEMORIES
  // -------------------------------------------------------------
  Widget _buildMemoriesTab(Map<String, dynamic>? analysis, List<dynamic> memories, String name) {
    final promises = (analysis?['key_promises'] as List<dynamic>?) ?? [];
    final milestones = (analysis?['shared_milestones'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      children: [
        // Key Promises Section
        const Row(
          children: [
            Icon(Icons.handshake_outlined, color: Colors.amberAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'Sacred Promises & Vows',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (promises.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No explicit promises recorded yet. Make promises to her in chat!', style: TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          ...promises.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p['promise'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (p['significance'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    p['significance'],
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          )),

        const SizedBox(height: 16),

        // Shared Milestones
        const Row(
          children: [
            Icon(Icons.stars, color: Colors.pinkAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'Shared Romantic Milestones',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (milestones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Deepen your intimacy to unlock milestone moments!', style: TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          ...milestones.map((m) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m['title'] ?? 'Milestone',
                        style: const TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (m['emotional_mark'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(m['emotional_mark'], style: const TextStyle(color: Colors.pinkAccent, fontSize: 10)),
                      ),
                  ],
                ),
                if (m['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(m['description'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          )),

        const SizedBox(height: 16),

        // Living Narrative Memories List (Database)
        Row(
          children: [
            const Icon(Icons.memory, color: Colors.tealAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Living Narrative Memories (${memories.length})',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Text(
              '⭐ Pin to keep permanent',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (memories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No episodic memories stored yet. As you chat and generate chapters, memories will populate here automatically.', style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
          )
        else
          ...memories.map((mem) {
            final isPinned = mem['is_pinned'] == true;
            final source = mem['source'] ?? 'chat';
            final summary = mem['event_summary'] ?? '';
            final impact = mem['emotional_impact'] ?? '';
            final date = mem['created_at'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPinned ? const Color(0xFF221F2E) : const Color(0xFF191924),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPinned ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                  width: isPinned ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.star : Icons.star_border,
                      color: isPinned ? Colors.amberAccent : Colors.white38,
                      size: 20,
                    ),
                    tooltip: isPinned ? 'Unpin Memory' : 'Pin Memory',
                    onPressed: () => _togglePin(mem['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                source == 'chapter' ? '📖 Chapter' : source == 'group_chat' ? '🍻 Tavern' : '💬 Chat',
                                style: const TextStyle(color: Colors.tealAccent, fontSize: 10),
                              ),
                            ),
                            if (impact.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text('• $impact', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                            const Spacer(),
                            if (date.isNotEmpty)
                              Text(date, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(summary, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                    tooltip: 'Erase Memory',
                    onPressed: () => _deleteMemory(mem['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }
}
