import 'package:flutter/material.dart';
import '../api.dart';

class AutonomousGossipSheet extends StatefulWidget {
  final String storyId;
  final String storyTitle;

  const AutonomousGossipSheet({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  static Future<void> show(BuildContext context, {required String storyId, required String storyTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => AutonomousGossipSheet(
        storyId: storyId,
        storyTitle: storyTitle,
      ),
    );
  }

  @override
  State<AutonomousGossipSheet> createState() => _AutonomousGossipSheetState();
}

class _AutonomousGossipSheetState extends State<AutonomousGossipSheet> {
  bool _isLoading = true;
  bool _isGenerating = false;
  List<dynamic> _gossips = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGossip();
  }

  Future<void> _loadGossip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ApiService.getStoryGossip(widget.storyId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _gossips = items;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _generateNewGossip() async {
    setState(() => _isGenerating = true);
    try {
      final newGossip = await ApiService.generateStoryGossip(widget.storyId);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _gossips.insert(0, newGossip);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF8B5CF6),
            content: Row(
              children: [
                const Icon(Icons.hearing, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('🕵️ Overheard new whispers in ${newGossip['location'] ?? 'the hallway'}!'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not eavesdrop right now: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF131522),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 25, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.record_voice_over, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overheard Hallway Whispers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'What characters say when they think you aren\'t around',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC084FC)))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _gossips.isEmpty
                        ? _buildEmptyState()
                        : _buildGossipList(),
          ),

          // Bottom Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hearing, color: Color(0xFFA78BFA), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quiet in the Hallways...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No whispers overheard yet. When you step away, characters gossip about your glances, your conversations, and private secrets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateNewGossip,
              icon: _isGenerating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.hearing, size: 18),
              label: const Text('Listen In Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Failed to load whispers', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadGossip,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGossipList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _gossips.length,
      itemBuilder: (context, idx) {
        final g = _gossips[idx];
        final c1 = g['character1_name'] ?? 'Character';
        final c2 = g['character2_name'] ?? 'Companion';
        final topic = g['topic'] ?? 'Secret whisper';
        final location = g['location'] ?? 'Hallway';
        final dialogue = (g['dialogue'] as List<dynamic>? ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF191D2D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF231E3D),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.purpleAccent,
                      child: Text(c1[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.tealAccent.shade700,
                      child: Text(c2[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$c1 & $c2',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '📍 $location',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hearing, size: 10, color: Colors.pinkAccent),
                          SizedBox(width: 4),
                          Text('OVERHEARD', style: TextStyle(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Topic Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        topic,
                        style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // Dialogue Turns
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: dialogue.map((d) {
                    final speaker = d['speaker'] ?? '';
                    final text = d['text'] ?? '';
                    final action = d['action'] as String?;
                    final isC1 = speaker == c1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: isC1 ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isC1 ? const Color(0xFF26233B) : const Color(0xFF1B2E36),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isC1 ? Colors.purple.withValues(alpha: 0.3) : Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isC1 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(
                              speaker,
                              style: TextStyle(
                                color: isC1 ? const Color(0xFFD8B4FE) : const Color(0xFF5EEAD4),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (action != null && action.isNotEmpty) ...[
                              Text(
                                action,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              '"$text"',
                              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F111A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateNewGossip,
            icon: _isGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.hearing, size: 18),
            label: Text(_isGenerating ? 'Eavesdropping on Hallway Whispers...' : '🕵️ Listen In (Eavesdrop New Whispers)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
