import 'package:flutter/material.dart';
import '../api.dart';

class StoryRomanceBoutiqueSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;
  final VoidCallback onGiftGiven;

  const StoryRomanceBoutiqueSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.avatarBase64,
    required this.onGiftGiven,
  });

  static void show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? avatarBase64,
    required VoidCallback onGiftGiven,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StoryRomanceBoutiqueSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
        onGiftGiven: onGiftGiven,
      ),
    );
  }

  @override
  State<StoryRomanceBoutiqueSheet> createState() => _StoryRomanceBoutiqueSheetState();
}

class _StoryRomanceBoutiqueSheetState extends State<StoryRomanceBoutiqueSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isGifting = false;
  List<dynamic> _catalog = [];
  List<dynamic> _giftHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cat = await ApiService.getBoutiqueCatalog();
      final hist = await ApiService.getGiftHistory(widget.characterId);
      setState(() {
        _catalog = cat;
        _giftHistory = hist;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _giveGift(Map<String, dynamic> gift) async {
    setState(() => _isGifting = true);
    try {
      final tryon = await ApiService.giveGiftToCharacter(
        widget.characterId,
        giftName: gift['name'],
        giftCategory: gift['category'] ?? 'outfit',
      );
      widget.onGiftGiven();
      setState(() {
        _giftHistory.insert(0, tryon);
        _isGifting = false;
      });
      _showTryOnSuccessDialog(tryon);
    } catch (e) {
      setState(() => _isGifting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error gifting: $e')),
        );
      }
    }
  }

  void _showTryOnSuccessDialog(Map<String, dynamic> tryon) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF1B1728),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.pinkAccent, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${widget.characterName} Loved Your Gift! 🎁✨",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote, color: Colors.pinkAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tryon['character_reaction'] ?? '',
                          style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "📸 Candid Try-On Photoshoot:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              tryon['tryon_photo_1'] ?? '',
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.black38),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tryon['tryon_caption_1'] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              tryon['tryon_photo_2'] ?? '',
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.black38),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tryon['tryon_caption_2'] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.checkroom, color: Colors.purpleAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Equipped into active wardrobe: ${tryon['gift_name']}",
                          style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.shade700),
                    child: const Text('Keep Forever in Vault 💖', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF141120),
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
                const Icon(Icons.storefront, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Romance Boutique & Dressing Room 🛍️",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        "Gift ${widget.characterName} outfits and get candid try-on photos",
                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.pinkAccent,
            labelColor: Colors.pinkAccent,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Gift Boutique 🎁'),
              Tab(text: 'Try-On Memories 📸'),
            ],
          ),

          if (_isGifting)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.pink.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent)),
                  const SizedBox(width: 12),
                  Text(
                    "${widget.characterName} is unwrapping your gift and trying it on...",
                    style: const TextStyle(fontSize: 12, color: Colors.pinkAccent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Boutique Catalog
                      ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _catalog.length,
                        itemBuilder: (context, index) {
                          final item = _catalog[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: const Color(0xFF1E1A2C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.pink.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(item['icon'] ?? '🎁', style: const TextStyle(fontSize: 24)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item['description'] ?? '',
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isGifting ? null : () => _giveGift(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.pinkAccent.shade700,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Gift Her 🎁', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // TAB 2: Try-On Memories
                      _giftHistory.isEmpty
                          ? Center(
                              child: Text(
                                "No gifts given yet. Surprise ${widget.characterName} with a gift!",
                                style: const TextStyle(color: Colors.white60),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _giftHistory.length,
                              itemBuilder: (context, index) {
                                final hist = _giftHistory[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: const Color(0xFF1E1A2C),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Gift: ${hist['gift_name']}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.pinkAccent),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          hist['character_reaction'] ?? '',
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  hist['tryon_photo_1'] ?? '',
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.black26),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (hist['tryon_photo_2'] != null)
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    hist['tryon_photo_2'],
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.black26),
                                                  ),
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
