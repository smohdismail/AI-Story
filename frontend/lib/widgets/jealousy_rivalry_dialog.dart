import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';

class JealousyRivalryDialog extends StatefulWidget {
  final String storyId;
  final String storyTitle;

  const JealousyRivalryDialog({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  static void show(BuildContext context, {required String storyId, required String storyTitle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JealousyRivalryDialog(storyId: storyId, storyTitle: storyTitle),
    );
  }

  @override
  State<JealousyRivalryDialog> createState() => _JealousyRivalryDialogState();
}

class _JealousyRivalryDialogState extends State<JealousyRivalryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _heatmapData;

  // Active confrontation
  Map<String, dynamic>? _activeConfrontation;
  bool _isTriggering = false;
  bool _isResolving = false;
  String? _resolvedChoice;
  String? _resolutionNarrative;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHeatmap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHeatmap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getStoryJealousyHeatmap(widget.storyId);
      setState(() {
        _heatmapData = res;
        _isLoading = false;
      });

      // If there are recent confrontations, select the most recent one
      final recents = res['recent_confrontations'] as List<dynamic>?;
      if (recents != null && recents.isNotEmpty && _activeConfrontation == null) {
        // Can auto-select or let user trigger new
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerConfrontation() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isTriggering = true;
      _resolvedChoice = null;
      _resolutionNarrative = null;
    });

    try {
      final res = await ApiService.triggerJealousyConfrontation(widget.storyId);
      if (res['confrontation'] != null) {
        setState(() {
          _activeConfrontation = res['confrontation'];
          _tabController.animateTo(0);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confrontation error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  Future<void> _makeChoice(Map<String, dynamic> choice) async {
    if (_activeConfrontation == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isResolving = true);

    try {
      final res = await ApiService.resolveJealousyConfrontation(
        _activeConfrontation!['id'],
        choiceKey: choice['key'] ?? 'A',
        choiceAction: choice['action_text'] ?? choice['label'] ?? '',
      );

      setState(() {
        _resolvedChoice = res['resolved_choice'];
        _resolutionNarrative = res['resolution_narrative'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
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
      color: Colors.red.shade900,
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
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF131018),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0xFF4A1028), blurRadius: 28, spreadRadius: 4),
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
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.flash_on, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jealousy & Rivalry Drama 🎭',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Dynamic Harem Tension in "${widget.storyTitle}"',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isTriggering ? null : _triggerConfrontation,
                  icon: _isTriggering
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                      : const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                  label: const Text('Encounter ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900.withValues(alpha: 0.4),
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.forum, size: 18), text: 'Confrontation Encounter'),
              Tab(icon: Icon(Icons.heat_pump, size: 18), text: 'Tension Heatmap'),
            ],
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildConfrontationTab(),
                          _buildHeatmapTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfrontationTab() {
    if (_isTriggering) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 14),
            Text('Generating dramatic confrontation encounter...', style: TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    if (_activeConfrontation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.heart_broken, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'No Active Confrontation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you spend time with one heroine, the others take notice. Tap below to trigger a live unexpected confrontation scene!',
                style: TextStyle(fontSize: 12, color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _triggerConfrontation,
                icon: const Icon(Icons.flash_on, color: Colors.white),
                label: const Text('Trigger Dramatic Encounter ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700),
              ),
            ],
          ),
        ),
      );
    }

    final conf = _activeConfrontation!;
    final pName = conf['primary_character_name'] ?? 'Primary Character';
    final rName = conf['rival_character_name'] ?? 'Rival Character';
    final pAvatar = conf['primary_avatar'];
    final rAvatar = conf['rival_avatar'];
    final turns = (conf['dialogue_turns'] as List<dynamic>?) ?? [];
    final choices = (conf['choices'] as List<dynamic>?) ?? [];
    final tension = conf['tension_score'] ?? 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Face-to-Face Dual Avatars & Tension Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900.withValues(alpha: 0.3), Colors.red.shade900.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Primary Character
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.pinkAccent, width: 2),
                          ),
                          child: ClipOval(child: _buildAvatarImage(pAvatar, pName)),
                        ),
                        const SizedBox(height: 4),
                        Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.pinkAccent)),
                      ],
                    ),

                    // Tension Meter in Center
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                              Text('$tension% Tension', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
                              const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: tension / 100.0,
                                minHeight: 6,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  tension > 75 ? Colors.redAccent : Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rival Character
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent, width: 2),
                          ),
                          child: ClipOval(child: _buildAvatarImage(rAvatar, rName)),
                        ),
                        const SizedBox(height: 4),
                        Text(rName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conf['opening_situation'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dialogue Exchange
          ...turns.map((t) {
            final speaker = t['speaker'] ?? '';
            final isPrimary = speaker.toString().toLowerCase().contains(pName.toLowerCase());
            final tone = t['tone'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary ? const Color(0xFF261424) : const Color(0xFF2A1517),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPrimary ? Colors.pinkAccent.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          speaker,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isPrimary ? Colors.pinkAccent : Colors.redAccent,
                          ),
                        ),
                        if (tone.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tone,
                              style: const TextStyle(fontSize: 10, color: Colors.white54, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t['text'] ?? '',
                      style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 14),

          // Resolution / Interactive Choices
          if (_resolutionNarrative != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14241B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resolvedChoice ?? 'Confrontation Resolved',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _resolutionNarrative!,
                    style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.7),
                  ),
                ],
              ),
            ),
          ] else if (choices.isNotEmpty) ...[
            const Text(
              'How do you respond to both of them?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
            ),
            const SizedBox(height: 10),
            ...choices.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isResolving ? null : () => _makeChoice(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF241C24),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['key'] ?? '•'}. ${c['label'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.amber),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c['action_text'] ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHeatmapTab() {
    final heatmap = (_heatmapData?['tension_heatmap'] as List<dynamic>?) ?? [];
    if (heatmap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Need at least 2 characters in this story to generate rivalry dynamics.',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: heatmap.length,
      itemBuilder: (ctx, i) {
        final item = heatmap[i];
        final c1 = item['char1'] ?? '';
        final c2 = item['char2'] ?? '';
        final score = item['tension_score'] ?? 50;
        final dynamicName = item['dynamic'] ?? '';
        final reason = item['reason'] ?? '';

        return Card(
          color: const Color(0xFF1E1822),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$c1 ⚡ $c2',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: score > 75 ? Colors.red.shade900 : Colors.amber.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$score% Rivalry',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dynamicName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
