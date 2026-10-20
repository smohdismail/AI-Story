import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';

class VintageMailboxSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const VintageMailboxSheet({
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
      builder: (ctx) => VintageMailboxSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<VintageMailboxSheet> createState() => _VintageMailboxSheetState();
}

class _VintageMailboxSheetState extends State<VintageMailboxSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _letters = [];
  Map<String, dynamic>? _selectedLetter;
  bool _isGenerating = false;

  // Reply Composer State
  bool _isReplying = false;
  final TextEditingController _replyController = TextEditingController();
  String _selectedCrest = 'Golden Rose';
  String _selectedStationery = 'Vintage Cream';
  bool _isSendingReply = false;

  final List<String> _crests = ['Golden Rose', 'Crescent Moon', 'Dragon Crest', 'Silver Dove'];
  final List<String> _stationeryStyles = ['Vintage Cream', 'Midnight Vellum', 'Rose Petal', 'Starry Navy'];

  @override
  void initState() {
    super.initState();
    _loadMailbox();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMailbox() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getCharacterMailbox(widget.characterId);
      setState(() {
        _letters = list;
        _isLoading = false;
        if (list.isNotEmpty && _selectedLetter == null) {
          _selectedLetter = list.first;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewLetter() async {
    setState(() => _isGenerating = true);
    try {
      final res = await ApiService.generateMailboxLetter(widget.characterId);
      if (res['letter'] != null) {
        setState(() {
          _letters.insert(0, res['letter']);
          _selectedLetter = res['letter'];
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

  Future<void> _openLetter(Map<String, dynamic> letter) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _selectedLetter = letter;
      _isReplying = false;
    });

    if (letter['is_opened'] != true) {
      setState(() {
        letter['is_opened'] = true;
      });
      try {
        await ApiService.openMailboxLetter(letter['id']);
      } catch (_) {}
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedLetter == null) return;

    setState(() => _isSendingReply = true);
    try {
      final res = await ApiService.replyMailboxLetter(
        _selectedLetter!['id'],
        userReply: text,
        replyCrest: _selectedCrest,
        replyStationery: _selectedStationery,
      );

      setState(() {
        _selectedLetter!['user_reply'] = text;
        _selectedLetter!['reply_crest'] = _selectedCrest;
        _selectedLetter!['reply_stationery'] = _selectedStationery;
        _selectedLetter!['character_reply_reaction'] = res['character_reply_reaction'];
        _isReplying = false;
        _replyController.clear();
      });

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF381E10),
            content: Text('${widget.characterName} has received and read your letter!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingReply = false);
    }
  }

  Color _getParchmentBg(String? style) {
    switch (style) {
      case 'midnight_vellum':
        return const Color(0xFF161520);
      case 'rose_petal':
        return const Color(0xFF26161E);
      case 'starry_navy':
        return const Color(0xFF0F1826);
      case 'aged_papyrus':
        return const Color(0xFF2B2215);
      default:
        return const Color(0xFF231F1D);
    }
  }

  Color _getWaxSealColor(String? color) {
    switch (color) {
      case 'gold':
        return const Color(0xFFD4AF37);
      case 'emerald':
        return const Color(0xFF2E8B57);
      case 'obsidian':
        return const Color(0xFF2B2B2B);
      case 'royal_purple':
        return const Color(0xFF7B1FA2);
      case 'rose_gold':
        return const Color(0xFFB76E79);
      default:
        return const Color(0xFF8B1E1E); // Crimson
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
      color: Colors.brown.shade800,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF141214),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 28, spreadRadius: 6),
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
                  child: const Icon(Icons.markunread_mailbox, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vintage Mailbox 📬',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Handwritten Letters & Keepsakes from ${widget.characterName}',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateNewLetter,
                  icon: _isGenerating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                      : const Icon(Icons.mail, size: 14, color: Colors.amber),
                  label: const Text('New Letter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                    : _letters.isEmpty
                        ? const Center(child: Text('No letters yet in your mailbox.', style: TextStyle(color: Colors.white54)))
                        : Column(
                            children: [
                              // Horizontal Envelope Selector
                              SizedBox(
                                height: 72,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _letters.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (ctx, i) {
                                    final let = _letters[i];
                                    final isSelected = _selectedLetter?['id'] == let['id'];
                                    final isOpened = let['is_opened'] == true;
                                    final sealColor = _getWaxSealColor(let['wax_seal_color']);

                                    return GestureDetector(
                                      onTap: () => _openLetter(let),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF2C241E) : const Color(0xFF1A1715),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? Colors.amber : Colors.white12,
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Wax Seal Emblem
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: sealColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(color: sealColor.withValues(alpha: 0.5), blurRadius: 4),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isOpened ? Icons.drafts : Icons.mail,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Letter #${_letters.length - i}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected ? Colors.amber : Colors.white70,
                                                  ),
                                                ),
                                                Text(
                                                  isOpened ? 'Opened' : 'Wax Sealed 🔒',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isOpened ? Colors.white38 : Colors.pinkAccent,
                                                    fontWeight: isOpened ? FontWeight.normal : FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const Divider(color: Colors.white10, height: 1),

                              // Letter Parchment Display
                              Expanded(
                                child: _selectedLetter == null
                                    ? const SizedBox.shrink()
                                    : _buildLetterPaperView(_selectedLetter!),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterPaperView(Map<String, dynamic> let) {
    final parchmentColor = _getParchmentBg(let['parchment_style']);
    final sealColor = _getWaxSealColor(let['wax_seal_color']);
    final content = let['letter_content'] ?? '';
    final keepsake = let['clipped_keepsake'];
    final caption = let['polaroid_caption'];
    final avatar = let['polaroid_image'] ?? widget.avatarBase64;
    final userReply = let['user_reply'];
    final reaction = let['character_reply_reaction'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Authentic Parchment Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: parchmentColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Wax Seal & Date Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: sealColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: sealColor.withValues(alpha: 0.6), blurRadius: 8),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.verified, size: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From ${let['sender_name'] ?? widget.characterName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                            ),
                            Text(
                              let['created_at'] ?? 'A late evening note',
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (keepsake != null && keepsake.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_florist, size: 12, color: Colors.pinkAccent),
                            const SizedBox(width: 4),
                            Text(
                              keepsake.toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.pinkAccent, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 14),

                // Clipped Polaroid Photo Frame (if available)
                if (avatar != null && avatar.toString().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(2, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 110,
                              width: 118,
                              child: _buildAvatarImage(avatar, widget.characterName),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            caption ?? 'For you...',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 9,
                              color: Colors.black87,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Handwritten Letter Body in Cursive/Serif
                SelectableText(
                  content,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    height: 1.8,
                    letterSpacing: 0.4,
                    color: Color(0xFFF0E6D8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // User's Reply Section or Reaction
          if (userReply != null && userReply.toString().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1A28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 16, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Your Letter Reply (${let['reply_crest'] ?? 'Golden Rose'} Crest)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userReply.toString(),
                    style: const TextStyle(fontFamily: 'serif', fontSize: 14, color: Colors.white70, height: 1.6),
                  ),
                  if (reaction != null && reaction.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.pinkAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.characterName}\'s Reaction Upon Reading',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reaction.toString(),
                      style: const TextStyle(fontSize: 13, color: Colors.white, fontStyle: FontStyle.italic, height: 1.6),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (_isReplying) ...[
            // Reply Composer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1B1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pen a Handwritten Reply ✉️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                  ),
                  const SizedBox(height: 10),

                  // Pick Crest
                  Row(
                    children: [
                      const Text('Personal Crest: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      DropdownButton<String>(
                        value: _selectedCrest,
                        dropdownColor: const Color(0xFF262220),
                        underline: const SizedBox.shrink(),
                        items: _crests.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, color: Colors.amber)))).toList(),
                        onChanged: (val) => setState(() => _selectedCrest = val ?? _selectedCrest),
                      ),
                    ],
                  ),

                  TextField(
                    controller: _replyController,
                    maxLines: 4,
                    style: const TextStyle(fontFamily: 'serif', fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Pour your heart out into ink and parchment...',
                      hintStyle: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isReplying = false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSendingReply ? null : _sendReply,
                        icon: _isSendingReply
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.send, size: 14, color: Colors.black),
                        label: const Text('Seal & Send Letter', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isReplying = true),
                icon: const Icon(Icons.edit_note, color: Colors.amber),
                label: const Text('Pen a Reply Letter ✍️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade900.withValues(alpha: 0.3),
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
