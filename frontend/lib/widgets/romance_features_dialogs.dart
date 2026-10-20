import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

// ==========================================
// 1. TENSION & JEALOUSY DIAL BOTTOM SHEET
// ==========================================
class TensionDialSheet extends StatefulWidget {
  final String storyId;
  final int initialLevel;
  final Function(int level)? onUpdated;

  const TensionDialSheet({
    super.key,
    required this.storyId,
    this.initialLevel = 2,
    this.onUpdated,
  });

  static void show(BuildContext context, String storyId, {int initialLevel = 2, Function(int level)? onUpdated}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => TensionDialSheet(storyId: storyId, initialLevel: initialLevel, onUpdated: onUpdated),
    );
  }

  @override
  State<TensionDialSheet> createState() => _TensionDialSheetState();
}

class _TensionDialSheetState extends State<TensionDialSheet> {
  late double _currentLevel;
  bool _isSaving = false;

  final Map<int, Map<String, String>> _levels = {
    1: {
      'emoji': '🌸',
      'title': 'Level 1: Sweet & Gentle Romance',
      'desc': 'Soft warmth, wholesome comfort, lingering shy smiles, gentle touches, and pure emotional tenderness.',
      'color': '#FFB6C1',
    },
    2: {
      'emoji': '🍷',
      'title': 'Level 2: Teasing & Flirty Banter',
      'desc': 'Witty push-and-pull banter, mischievous smiles, playful tension, and magnetic stolen glances.',
      'color': '#FFD700',
    },
    3: {
      'emoji': '⚡',
      'title': 'Level 3: Simmering Jealousy & Rivalry',
      'desc': 'A rival or suitor sparks territorial instincts; flared tempers, protective body language, and heightened possessiveness.',
      'color': '#FF8C00',
    },
    4: {
      'emoji': '🔥',
      'title': 'Level 4: High-Heat Standoff',
      'desc': 'Breathless proximity, pinned against walls, heated confrontations, and undeniable physical passion.',
      'color': '#FF4500',
    },
    5: {
      'emoji': '🖤',
      'title': 'Level 5: Pure Dark Romance & Obsession',
      'desc': 'Dangerous possessiveness, raw uncensored vows, ruthless protection, and overwhelming forbidden passion.',
      'color': '#DC143C',
    },
  };

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.initialLevel.toDouble().clamp(1.0, 5.0);
  }

  Future<void> _saveTension() async {
    setState(() => _isSaving = true);
    final int lvl = _currentLevel.round();
    try {
      await ApiService.updateTensionDial(widget.storyId, lvl);
      if (widget.onUpdated != null) widget.onUpdated!(lvl);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tension Dial set to Level $lvl! Upcoming chapters will reflect this heat.'),
            backgroundColor: Colors.amber[900],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int lvl = _currentLevel.round();
    final data = _levels[lvl]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'Tension & Jealousy Dial',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Control the exact emotional heat, banter, and jealousy level for your next chapters.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // Active Level Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(data['emoji']!, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['title']!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['desc']!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.amber,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.amberAccent,
              overlayColor: Colors.amber.withValues(alpha: 0.2),
              valueIndicatorColor: Colors.amber[900],
            ),
            child: Slider(
              value: _currentLevel,
              min: 1.0,
              max: 5.0,
              divisions: 4,
              label: 'Level $lvl',
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _currentLevel = val);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🌸 Sweet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              Text('🍷 Flirty', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              Text('⚡ Jealousy', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              Text('🔥 High Heat', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              Text('🖤 Dark Obsession', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),

          // Save button
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveTension,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Applying Setting...' : 'Set Active Tension (Level $lvl)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ==========================================
// 2. THE CLIMAX & PROPOSAL MILESTONE DIALOG
// ==========================================
class ClimaxMilestoneDialog extends StatefulWidget {
  final String storyId;
  final String? leadName;

  const ClimaxMilestoneDialog({super.key, required this.storyId, this.leadName});

  static void show(BuildContext context, String storyId, {String? leadName}) {
    showDialog(
      context: context,
      builder: (context) => ClimaxMilestoneDialog(storyId: storyId, leadName: leadName),
    );
  }

  @override
  State<ClimaxMilestoneDialog> createState() => _ClimaxMilestoneDialogState();
}

class _ClimaxMilestoneDialogState extends State<ClimaxMilestoneDialog> {
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSavingChoice = false;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _climaxData;
  Map<String, dynamic>? _keepsake;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await ApiService.getClimaxMilestoneStatus(widget.storyId);
      setState(() {
        _status = res;
        _keepsake = res['keepsake'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateClimax() async {
    setState(() => _isGenerating = true);
    HapticFeedback.heavyImpact();
    try {
      final res = await ApiService.generateClimaxMilestone(widget.storyId, leadCharacterName: widget.leadName);
      setState(() {
        _climaxData = res['climax_data'];
        _isGenerating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating climax: $e')));
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _chooseClimaxBranch(String choice) async {
    if (_climaxData == null) return;
    setState(() => _isSavingChoice = true);
    HapticFeedback.mediumImpact();
    try {
      final lead = _climaxData!['lead_name'] ?? widget.leadName ?? 'Lead';
      final vow = _climaxData!['keepsake_vow'] ?? 'Forever bound.';
      final res = await ApiService.saveClimaxChoice(
        widget.storyId,
        selectedChoice: choice,
        leadName: lead,
        keepsakeVow: vow,
        destinyScore: _climaxData!['destiny_score'],
      );
      setState(() {
        _keepsake = res['keepsake'];
        _isSavingChoice = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💍 Proposal vow engraved into story keepsake!'), backgroundColor: Colors.amber),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSavingChoice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141218),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pinkAccent, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Grand Climax & Proposal Milestone',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_status!['is_unlocked'] == true ? Colors.green : Colors.pinkAccent).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (_status!['is_unlocked'] == true ? Colors.greenAccent : Colors.pinkAccent).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _status!['is_unlocked'] == true ? Icons.check_circle : Icons.lock_clock,
                                    size: 13,
                                    color: _status!['is_unlocked'] == true ? Colors.greenAccent : Colors.pinkAccent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _status!['is_unlocked'] == true
                                        ? 'Endgame Milestone Unlocked (${_status!['chapter_count'] ?? 0} Chs)'
                                        : 'Chapter Progress: ${_status!['chapter_count'] ?? 0} / 5',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _status!['is_unlocked'] == true ? Colors.greenAccent : Colors.pinkAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // If Keepsake exists, show the Keepsake Certificate
                    if (_keepsake != null) ...[
                      _buildKeepsakeCertificate(),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => setState(() => _keepsake = null),
                        icon: const Icon(Icons.refresh, color: Colors.amber, size: 16),
                        label: const Text('Re-experience Climax Scene', style: TextStyle(color: Colors.amber)),
                      ),
                    ] else if (_climaxData != null) ...[
                      // Climax scene view
                      _buildClimaxSceneView(),
                    ] else ...[
                      // Initial prompt to trigger climax
                      _buildClimaxUnlockPrompt(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildClimaxUnlockPrompt() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Colors.purple[700]!, Colors.pinkAccent]),
            boxShadow: [
              BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.ring_volume, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'The Moment of Ultimate Truth',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'When romantic tension reaches its boiling point, pride breaks down. A high-stakes confession, grand gesture, or proposal awaits your leads in the rain.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : _generateClimax,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isGenerating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.auto_awesome),
          label: Text(
            _isGenerating ? 'Weaving Grand Gesture & Proposal...' : 'Begin Climax & Proposal Event 💍',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildClimaxSceneView() {
    final title = _climaxData!['title'] ?? 'The Grand Confession';
    final scene = _climaxData!['dramatic_scene'] ?? '';
    final speech = _climaxData!['lead_speech'] ?? '';
    final choices = (_climaxData!['choices'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.2)),
          ),
          child: Text(
            scene,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 14),
        if (speech.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    speech,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'YOUR MOMENT OF DECISION:',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        ...choices.map((c) {
          final choiceText = c.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ElevatedButton(
              onPressed: _isSavingChoice ? null : () => _chooseClimaxBranch(choiceText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(choiceText, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKeepsakeCertificate() {
    final lead = _keepsake!['lead_name'] ?? 'Lead';
    final user = _keepsake!['user_name'] ?? 'Beloved';
    final vow = _keepsake!['keepsake_vow'] ?? '';
    final date = _keepsake!['completed_at'] ?? '';
    final choice = _keepsake!['selected_choice'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 36),
          const SizedBox(height: 8),
          const Text(
            'HAPPILY EVER AFTER VOW',
            style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '$lead  &  $user',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.amber, height: 24),
          Text(
            '"$vow"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Choice Chosen: "$choice"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            'Sealed on $date',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 10, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. CHARACTER VOICEMAIL BOX & MIDNIGHT MEMOS
// ==========================================
class CharacterVoicemailsSheet extends StatefulWidget {
  final Map<String, dynamic> character;

  const CharacterVoicemailsSheet({super.key, required this.character});

  static void show(BuildContext context, Map<String, dynamic> character) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => CharacterVoicemailsSheet(character: character),
    );
  }

  @override
  State<CharacterVoicemailsSheet> createState() => _CharacterVoicemailsSheetState();
}

class _CharacterVoicemailsSheetState extends State<CharacterVoicemailsSheet> {
  List<dynamic> _voicemails = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadVoicemails();
  }

  Future<void> _loadVoicemails() async {
    try {
      final list = await ApiService.getCharacterVoicemails(widget.character['id'].toString());
      if (mounted) {
        setState(() {
          _voicemails = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateNewMemo() async {
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();
    try {
      await ApiService.generateCharacterVoicemail(widget.character['id'].toString());
      await _loadVoicemails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New midnight memo received from ${widget.character['name']}!'),
            backgroundColor: Colors.teal[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.character['name'] ?? 'Character';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.mic, color: Colors.tealAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '$name\'s Voicemail Box',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateNewMemo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.phone_in_talk, size: 18),
                label: Text(_isGenerating ? 'Recording Midnight Memo...' : 'Request Spontaneous Midnight Memo 🎙️'),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_voicemails.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.voicemail, color: Colors.white.withValues(alpha: 0.3), size: 48),
                        const SizedBox(height: 10),
                        const Text('No voicemails left yet.', style: TextStyle(color: Colors.white60)),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap the button above to have them leave a midnight voice memo.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._voicemails.map((vm) {
                  final id = vm['id'].toString();
                  final isPlaying = _currentlyPlayingId == id;
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  vm['timestamp_label'] ?? 'Late Night',
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vm['location_label'] ?? 'Unknown location',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  color: Colors.tealAccent,
                                  size: 32,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _currentlyPlayingId = isPlaying ? null : id;
                                  });
                                  ApiService.listenVoicemail(id);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.graphic_eq, color: Colors.white38, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                vm['ambient_sound'] ?? 'Rain against glass',
                                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              vm['transcript'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 4. DESTINY TAROT & ROMANCE PROPHECY DIALOG
// ==========================================
class DestinyTarotDialog extends StatefulWidget {
  final String storyId;
  final Function(String twist)? onInjected;

  const DestinyTarotDialog({super.key, required this.storyId, this.onInjected});

  static void show(BuildContext context, String storyId, {Function(String twist)? onInjected}) {
    showDialog(
      context: context,
      builder: (context) => DestinyTarotDialog(storyId: storyId, onInjected: onInjected),
    );
  }

  @override
  State<DestinyTarotDialog> createState() => _DestinyTarotDialogState();
}

class _DestinyTarotDialogState extends State<DestinyTarotDialog> {
  bool _isLoading = true;
  bool _isInjecting = false;
  Map<String, dynamic>? _tarotData;
  String? _activeProphecy;

  @override
  void initState() {
    super.initState();
    _drawCards();
  }

  Future<void> _drawCards() async {
    try {
      final res = await ApiService.drawRomanceTarot(widget.storyId);
      if (mounted) {
        setState(() {
          _tarotData = res['tarot_data'];
          _activeProphecy = res['active_prophecy'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _injectProphecy() async {
    final twist = _tarotData?['prophecy_twist'];
    if (twist == null) return;
    setState(() => _isInjecting = true);
    try {
      await ApiService.injectProphecy(widget.storyId, twist);
      setState(() => _activeProphecy = twist);
      if (widget.onInjected != null) widget.onInjected!(twist);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔮 Tarot prophecy twist injected into next chapter!'), backgroundColor: Colors.purple),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isInjecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161020),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(18),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Destiny Romance Tarot',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 6),
                    Text(
                      _tarotData?['spread_theme'] ?? 'The Crimson Thread of Fate',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (_activeProphecy != null && _activeProphecy!.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Active Prophecy: $_activeProphecy',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Cards row
                    if (_tarotData?['cards'] != null)
                      ...(_tarotData!['cards'] as List<dynamic>).map((card) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card['symbol'] ?? '🎴', style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${card['position']}: ${card['name']}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      card['meaning'] ?? '',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      card['story_reading'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 14),

                    // Prophecy twist
                    if (_tarotData?['prophecy_twist'] != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flash_on, color: Colors.purpleAccent, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'CANON PROPHECY TWIST:',
                                  style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _tarotData!['prophecy_twist'],
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _isInjecting ? null : _injectProphecy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent[700],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isInjecting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_fix_high),
                        label: Text(_isInjecting ? 'Injecting Fate...' : 'Inject Prophecy into Next Chapter 🔮'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ==========================================
// 5. WARDROBE & EVENT STYLIST SHEET
// ==========================================
class WardrobeClosetSheet extends StatefulWidget {
  final Map<String, dynamic> character;
  final VoidCallback? onEquipped;

  const WardrobeClosetSheet({super.key, required this.character, this.onEquipped});

  static void show(BuildContext context, Map<String, dynamic> character, {VoidCallback? onEquipped}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16141D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => WardrobeClosetSheet(character: character, onEquipped: onEquipped),
    );
  }

  @override
  State<WardrobeClosetSheet> createState() => _WardrobeClosetSheetState();
}

class _WardrobeClosetSheetState extends State<WardrobeClosetSheet> {
  final TextEditingController _outfitController = TextEditingController();
  List<dynamic> _outfits = [];
  String? _activeWardrobe;
  bool _isLoading = true;
  bool _isGenerating = false;

  final List<String> _presetOutfits = [
    'Midnight Masquerade Ball Gown',
    'Rainy Leather Jacket & Motorcycle',
    'Lazy Morning Silk Robe',
    'Royal Coronation Velvet Suit',
    'Sunlit Linen Beach Attire',
  ];

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  @override
  void dispose() {
    _outfitController.dispose();
    super.dispose();
  }

  Future<void> _loadWardrobe() async {
    try {
      final res = await ApiService.getCharacterWardrobe(widget.character['id'].toString());
      if (mounted) {
        setState(() {
          _outfits = res['outfits'] ?? [];
          _activeWardrobe = res['active_wardrobe'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateOutfit(String concept) async {
    if (concept.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();
    try {
      await ApiService.generateWardrobe(widget.character['id'].toString(), concept.trim());
      _outfitController.clear();
      await _loadWardrobe();
      if (widget.onEquipped != null) widget.onEquipped!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Haute couture "$concept" styled and equipped!'), backgroundColor: Colors.purple[800]),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _equipOutfit(String id) async {
    try {
      await ApiService.equipWardrobe(widget.character['id'].toString(), id, setAsAvatar: true);
      await _loadWardrobe();
      if (widget.onEquipped != null) widget.onEquipped!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attire equipped as active!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.character['name'] ?? 'Character';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.checkroom, color: Colors.purpleAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '$name\'s Wardrobe Closet',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),

              // Active attire badge
              if (_activeWardrobe != null && _activeWardrobe!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Equipped in Story: $_activeWardrobe',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Outfit concept input
              TextField(
                controller: _outfitController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe new outfit (e.g., Midnight Masquerade)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                    onPressed: _isGenerating ? null : () => _generateOutfit(_outfitController.text),
                  ),
                ),
                onSubmitted: (val) => _generateOutfit(val),
              ),
              const SizedBox(height: 8),

              // Quick preset chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presetOutfits.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        label: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        onPressed: _isGenerating ? null : () => _generateOutfit(p),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              if (_isGenerating)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: Colors.purpleAccent),
                        const SizedBox(height: 10),
                        Text('Designing haute couture and rendering portrait for $name...', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // Outfits list
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_outfits.isEmpty && !_isGenerating)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No custom outfits in closet yet.', style: TextStyle(color: Colors.white54))),
                )
              else
                ..._outfits.map((outfit) {
                  final b64 = outfit['image_base64'] as String?;
                  final id = outfit['id']?.toString() ?? '';
                  final isEquipped = _activeWardrobe != null && _activeWardrobe!.contains(outfit['name'] ?? '');

                  return Card(
                    color: Colors.white.withValues(alpha: 0.04),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: b64 != null && b64.isNotEmpty ? MemoryImage(base64Decode(b64)) : null,
                        child: b64 == null ? const Icon(Icons.checkroom, color: Colors.white) : null,
                      ),
                      title: Text(
                        outfit['name'] ?? outfit['concept'] ?? 'Outfit',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        outfit['fabric_and_cut'] ?? outfit['accessories'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped ? Colors.amber : Colors.purple[800],
                          foregroundColor: isEquipped ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isEquipped ? null : () => _equipOutfit(id),
                        child: Text(isEquipped ? 'Equipped' : 'Equip', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 6. NARRATIVE TIMELINE & SYNCHRONIZED MEMORIES
// ==========================================
class NarrativeTimelineSheet extends StatefulWidget {
  final String storyId;

  const NarrativeTimelineSheet({super.key, required this.storyId});

  static void show(BuildContext context, String storyId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => NarrativeTimelineSheet(storyId: storyId),
    );
  }

  @override
  State<NarrativeTimelineSheet> createState() => _NarrativeTimelineSheetState();
}

class _NarrativeTimelineSheetState extends State<NarrativeTimelineSheet> {
  List<dynamic> _memories = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final list = await ApiService.getStoryNarrativeMemories(widget.storyId);
      if (mounted) {
        setState(() {
          _memories = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncMemories() async {
    setState(() => _isSyncing = true);
    try {
      final res = await ApiService.syncStoryChronicle(widget.storyId);
      await _loadMemories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Synchronized ${res['synced_chapters'] ?? 0} chapters & ${res['total_memories'] ?? 0} memory milestones!'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error syncing memories: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.link, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Living Story Timeline & Memories',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                          )
                        : const Icon(Icons.sync, color: Colors.blueAccent),
                    tooltip: 'Synchronize Living Memory',
                    onPressed: _isSyncing ? null : _syncMemories,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const Text(
                '🔗 All key moments from 1-on-1 Chats, Tavern Chats, and Prophecies automatically synchronize here and steer upcoming chapters.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_memories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No timeline memories yet. Chat with characters or in the tavern to generate live memories!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                )
              else
                ..._memories.map((m) {
                  final source = m['source']?.toString().toUpperCase() ?? 'EVENT';
                  final charName = m['character_name'] ?? 'Characters';
                  final summary = m['event_summary'] ?? '';
                  final impact = m['emotional_impact'] ?? '';

                  return Card(
                    color: Colors.white.withValues(alpha: 0.04),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(source, style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(charName, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(summary, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35)),
                          if (impact.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Tone: $impact', style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}


// ==========================================
// 7. 24-HOUR CHARACTER LIVE ROUTINE & CHECK-INS
// ==========================================
class LiveRoutineSheet extends StatefulWidget {
  final Map<String, dynamic> character;
  final VoidCallback? onInteraction;

  const LiveRoutineSheet({super.key, required this.character, this.onInteraction});

  static void show(BuildContext context, Map<String, dynamic> character, {VoidCallback? onInteraction}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF110E1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => LiveRoutineSheet(character: character, onInteraction: onInteraction),
    );
  }

  @override
  State<LiveRoutineSheet> createState() => _LiveRoutineSheetState();
}

class _LiveRoutineSheetState extends State<LiveRoutineSheet> {
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _routine;
  Map<String, dynamic>? _distractionResult;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutine({bool force = false}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getCharacterLiveRoutine(
        widget.character['id'].toString(),
        forceRefresh: force,
      );
      if (mounted) {
        setState(() {
          _routine = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading routine: $e')));
      }
    }
  }

  Future<void> _sendDistraction(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _routine == null) return;
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();
    try {
      final res = await ApiService.distractCharacterRoutine(
        widget.character['id'].toString(),
        message: msg,
        currentActivity: _routine!['current_activity'],
        location: _routine!['location'],
        innerThought: _routine!['inner_thought'],
      );
      if (mounted) {
        setState(() {
          _distractionResult = res;
          _isSending = false;
        });
        _msgController.clear();
        if (widget.onInteraction != null) widget.onInteraction!();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.character['name'] ?? 'Character';
    final avatar = widget.character['avatar_base64'];

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.purple.withValues(alpha: 0.3),
                    backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                        ? (avatar.toString().startsWith('http')
                            ? NetworkImage(avatar.toString())
                            : MemoryImage(base64Decode(avatar.toString()))) as ImageProvider
                        : null,
                    child: (avatar == null || avatar.toString().isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$name's Live Routine",
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Ambient Life Sim • Active Now',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.amberAccent),
                    tooltip: 'Refresh Routine',
                    onPressed: _isLoading ? null : () => _loadRoutine(force: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_routine != null) ...[
                // Time & Location Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withValues(alpha: 0.18),
                        Colors.blue.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_routine!['status_emoji'] ?? '🌙', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(
                            '${_routine!['time_label'] ?? ''} • ${_routine!['time_period'] ?? ''}',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _routine!['mood'] ?? 'Brooding',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.pinkAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _routine!['location'] ?? 'Private Quarters',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _routine!['current_activity'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Secret Inner Thought
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology, size: 16, color: Colors.purpleAccent),
                          SizedBox(width: 6),
                          Text(
                            'Private Inner Thought',
                            style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${_routine!['inner_thought'] ?? ''}"',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Distraction Result (if just sent)
                if (_distractionResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal[900]?.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on, color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Interruption Caught Him Off-Guard!',
                              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              '+${_distractionResult!['intimacy_delta'] ?? 2} Intimacy',
                              style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        if (_distractionResult!['heart_rate_spike'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _distractionResult!['heart_rate_spike'].toString(),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        const Divider(color: Colors.white12, height: 16),
                        Text(
                          _distractionResult!['reaction'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              GoRouter.of(context).push('/character_chat', extra: {
                                'characterId': widget.character['id'],
                                'characterName': widget.character['name'] ?? 'Character',
                                'backgroundImage': widget.character['avatar_base64'],
                              });
                            },
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('Continue Chat with Him'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Interrupt him section
                const Text(
                  '⚡ Interrupt His Routine',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Send a spontaneous whisper right now. He will be startled in the middle of his activity and react immediately.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 10),

                // Quick suggestions chips
                if (_routine!['distraction_prompt_suggestion'] != null) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.touch_app, size: 14, color: Colors.amber),
                        label: Text(
                          _routine!['distraction_prompt_suggestion'],
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onPressed: () {
                          _msgController.text = _routine!['distraction_prompt_suggestion'];
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.nightlight, size: 14, color: Colors.purpleAccent),
                        label: const Text('Can\'t sleep either?', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onPressed: () => _msgController.text = "Can't sleep either?",
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.favorite, size: 14, color: Colors.pinkAccent),
                        label: const Text('Thinking of you...', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onPressed: () => _msgController.text = "Thinking of you...",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Input box
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Whisper a distraction to him...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.purpleAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSending ? null : () => _sendDistraction(_msgController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
