import 'package:flutter/material.dart';
import '../api.dart';

class PreviouslyOnSheet extends StatefulWidget {
  final String storyId;
  final String storyTitle;

  const PreviouslyOnSheet({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  static Future<void> show(BuildContext context, {required String storyId, required String storyTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PreviouslyOnSheet(storyId: storyId, storyTitle: storyTitle),
    );
  }

  @override
  State<PreviouslyOnSheet> createState() => _PreviouslyOnSheetState();
}

class _PreviouslyOnSheetState extends State<PreviouslyOnSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recapData;

  @override
  void initState() {
    super.initState();
    _fetchRecap();
  }

  Future<void> _fetchRecap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getStoryPreviouslyOnRecap(widget.storyId);
      if (data != null) {
        setState(() {
          _recapData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unable to load story recap right now.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading recap: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141322) : Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              // Sheet Grabber handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.deepOrangeAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.35),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: const Icon(Icons.movie_filter_rounded, color: Colors.black, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'PREVIOUSLY ON...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                  color: Colors.amberAccent.shade200,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 0.8),
                                ),
                                child: const Text(
                                  '0 Credits • Instant',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _recapData?['story_title'] ?? widget.storyTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.amberAccent),
                            SizedBox(height: 16),
                            Text(
                              'Assembling your story recap...',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                  const SizedBox(height: 12),
                                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _fetchRecap,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildRecapContent(scrollController),
              ),

              // Bottom Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF100F1C) : Colors.white,
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
                      label: const Text(
                        'Continue Story',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecapContent(ScrollController controller) {
    final currentStatus = _recapData?['current_status'] ?? '';
    final keyRevelations = (_recapData?['key_revelations'] as List<dynamic>? ?? []);
    final recapCards = (_recapData?['recap_cards'] as List<dynamic>? ?? []);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // "Where You Left Off" hero banner
        if (currentStatus.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade900.withValues(alpha: 0.3),
                  Colors.purple.shade900.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bookmark_added_rounded, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WHERE YOU LEFT OFF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Key Revelations & Unresolved Lore (if any)
        if (keyRevelations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.purpleAccent),
                const SizedBox(width: 6),
                Text(
                  'CANON MEMORIES & REVELATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.purpleAccent.shade100,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: keyRevelations.map((rev) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✦ ', style: TextStyle(color: Colors.purpleAccent, fontSize: 13)),
                      Expanded(
                        child: Text(
                          rev.toString(),
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // The Timeline Journey
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 16, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                'THE CHRONOLOGICAL STORY LINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.cyanAccent.shade100,
                ),
              ),
            ],
          ),
        ),

        if (recapCards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No chapters or conversations have been recorded yet.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          )
        else
          ...recapCards.asMap().entries.map((entry) {
            final idx = entry.key;
            final card = entry.value;
            final isLast = idx == recapCards.length - 1;
            return _buildTimelineNode(card, isLast: isLast);
          }),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTimelineNode(Map<String, dynamic> card, {required bool isLast}) {
    final isChapter = card['type'] == 'chapter';
    final title = card['title'] ?? (isChapter ? 'Chapter' : 'Conversations');
    final summary = card['summary'] ?? '';
    final badge = card['badge'] ?? '';
    final exchanges = (card['sample_exchanges'] as List<dynamic>? ?? []);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail with icon and line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isChapter ? Colors.deepPurple.shade800 : const Color(0xFF1B3B4B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isChapter ? Colors.purpleAccent : Colors.cyanAccent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isChapter ? Icons.menu_book_rounded : Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Right Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isChapter ? const Color(0xFF1E1C2E) : const Color(0xFF17242F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChapter
                      ? Colors.purpleAccent.withValues(alpha: 0.25)
                      : Colors.cyanAccent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isChapter ? Colors.purple : Colors.cyan).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: isChapter ? Colors.purpleAccent : Colors.cyanAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                  if (!isChapter && exchanges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: exchanges.map((ex) {
                          final speaker = ex['speaker'] ?? 'Character';
                          final text = ex['text'] ?? '';
                          final isAi = ex['is_ai'] == true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                children: [
                                  TextSpan(
                                    text: '$speaker: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isAi ? Colors.cyanAccent : Colors.amberAccent,
                                    ),
                                  ),
                                  TextSpan(text: text),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
