import 'package:flutter/material.dart';
import '../services/audiobook_service.dart';

class AudiobookPlayerScreen extends StatefulWidget {
  const AudiobookPlayerScreen({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AudiobookPlayerScreen(),
    );
  }

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen> {
  final AudiobookService _service = AudiobookService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _service.currentChapter;
    final title = chapter?['title'] ?? 'No Chapter Playing';
    final storyTitle = _service.storyTitle ?? 'Audiobook Player';
    final coverUrl = _service.storyCoverUrl;
    final isPlaying = _service.isPlaying;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  storyTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent),
                ),
              ),
              PopupMenuButton<int?>(
                icon: Icon(
                  Icons.bedtime,
                  color: _service.sleepTimerMinutes != null ? Colors.amber : Colors.white70,
                ),
                tooltip: 'Sleep Timer',
                onSelected: (mins) {
                  _service.setSleepTimer(mins);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(mins == null ? 'Sleep Timer Off' : 'Sleep Timer set to $mins mins')),
                  );
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: null, child: Text('Timer Off')),
                  const PopupMenuItem(value: 15, child: Text('15 Minutes')),
                  const PopupMenuItem(value: 30, child: Text('30 Minutes')),
                  const PopupMenuItem(value: 45, child: Text('45 Minutes')),
                  const PopupMenuItem(value: 60, child: Text('60 Minutes')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Cover Art / Visual
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.25),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (coverUrl != null && coverUrl.isNotEmpty)
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildCoverFallback(),
                        )
                      : _buildCoverFallback(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Chapter Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Track ${_service.currentIndex + 1} of ${_service.playlist.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (_service.sleepTimerMinutes != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  'Sleep timer: ${_service.remainingSleepTime?.inMinutes ?? _service.sleepTimerMinutes}m remaining',
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _service.hasTrack ? () => _service.previousChapter() : null,
              ),
              const SizedBox(width: 20),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                ),
                child: IconButton(
                  iconSize: 44,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                  ),
                  onPressed: _service.hasTrack ? () => _service.togglePlayPause() : null,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: _service.hasTrack ? () => _service.nextChapter() : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Speed chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [0.3, 0.5, 0.8, 1.0].map((s) {
              final isSel = (_service.speed - s).abs() < 0.05;
              final label = s == 0.3 ? '0.7x' : s == 0.5 ? '1.0x' : s == 0.8 ? '1.2x' : '1.5x';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(label, style: TextStyle(fontSize: 11, color: isSel ? Colors.black : Colors.white70)),
                  selected: isSel,
                  selectedColor: Colors.amber,
                  backgroundColor: Colors.white10,
                  onSelected: (sel) {
                    if (sel) _service.setSpeed(s);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Chapter playlist expansion
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _service.playlist.length,
                itemBuilder: (ctx, i) {
                  final ch = _service.playlist[i];
                  final isCurrent = i == _service.currentIndex;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isCurrent ? Icons.volume_up : Icons.bookmark_border,
                      color: isCurrent ? Colors.amber : Colors.white38,
                    ),
                    title: Text(
                      ch['title'] ?? 'Chapter ${ch['chapter_number']}',
                      style: TextStyle(
                        color: isCurrent ? Colors.amber : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      _service.startPlaylist(_service.playlist, i, storyTitle: _service.storyTitle, coverUrl: _service.storyCoverUrl);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      color: const Color(0xFF222233),
      child: const Center(
        child: Icon(Icons.headphones, size: 70, color: Colors.amber),
      ),
    );
  }
}
