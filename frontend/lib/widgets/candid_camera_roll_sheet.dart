import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class CandidCameraRollSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;
  final String? storyId;

  const CandidCameraRollSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.avatarBase64,
    this.storyId,
  });

  static void show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? avatarBase64,
    String? storyId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => CandidCameraRollSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
        storyId: storyId,
      ),
    );
  }

  @override
  State<CandidCameraRollSheet> createState() => _CandidCameraRollSheetState();
}

class _CandidCameraRollSheetState extends State<CandidCameraRollSheet> {
  bool _isLoading = true;
  bool _isGenerating = false;
  List<dynamic> _photos = [];

  final List<Map<String, String>> _photoPrompts = [
    {
      'title': '☕ Morning Coffee in Pajamas',
      'category': 'morning_pajamas',
      'theme': 'Bed hair, cozy oversized sweater, sipping hot tea on balcony in soft morning sunlight'
    },
    {
      'title': '📚 Studying at Library Desk',
      'category': 'studying_library',
      'theme': 'Messy desk with highlighters and books, pencil tucked in hair, looking up surprised'
    },
    {
      'title': '🌅 Golden Hour Sunset Stroll',
      'category': 'golden_hour',
      'theme': 'Sun setting behind her hair, warm amber glow, candid looking over shoulder and smiling'
    },
    {
      'title': '👗 Getting Ready for Date',
      'category': 'getting_ready',
      'theme': 'Mirror selfie checking makeup or dress, shy blushing smile, soft warm room lights'
    },
    {
      'title': '🍳 Cooking in the Kitchen',
      'category': 'cooking_kitchen',
      'theme': 'Cute apron, tasting sauce from wooden spoon, laughing at camera'
    },
    {
      'title': '🌧️ Looking Out Rainy Window',
      'category': 'rainy_window',
      'theme': 'Raindrops on window pane, soft cozy lighting, contemplative affectionate look'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getCandidPhotos(widget.characterId);
      setState(() {
        _photos = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPhoto(String category, String theme) async {
    setState(() => _isGenerating = true);
    try {
      final newPhoto = await ApiService.requestCandidPhoto(
        widget.characterId,
        category: category,
        promptTheme: theme,
        isSpontaneous: false,
      );
      setState(() {
        _photos.insert(0, newPhoto);
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📸 ${widget.characterName} sent you a candid photo!'),
            backgroundColor: Colors.pinkAccent.shade700,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting photo: $e')),
        );
      }
    }
  }

  void _showRequestDialog() {
    final customController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.pinkAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ask ${widget.characterName} for a Photo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick a candid moment or write your own request:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ..._photoPrompts.map((p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                    title: Text(p['title']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _requestPhoto(p['category']!, p['theme']!);
                    },
                  )),
                  const Divider(color: Colors.white12),
                  const Text('Custom Moment:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Taking a stroll under the neon city lights...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.pinkAccent),
                        onPressed: () {
                          final text = customController.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx);
                            _requestPhoto('custom_request', text);
                          }
                        },
                      ),
                      isDense: true,
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

  void _openPhotoViewer(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1926),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      photo['image_url'] ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 300,
                        color: Colors.black26,
                        child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white38)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.pinkAccent),
                            const SizedBox(width: 4),
                            Text(
                              photo['location_tag'] ?? 'Private Space',
                              style: const TextStyle(fontSize: 12, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                photo['is_favorited'] == true ? Icons.favorite : Icons.favorite_border,
                                color: Colors.pinkAccent,
                                size: 20,
                              ),
                              onPressed: () async {
                                final fav = await ApiService.toggleFavoriteCandidPhoto(photo['id']);
                                setState(() {
                                  photo['is_favorited'] = fav;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          photo['caption'] ?? '',
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontStyle: FontStyle.italic, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IconButton.filled(
              onPressed: () => Navigator.pop(c),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF14121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.pink[900],
                  backgroundImage: (widget.avatarBase64 != null && widget.avatarBase64!.isNotEmpty)
                      ? (widget.avatarBase64!.startsWith('http')
                          ? NetworkImage(widget.avatarBase64!)
                          : MemoryImage(base64Decode(widget.avatarBase64!))) as ImageProvider
                      : null,
                  child: (widget.avatarBase64 == null || widget.avatarBase64!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.characterName}'s Camera Roll 📸",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Spontaneous candid moments & selfies",
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _showRequestDialog,
                  icon: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                  label: const Text('Ask Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Generating indicator
          if (_isGenerating)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.pink.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent)),
                  const SizedBox(width: 12),
                  Text(
                    "${widget.characterName} is snapping a photo for you...",
                    style: const TextStyle(fontSize: 12, color: Colors.pinkAccent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 50, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "No candid photos yet from ${widget.characterName}",
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _showRequestDialog,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Ask for her first photo!'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.shade700),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(14),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[index];
                          return GestureDetector(
                            onTap: () => _openPhotoViewer(photo),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1C2C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: Image.network(
                                        photo['image_url'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black26,
                                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          photo['location_tag'] ?? 'Candid Moment',
                                          style: const TextStyle(fontSize: 10, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          photo['caption'] ?? '',
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
