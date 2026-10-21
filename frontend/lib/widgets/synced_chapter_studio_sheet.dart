import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class SyncedChapterStudioSheet extends StatefulWidget {
  final String storyId;
  final int chapterCount;
  final Function(String prompt)? onPromptSelected;

  const SyncedChapterStudioSheet({
    super.key,
    required this.storyId,
    required this.chapterCount,
    this.onPromptSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String storyId,
    required int chapterCount,
    Function(String prompt)? onPromptSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => SyncedChapterStudioSheet(
        storyId: storyId,
        chapterCount: chapterCount,
        onPromptSelected: onPromptSelected,
      ),
    );
  }

  @override
  State<SyncedChapterStudioSheet> createState() => _SyncedChapterStudioSheetState();
}

class _SyncedChapterStudioSheetState extends State<SyncedChapterStudioSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  String _recentCanonSummary = 'Connecting timeline across chapters, private chats, and group banter...';
  List<dynamic> _prompts = [];
  int _selectedIndex = 0;

  final TextEditingController _promptController = TextEditingController();
  
  // Continuity Audit State
  bool _isAuditing = false;
  bool? _isConsistent;
  List<String> _continuityFlags = [];
  String? _autoAlignedPrompt;

  @override
  void initState() {
    super.initState();
    _fetchPrompts();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrompts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getSyncedChapterPrompts(widget.storyId);
      final rawPrompts = res['prompts'] as List<dynamic>? ?? [];
      final summary = res['recent_canon_summary'] as String? ?? 'Timeline fully synchronized.';

      if (mounted) {
        setState(() {
          _isLoading = false;
          _prompts = rawPrompts;
          _recentCanonSummary = summary;
          if (_prompts.isNotEmpty) {
            _selectedIndex = 0;
            _promptController.text = _prompts[0]['prompt_text'] ?? '';
          }
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

  Future<void> _runContinuityAudit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a prompt before auditing.')),
      );
      return;
    }

    setState(() {
      _isAuditing = true;
      _isConsistent = null;
      _continuityFlags = [];
      _autoAlignedPrompt = null;
    });

    try {
      final res = await ApiService.checkChapterContinuity(widget.storyId, prompt);
      if (mounted) {
        setState(() {
          _isAuditing = false;
          _isConsistent = res['is_consistent'] == true;
          _continuityFlags = (res['flags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          _autoAlignedPrompt = res['auto_aligned_prompt'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audit error: $e')),
        );
      }
    }
  }

  void _applyAutoAlignedFix() {
    if (_autoAlignedPrompt != null && _autoAlignedPrompt!.isNotEmpty) {
      setState(() {
        _promptController.text = _autoAlignedPrompt!;
        _isConsistent = true;
        _continuityFlags = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('✨ Contradictions automatically resolved and aligned with canon!'),
        ),
      );
    }
  }

  void _proceedWithPrompt() {
    final prompt = _promptController.text.trim();
    if (widget.onPromptSelected != null) {
      widget.onPromptSelected!(prompt);
      Navigator.pop(context);
    } else {
      Navigator.pop(context);
      context.push(
        '/story/${widget.storyId}/director',
        extra: {
          'chapterCount': widget.chapterCount,
          'initialPrompt': prompt,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF13151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 25, offset: Offset(0, -5)),
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
                  child: const Icon(Icons.hub_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Omniscient Chapter Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Chapter ${widget.chapterCount + 1} • Complete Canon Sync',
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
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
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),

          // Bottom Action Bar
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withOpacity(0.12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: const CircularProgressIndicator(color: Color(0xFFC084FC)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analyzing Living Timeline...',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Gathering the latest chapter cliffhanger, private 1-on-1 character chats, and tavern group interactions into a synchronized narrative web.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
            ),
          ),
        ],
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load synchronized prompts',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchPrompts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Canon Sync Banner
          _buildCanonSyncBanner(),
          const SizedBox(height: 16),

          // 2. Section Header: 5 Synced Prompts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 18),
                  SizedBox(width: 8),
                  Text(
                    '5 Synced Next-Chapter Directions',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                tooltip: 'Regenerate 5 directions',
                onPressed: _fetchPrompts,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select any of the 5 options below to populate and freely tweak the prompt:',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),

          // 5 Prompt Cards Horizontal/Vertical List
          ...List.generate(_prompts.length, (idx) => _buildPromptCard(idx)),

          const SizedBox(height: 20),

          // 3. Editable Prompt Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF60A5FA), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Customize Your Chapter Prompt',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'Freely editable',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
                hintText: 'Describe what happens next in Chapter ${widget.chapterCount + 1}...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              ),
              onChanged: (_) {
                // If user edits text, reset continuity audit state
                if (_isConsistent != null) {
                  setState(() {
                    _isConsistent = null;
                    _continuityFlags = [];
                    _autoAlignedPrompt = null;
                  });
                }
              },
            ),
          ),

          const SizedBox(height: 14),

          // 4. Continuity Auditor Section
          _buildContinuityAuditorSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCanonSyncBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1938),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leak_add, color: Color(0xFFA78BFA), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Timeline & Dialogue Web',
                style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.amber, size: 12),
                    SizedBox(width: 4),
                    Text('Active Sync', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _recentCanonSummary,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPill(Icons.book_outlined, 'Latest Chapter', Colors.purpleAccent),
              _buildPill(Icons.chat_bubble_outline, '1-on-1 Character Chats', Colors.cyanAccent),
              _buildPill(Icons.groups_outlined, 'Tavern Lounge Banter', Colors.amberAccent),
              _buildPill(Icons.checkroom_outlined, 'Active Outfits & Gifts', Colors.pinkAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPromptCard(int idx) {
    final prompt = _prompts[idx];
    final bool isSelected = _selectedIndex == idx;
    final category = prompt['category'] as String? ?? 'Direction';
    final title = prompt['title'] as String? ?? 'Chapter Idea';
    final text = prompt['prompt_text'] as String? ?? '';
    final syncedElements = (prompt['synced_elements'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = idx;
          _promptController.text = text;
          _isConsistent = null;
          _continuityFlags = [];
          _autoAlignedPrompt = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF262145) : const Color(0xFF181A26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFFA78BFA) : Colors.white24,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              maxLines: isSelected ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(isSelected ? 0.9 : 0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (syncedElements.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: syncedElements.map((elem) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔗 $elem',
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContinuityAuditorSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181C2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConsistent == true
              ? Colors.green.withOpacity(0.4)
              : _isConsistent == false
                  ? Colors.amber.withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Continuity & Contradiction Checker',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isAuditing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                )
              else
                TextButton.icon(
                  onPressed: _runContinuityAudit,
                  icon: const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF38BDF8)),
                  label: const Text('Audit Now', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scans proposed chapter events against character timelines, private chat confessions, and world rules to prevent plot holes before writing.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, height: 1.35),
          ),

          // Audit Results Display
          if (_isConsistent == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Canon Verified! No contradictions detected across 1-on-1 chats, group banter, or past chapters.',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isConsistent == false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Contradictions Detected:',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._continuityFlags.map((flag) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.amberAccent)),
                            Expanded(
                              child: Text(
                                flag,
                                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_autoAlignedPrompt != null && _autoAlignedPrompt!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _applyAutoAlignedFix,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('✨ Apply Auto-Aligned Fix (Zero Plot Holes)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F111A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Manual Blank Director option
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                  '/story/${widget.storyId}/director',
                  extra: {
                    'chapterCount': widget.chapterCount,
                  },
                );
              },
              child: Text(
                'Manual Blank',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            // Proceed to generate
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _proceedWithPrompt,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: Text('Generate Chapter ${widget.chapterCount + 1}'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
