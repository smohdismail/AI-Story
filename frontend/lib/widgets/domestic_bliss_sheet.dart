import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';

class DomesticBlissSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const DomesticBlissSheet({
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
      builder: (ctx) => DomesticBlissSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<DomesticBlissSheet> createState() => _DomesticBlissSheetState();
}

class _DomesticBlissSheetState extends State<DomesticBlissSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _vignettes = [];
  Map<String, dynamic>? _selectedVignette;
  String _selectedCategory = 'morning_kitchen';
  bool _isGenerating = false;

  final List<Map<String, String>> _categories = [
    {'key': 'morning_kitchen', 'label': '🥞 Kitchen Morning', 'desc': 'Breakfast & sweet sleepy smiles'},
    {'key': 'sick_bay_comfort', 'label': '🍵 Gentle Comfort', 'desc': 'Forehead kisses & herbal tea'},
    {'key': 'shared_sanctuary', 'label': '🏡 Our Sanctuary', 'desc': 'Furnishing & cozy home decorating'},
    {'key': 'late_night_porch', 'label': '🌙 Porch Stargazing', 'desc': 'Midnight blankets & soft cuddles'},
    {'key': 'anniversary_surprise', 'label': '🎁 Sweet Anniversary', 'desc': 'Hidden gifts & promise renewals'},
  ];

  @override
  void initState() {
    super.initState();
    _loadVignettes();
  }

  Future<void> _loadVignettes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getCharacterDomesticBliss(widget.characterId);
      setState(() {
        _vignettes = list;
        _isLoading = false;
        if (list.isNotEmpty) {
          _selectedVignette = list.first;
        }
      });

      if (list.isEmpty) {
        _generateVignette();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateVignette() async {
    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);

    try {
      final res = await ApiService.generateDomesticBliss(widget.characterId, category: _selectedCategory);
      if (res['vignette'] != null) {
        setState(() {
          _vignettes.insert(0, res['vignette']);
          _selectedVignette = res['vignette'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildAvatarImage(dynamic avatar, String name) {
    if (avatar != null && avatar.toString().isNotEmpty) {
      final str = avatar.toString();
      if (str.startsWith('http')) {
        return Image.network(str, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      }
      try {
        final bytes = base64Decode(str);
        return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar(name));
      } catch (_) {}
    }
    return _fallbackAvatar(name);
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      color: Colors.amber.shade900,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF14131A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0xFF382212), blurRadius: 28, spreadRadius: 4),
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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
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
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.cottage, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Domestic Bliss & Epilogue 🏡',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Life After the Story with ${widget.characterName}',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateVignette,
                  icon: _isGenerating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                      : const Icon(Icons.favorite, size: 14, color: Colors.amber),
                  label: const Text('Next Bliss', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade900.withValues(alpha: 0.4),
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Bar
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: isSelected,
                  selectedColor: Colors.amber.shade900.withValues(alpha: 0.5),
                  backgroundColor: const Color(0xFF1F1C25),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.amberAccent : Colors.white70,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.amberAccent : Colors.white12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedCategory = cat['key']!);
                      _generateVignette();
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: _isLoading || _isGenerating
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.amber),
                        SizedBox(height: 14),
                        Text('Crafting cozy domestic moment...', style: TextStyle(color: Colors.amber, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  )
                : _selectedVignette == null
                    ? const Center(child: Text('No domestic moments recorded yet.', style: TextStyle(color: Colors.white54)))
                    : _buildVignetteView(_selectedVignette!),
          ),
        ],
      ),
    );
  }

  Widget _buildVignetteView(Map<String, dynamic> vig) {
    final title = vig['vignette_title'] ?? 'Domestic Moment';
    final narrative = vig['story_narrative'] ?? '';
    final dialogue = vig['sweet_dialogue'] ?? '';
    final activity = vig['interactive_activity'] ?? '';
    final sentiment = vig['bliss_sentiment'] ?? 'Gentle love';
    final avatar = widget.avatarBase64;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cozy Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B1D12), Color(0xFF1D1720), Color(0xFF14131C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10),
                        ],
                      ),
                      child: ClipOval(child: _buildAvatarImage(avatar, widget.characterName)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vig['created_at'] ?? 'Living happily together',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                          const SizedBox(width: 4),
                          Text(sentiment, style: const TextStyle(fontSize: 11, color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (activity.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(activity, style: const TextStyle(fontSize: 11, color: Colors.amber, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Narrative Story
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1922),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, size: 15, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      'Daily Domestic Slice of Life',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  narrative,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14.5,
                    height: 1.8,
                    color: Color(0xFFF2EADC),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sweet Domestic Dialogue
          if (dialogue.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF261D17),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 15, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.characterName}\'s Sweet Whisper',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dialogue,
                    style: const TextStyle(fontFamily: 'serif', fontSize: 14, color: Colors.white, fontStyle: FontStyle.italic, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
