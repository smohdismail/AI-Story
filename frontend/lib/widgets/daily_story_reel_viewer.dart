import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class DailyStoryReelViewer extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;
  final String storyId;
  final VoidCallback onRefresh;

  const DailyStoryReelViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.storyId,
    required this.onRefresh,
  });

  static void show(
    BuildContext context, {
    required List<dynamic> stories,
    int initialIndex = 0,
    required String storyId,
    required VoidCallback onRefresh,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DailyStory',
      pageBuilder: (c, _, __) => DailyStoryReelViewer(
        stories: stories,
        initialIndex: initialIndex,
        storyId: storyId,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<DailyStoryReelViewer> createState() => _DailyStoryReelViewerState();
}

class _DailyStoryReelViewerState extends State<DailyStoryReelViewer> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  bool _isSendingReply = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  Future<void> _sendReply(String emoji, [String? text]) async {
    final story = widget.stories[_currentIndex];
    final replyMsg = text ?? _replyController.text.trim();
    if (replyMsg.isEmpty && emoji.isEmpty) return;

    setState(() => _isSendingReply = true);
    _progressController.stop();

    try {
      await ApiService.replyToDailyStory(
        story['id'],
        replyText: replyMsg.isNotEmpty ? replyMsg : 'Sent a reaction',
        reactionEmoji: emoji,
      );
      _replyController.clear();
      setState(() => _isSendingReply = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${story['character_name']}! She will remember this in chat.'),
            backgroundColor: Colors.purple.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _progressController.forward();
    } catch (e) {
      setState(() => _isSendingReply = false);
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No active stories right now.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
            ],
          ),
        ),
      );
    }

    final currentStory = widget.stories[_currentIndex];
    final avatar = currentStory['character_avatar'];
    final charName = currentStory['character_name'] ?? 'Character';
    final statusText = currentStory['status_text'] ?? '';
    final imageUrl = currentStory['image_url'] ?? '';
    final musicMood = currentStory['music_mood'] ?? 'Acoustic Melody';
    final timePeriod = (currentStory['time_period'] ?? 'Today').toString().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) {
          setState(() => _isPaused = true);
          _progressController.stop();
        },
        onLongPressEnd: (_) {
          setState(() => _isPaused = false);
          _progressController.forward();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background image
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1B1626),
                child: const Center(child: Icon(Icons.image, size: 80, color: Colors.white24)),
              ),
            ),

            // 2. Vignette Gradients
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),

            // 3. Tap areas for left / right navigation
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _previousStory,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _nextStory,
                  ),
                ),
              ],
            ),

            // 4. Content Overlay
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bars row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    child: Row(
                      children: List.generate(widget.stories.length, (idx) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
                            child: idx < _currentIndex
                                ? Container(color: Colors.white)
                                : idx == _currentIndex
                                    ? AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (c, _) => LinearProgressIndicator(
                                          value: _progressController.value,
                                          backgroundColor: Colors.white24,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          minHeight: 3,
                                        ),
                                      )
                                    : Container(color: Colors.white24),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Header with avatar, name, and time
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.purpleAccent, Colors.pinkAccent, Colors.amberAccent],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.purple[900],
                            backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                ? (avatar.toString().startsWith('http')
                                    ? NetworkImage(avatar.toString())
                                    : MemoryImage(base64Decode(avatar.toString()))) as ImageProvider
                                : null,
                            child: (avatar == null || avatar.toString().isEmpty)
                                ? const Icon(Icons.person, color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                charName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                '• $timePeriod STATUS REEL',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Music / Mood badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note, color: Colors.amberAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            musicMood,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Story caption text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Quick Reply & Reactions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        // Quick Emoji Reactions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['❤️', '🔥', '😍', '🥺', '☕', '✨'].map((emoji) {
                            return InkWell(
                              onTap: () => _sendReply(emoji),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 18)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Text input field
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: TextField(
                                  controller: _replyController,
                                  onTap: () {
                                    _progressController.stop();
                                  },
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      _sendReply('💬', val);
                                    }
                                  },
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Send message to $charName...',
                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                if (_replyController.text.trim().isNotEmpty) {
                                  _sendReply('💬', _replyController.text.trim());
                                }
                              },
                              icon: const Icon(Icons.send, size: 16),
                              style: IconButton.styleFrom(backgroundColor: Colors.purpleAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
