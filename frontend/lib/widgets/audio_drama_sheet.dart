import 'package:flutter/material.dart';
import '../services/audio_drama_service.dart';

class AudioDramaSheet extends StatefulWidget {
  final String rawContent;
  final String chapterTitle;
  final int? chapterNumber;
  final String? storyTitle;
  final String? coverUrl;
  final List<dynamic>? characters;

  const AudioDramaSheet({
    super.key,
    required this.rawContent,
    required this.chapterTitle,
    this.chapterNumber,
    this.storyTitle,
    this.coverUrl,
    this.characters,
  });

  static void show(
    BuildContext context, {
    required String rawContent,
    required String chapterTitle,
    int? chapterNumber,
    String? storyTitle,
    String? coverUrl,
    List<dynamic>? characters,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AudioDramaSheet(
        rawContent: rawContent,
        chapterTitle: chapterTitle,
        chapterNumber: chapterNumber,
        storyTitle: storyTitle,
        coverUrl: coverUrl,
        characters: characters,
      ),
    );
  }

  @override
  State<AudioDramaSheet> createState() => _AudioDramaSheetState();
}

class _AudioDramaSheetState extends State<AudioDramaSheet> with SingleTickerProviderStateMixin {
  final AudioDramaService _drama = AudioDramaService.instance;
  late AnimationController _waveController;

  final List<Map<String, String>> _bgmPresets = [
    {'id': 'piano', 'label': 'Midnight Piano', 'icon': '🎹'},
    {'id': 'strings', 'label': 'Cinematic Strings', 'icon': '🎻'},
    {'id': 'jazz', 'label': 'Sultry Jazz', 'icon': '🎷'},
    {'id': 'rain', 'label': 'Rain & Thunder', 'icon': '🌧️'},
    {'id': 'none', 'label': 'No Music', 'icon': '🔇'},
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _drama.addListener(_onDramaUpdate);

    // Auto-start drama if not already playing this chapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_drama.isPlaying) {
        _startDrama();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _drama.removeListener(_onDramaUpdate);
    super.dispose();
  }

  void _onDramaUpdate() {
    if (mounted) setState(() {});
  }

  void _startDrama() {
    _drama.startDrama(
      rawContent: widget.rawContent,
      chapterTitle: widget.chapterTitle,
      chapterNumber: widget.chapterNumber,
      storyTitle: widget.storyTitle,
      coverUrl: widget.coverUrl,
      characters: widget.characters,
      bgm: _drama.currentBgmId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLine = _drama.currentLine;
    final totalLines = _drama.scriptLines.length;
    final currentIndex = _drama.currentLineIndex;
    final progress = totalLines > 0 ? (currentIndex + 1) / totalLines : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
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
                  child: const Icon(Icons.theater_comedy, color: Colors.purpleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'CINEMATIC AUDIO DRAMA',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            totalLines > 0 ? 'Cue ${currentIndex + 1}/$totalLines' : '',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.chapterTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.storyTitle != null)
                        Text(
                          widget.storyTitle!,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 12),

          // Cast Voice Badges Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVoicePill(
                  icon: Icons.record_voice_over,
                  label: 'Narrator',
                  isActive: currentLine?.role == DramaRole.narrator,
                  activeColor: Colors.amberAccent,
                ),
                _buildVoicePill(
                  icon: Icons.male,
                  label: 'Baritone Lead',
                  isActive: currentLine?.role == DramaRole.maleLead,
                  activeColor: const Color(0xFFFF5252),
                ),
                _buildVoicePill(
                  icon: Icons.female,
                  label: 'Female Lead',
                  isActive: currentLine?.role == DramaRole.femaleLead,
                  activeColor: Colors.pinkAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Script Teleprompter Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getSpeakerBorderColor(currentLine?.role),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Speaker Tag & Soundwave
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSpeakerBorderColor(currentLine?.role).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentLine?.speakerName ?? 'Narrator',
                          style: TextStyle(
                            color: _getSpeakerBorderColor(currentLine?.role),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Animated soundwave bars
                      if (_drama.isPlaying && !_drama.isPaused)
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) {
                            return Row(
                              children: List.generate(5, (index) {
                                final height = 8.0 + (index * 3 * _waveController.value);
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  width: 3,
                                  height: height.clamp(4.0, 20.0),
                                  decoration: BoxDecoration(
                                    color: _getSpeakerBorderColor(currentLine?.role),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Current Dialogue / Narration Text
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          currentLine?.text ?? (totalLines == 0 ? 'Parsing chapter script...' : 'Tap Play to start drama'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: currentLine?.role == DramaRole.narrator ? 15 : 17,
                            height: 1.5,
                            fontWeight: currentLine?.role == DramaRole.narrator ? FontWeight.normal : FontWeight.w600,
                            fontStyle: currentLine?.role == DramaRole.narrator ? FontStyle.italic : FontStyle.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getSpeakerBorderColor(currentLine?.role),
                ),
                minHeight: 4,
              ),
            ),
          ),

          // Ambient Background Score Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.music_note, size: 14, color: Colors.white54),
                    SizedBox(width: 6),
                    Text(
                      'Atmospheric Score (Subtle BGM)',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _bgmPresets.map((bgm) {
                      final isSelected = _drama.currentBgmId == bgm['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${bgm['icon']} ${bgm['label']}'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _drama.setBgm(bgm['id']!);
                            }
                          },
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          selectedColor: Colors.purpleAccent,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Playback Controls Row
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speed control
                PopupMenuButton<double>(
                  initialValue: _drama.speed,
                  tooltip: 'Speech Pace',
                  onSelected: (spd) => _drama.setSpeed(spd),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 0.35, child: Text('0.8x (Slow & Intimate)')),
                    const PopupMenuItem(value: 0.42, child: Text('1.0x (Standard)')),
                    const PopupMenuItem(value: 0.50, child: Text('1.2x (Fast Pace)')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(_drama.speed / 0.42).toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Previous line button
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                  tooltip: 'Previous Line',
                  onPressed: currentIndex > 0 ? () => _drama.previousLine() : null,
                ),

                // Play / Pause main button
                GestureDetector(
                  onTap: () {
                    if (!_drama.isPlaying && !_drama.isPaused) {
                      _startDrama();
                    } else {
                      _drama.togglePlayPause();
                    }
                  },
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _drama.isPlaying && !_drama.isPaused ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),

                // Next line button
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
                  tooltip: 'Next Line',
                  onPressed: currentIndex + 1 < totalLines ? () => _drama.nextLine() : null,
                ),

                // Stop button
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.white60, size: 28),
                  tooltip: 'Stop Drama',
                  onPressed: () => _drama.stop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePill({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? activeColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? activeColor : Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white38,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpeakerBorderColor(DramaRole? role) {
    switch (role) {
      case DramaRole.maleLead:
        return const Color(0xFFFF5252);
      case DramaRole.femaleLead:
        return Colors.pinkAccent;
      case DramaRole.narrator:
      default:
        return Colors.amberAccent;
    }
  }
}
