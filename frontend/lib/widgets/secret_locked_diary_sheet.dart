import 'package:flutter/material.dart';
import '../api.dart';

class SecretLockedDiarySheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final int intimacyScore;
  final String? avatarBase64;

  const SecretLockedDiarySheet({
    super.key,
    required this.characterId,
    required this.characterName,
    required this.intimacyScore,
    this.avatarBase64,
  });

  static Future<void> show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    required int intimacyScore,
    String? avatarBase64,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => SecretLockedDiarySheet(
        characterId: characterId,
        characterName: characterName,
        intimacyScore: intimacyScore,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<SecretLockedDiarySheet> createState() => _SecretLockedDiarySheetState();
}

class _SecretLockedDiarySheetState extends State<SecretLockedDiarySheet> {
  bool _isLoading = true;
  bool _isGenerating = false;
  List<dynamic> _entries = [];
  String? _errorMessage;
  int _currentIntimacy = 0;

  @override
  void initState() {
    super.initState();
    _currentIntimacy = widget.intimacyScore;
    _loadDiary();
  }

  Future<void> _loadDiary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ApiService.getCharacterDiary(widget.characterId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _entries = items;
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

  Future<void> _generateNewEntry() async {
    setState(() => _isGenerating = true);
    try {
      final newEntry = await ApiService.generateCharacterDiary(widget.characterId);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _entries.insert(0, newEntry);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF78350F),
            content: Row(
              children: [
                const Icon(Icons.book, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('📖 ${widget.characterName} secretly wrote a new diary entry!'),
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
          SnackBar(content: Text('Could not write entry right now: $e')),
        );
      }
    }
  }

  Future<void> _unlockEntry(dynamic entry) async {
    final entryId = entry['id'] as String;
    try {
      final res = await ApiService.unlockDiaryEntry(entryId);
      if (res['success'] == true) {
        setState(() {
          entry['is_unlocked'] = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal.shade800,
              content: Text(res['message'] ?? 'Brass lock unlatched!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(res['message'] ?? 'Requires higher intimacy to unlock.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlock error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1613),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, -6)),
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
                color: Colors.amber.withValues(alpha: 0.3),
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
                      colors: [Color(0xFF92400E), Color(0xFFB45309)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.characterName}\'s Secret Locked Diary',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Your Intimacy: $_currentIntimacy/100',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                          ),
                        ],
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
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _entries.isEmpty
                        ? _buildEmptyState()
                        : _buildDiaryPagesList(),
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
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_clock, color: Colors.amber, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'No Secret Pages Written Yet',
              style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.characterName} hasn\'t poured her late-night secrets onto these pages yet. Tap below to have her secretly write her private thoughts after your recent chats!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateNewEntry,
              icon: _isGenerating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.create, size: 18),
              label: const Text('Write Secret Reflection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
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
            Text(_errorMessage ?? 'Failed to load diary', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadDiary,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryPagesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _entries.length,
      itemBuilder: (context, idx) {
        final entry = _entries[idx];
        final bool isUnlocked = entry['is_unlocked'] == true || _currentIntimacy >= (entry['required_intimacy'] ?? 20);
        final title = entry['title'] ?? 'Secret Thoughts';
        final date = entry['entry_date'] ?? 'Late Night';
        final emoji = entry['mood_emoji'] ?? '🥺';
        final rawContent = entry['raw_content'] ?? '';
        final reqIntimacy = entry['required_intimacy'] ?? 20;
        final secretLevel = entry['secret_level'] ?? 'crush';
        final doodleType = entry['doodle_type'] ?? 'heart';

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF261D18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked ? const Color(0xFFD97706).withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Diary Page Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1713),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.green.withValues(alpha: 0.18) : Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUnlocked ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                            size: 11,
                            color: isUnlocked ? Colors.greenAccent : Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUnlocked ? 'UNLOCKED' : 'LOCK: $reqIntimacy INT',
                            style: TextStyle(
                              color: isUnlocked ? Colors.greenAccent : Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Page Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: isUnlocked
                    ? _buildUnlockedParchment(rawContent, secretLevel, doodleType)
                    : _buildLockedTeaser(entry, rawContent, reqIntimacy),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnlockedParchment(String rawContent, String secretLevel, String doodleType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Secret level badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Confession Tier: ${secretLevel.toUpperCase()}',
                style: const TextStyle(color: Color(0xFFF472B6), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Text(
              _getDoodleIcon(doodleType),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Handwritten Text with Strikethroughs
        SelectableText.rich(
          TextSpan(
            children: _buildHandwrittenSpans(rawContent),
          ),
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: Color(0xFFFEF3C7),
            fontFamily: 'serif',
          ),
        ),

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '— ${widget.characterName} (private thoughts)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLockedTeaser(dynamic entry, String rawContent, int reqIntimacy) {
    // Generate partially blurred preview text
    final previewWords = rawContent.split(' ').take(8).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$previewWords... ~███████████████████~',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock, color: Colors.amber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Locked with Brass Latch',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Requires Intimacy $reqIntimacy (Your level: $_currentIntimacy/100)',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _unlockEntry(entry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                child: const Text('Pick Lock'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildHandwrittenSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'~([^~]+)~');
    int lastEnd = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // Crossed out text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.redAccent.shade200,
          decorationThickness: 2.0,
          color: Colors.white.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  String _getDoodleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'rose':
        return '🌹';
      case 'cloud':
        return '🌧️';
      case 'coffee':
        return '☕';
      case 'stars':
        return '✨';
      case 'heart':
      default:
        return '💌';
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF140F0D),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateNewEntry,
            icon: _isGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.create, size: 18),
            label: Text(_isGenerating ? 'Writing Secret Thoughts...' : '✍️ Write Secret Entry (AI Reflection)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFFB45309),
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
