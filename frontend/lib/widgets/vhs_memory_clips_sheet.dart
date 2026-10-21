import 'package:flutter/material.dart';
import '../api.dart';

class VhsMemoryClipsSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const VhsMemoryClipsSheet({
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
      builder: (c) => VhsMemoryClipsSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<VhsMemoryClipsSheet> createState() => _VhsMemoryClipsSheetState();
}

class _VhsMemoryClipsSheetState extends State<VhsMemoryClipsSheet> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRecording = false;
  List<dynamic> _clips = [];
  late AnimationController _recBlinkController;

  @override
  void initState() {
    super.initState();
    _recBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadClips();
  }

  @override
  void dispose() {
    _recBlinkController.dispose();
    super.dispose();
  }

  Future<void> _loadClips() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getVhsClips(widget.characterId);
      setState(() {
        _clips = res;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordNewClip() async {
    setState(() => _isRecording = true);
    try {
      final newClip = await ApiService.generateVhsClip(
        widget.characterId,
        clipTheme: 'candid unforgettable memory with laughter and intimate whispers',
      );
      setState(() {
        _clips.insert(0, newClip);
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📹 New VHS tape recorded with ${widget.characterName}!'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording clip: $e')),
        );
      }
    }
  }

  void _playClip(Map<String, dynamic> clip) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0B14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: -5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.black45,
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _recBlinkController,
                      builder: (c, _) => Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _recBlinkController.value > 0.5 ? Colors.redAccent : Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '● REC',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text('SP  PLAY 0:00:24', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    const Icon(Icons.battery_4_bar, color: Colors.greenAccent, size: 16),
                  ],
                ),
              ),

              // Image with Scanlines simulation
              Stack(
                children: [
                  Image.network(
                    clip['image_url'] ?? '',
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 280,
                      color: Colors.black54,
                      child: const Center(child: Icon(Icons.videocam_off, size: 50, color: Colors.white30)),
                    ),
                  ),
                  // CRT Scanline gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Timestamp badge on bottom-right of video
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      color: Colors.black87,
                      child: Text(
                        clip['date_stamp'] ?? 'OCT 21, 2026',
                        style: const TextStyle(color: Color(0xFF00FF66), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              // Tape Details
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip['clip_title'] ?? 'Candid Camcorder Memory',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.graphic_eq, color: Colors.amberAccent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          clip['ambient_sound'] ?? 'Tape Whir & Gentle Rain',
                          style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      clip['narrative_moment'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              clip['whisper_quote'] ?? '',
                              style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14.0, bottom: 10.0),
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.eject, color: Colors.white70, size: 16),
                    label: const Text('Eject Tape', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF13101C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.redAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.characterName}'s VHS Camcorder Vault 📹",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Living nostalgic clips caught on vintage magnetic tape",
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecording ? null : _recordNewClip,
                  icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
                  label: const Text('Record Tape', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B101D),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.redAccent, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha: 0.15),
              child: const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)),
                  SizedBox(width: 12),
                  Text(
                    "Rolling analog tape... capturing a candid memory...",
                    style: TextStyle(fontSize: 12, color: Colors.redAccent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.movie_creation_outlined, size: 50, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "No VHS tapes recorded with ${widget.characterName} yet.",
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _recordNewClip,
                              icon: const Icon(Icons.videocam, size: 16),
                              label: const Text('Record First VHS Tape'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _clips.length,
                        itemBuilder: (context, index) {
                          final clip = _clips[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: const Color(0xFF1D182A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                            ),
                            child: InkWell(
                              onTap: () => _playClip(clip),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            clip['image_url'] ?? '',
                                            width: 80,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 80,
                                              height: 60,
                                              color: Colors.black26,
                                              child: const Icon(Icons.broken_image, size: 20, color: Colors.white24),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            clip['clip_title'] ?? 'Tape',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            clip['date_stamp'] ?? '',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF00FF66), fontFamily: 'monospace'),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            clip['whisper_quote'] ?? '',
                                            style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.white38),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
