import 'package:flutter/material.dart';
import '../api.dart';
import '../services/character_voice_service.dart';
import '../services/notification_service.dart';

class CharacterVoiceSettingsSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const CharacterVoiceSettingsSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.avatarBase64,
  });

  static Future<void> show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? avatarBase64,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CharacterVoiceSettingsSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<CharacterVoiceSettingsSheet> createState() => _CharacterVoiceSettingsSheetState();
}

class _CharacterVoiceSettingsSheetState extends State<CharacterVoiceSettingsSheet> {
  final CharacterVoiceService _voiceService = CharacterVoiceService();
  List<dynamic> _voices = [];
  bool _isLoadingVoices = true;
  String _selectedVoiceId = 'en-US-JennyNeural';
  bool _isTestingPing = false;
  String? _previewingVoiceId;

  @override
  void initState() {
    super.initState();
    _selectedVoiceId = _voiceService.preferredVoice;
    _loadVoices();
    _voiceService.addListener(_onVoiceServiceUpdate);
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceServiceUpdate);
    super.dispose();
  }

  void _onVoiceServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadVoices() async {
    try {
      final list = await ApiService.getAvailableVoices();
      if (mounted) {
        setState(() {
          _voices = list;
          _isLoadingVoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVoices = false);
      }
    }
  }

  Future<void> _selectVoice(String voiceId) async {
    setState(() => _selectedVoiceId = voiceId);
    await _voiceService.setPreferredVoice(voiceId);
    try {
      await ApiService.setCharacterVoice(widget.characterId, voiceId);
    } catch (e) {
      debugPrint('Failed to save voice to backend: $e');
    }
  }

  Future<void> _previewVoice(String voiceId) async {
    setState(() => _previewingVoiceId = voiceId);
    await _voiceService.playDialogue(
      characterId: widget.characterId,
      text: "Hey... I was just sitting here hoping you'd come talk to me today.",
      messageId: 'preview_$voiceId',
      voiceId: voiceId,
    );
    if (mounted) {
      setState(() => _previewingVoiceId = null);
    }
  }

  Future<void> _triggerTestPing() async {
    setState(() => _isTestingPing = true);
    try {
      final ping = await ApiService.getProactiveNotification(
        widget.characterId,
        localTimeStr: 'Afternoon',
      );

      await NotificationService().showCharacterPing(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: ping['notification_title'] ?? '${widget.characterName} ❤️',
        body: ping['notification_body'] ?? 'Thinking about you right now...',
        subtext: ping['subtext'] ?? '1-on-1 Whisper',
        payloadData: {
          'character_id': widget.characterId,
          'character_name': widget.characterName,
          'avatar_base64': widget.avatarBase64,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('📱 Spontaneous ping sent to your phone lock screen! Check notifications.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to trigger ping: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingPing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
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
                    color: Colors.pink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.record_voice_over, color: Colors.pinkAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice & Spontaneous Whispers',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Configure ${widget.characterName}\'s neural voice & lock screen pings',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
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

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Auto-Voice Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _voiceService.autoVoiceEnabled ? Colors.pinkAccent.withOpacity(0.4) : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _voiceService.autoVoiceEnabled ? Colors.pinkAccent.withOpacity(0.2) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _voiceService.autoVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                          color: _voiceService.autoVoiceEnabled ? Colors.pinkAccent : Colors.white54,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Speak AI Replies',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Automatically speak ${widget.characterName}\'s replies aloud as soon as they arrive.',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _voiceService.autoVoiceEnabled,
                        activeColor: Colors.pinkAccent,
                        onChanged: (val) => _voiceService.setAutoVoice(val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Spontaneous Lock Screen Ping Trigger
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.15),
                        const Color(0xFFEC4899).withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.purpleAccent, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '📱 Lock Screen Whispers',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'When you lock your phone or leave the app, ${widget.characterName} will spontaneously ping your phone lock screen like a real person thinking about you.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isTestingPing ? null : _triggerTestPing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isTestingPing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_to_mobile, size: 18),
                          label: Text(_isTestingPing ? 'Sending Ping...' : 'Test Lock Screen Ping Now'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Voice Selection Catalog
                const Text(
                  '🎙️ Select Neural Spoken Voice',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'High-fidelity neural voices with realistic breathing and emotional intonation:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),

                if (_isLoadingVoices)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Colors.pinkAccent),
                    ),
                  )
                else
                  ..._voices.map((v) {
                    final voiceId = v['voice_id'] as String;
                    final isSelected = _selectedVoiceId == voiceId;
                    final isPreviewing = _previewingVoiceId == voiceId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.pinkAccent.withOpacity(0.12) : const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? Colors.pinkAccent : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _selectVoice(voiceId),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Colors.pinkAccent : Colors.white12,
                          child: Icon(
                            v['gender'] == 'Female' ? Icons.face : Icons.face_6,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              v['name'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.pinkAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v['locale'] as String,
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v['style'] as String,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'Best for: ${v['recommended_roles']}',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isPreviewing ? Icons.stop_circle : Icons.play_circle_fill,
                            color: isSelected ? Colors.pinkAccent : Colors.white70,
                            size: 28,
                          ),
                          tooltip: 'Preview Voice',
                          onPressed: () => _previewVoice(voiceId),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

