import 'package:flutter/material.dart';
import '../api.dart';

class PhotoboothStripSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const PhotoboothStripSheet({
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
      builder: (c) => PhotoboothStripSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<PhotoboothStripSheet> createState() => _PhotoboothStripSheetState();
}

class _PhotoboothStripSheetState extends State<PhotoboothStripSheet> {
  bool _isLoading = true;
  bool _isSnapping = false;
  List<dynamic> _strips = [];

  @override
  void initState() {
    super.initState();
    _loadStrips();
  }

  Future<void> _loadStrips() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getPhotoboothStrips(widget.characterId);
      setState(() {
        _strips = res;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _snapNewStrip() async {
    setState(() => _isSnapping = true);
    try {
      final strip = await ApiService.generatePhotoboothStrip(
        widget.characterId,
        milestoneEvent: 'Spontaneous Date Together',
        stripTheme: 'pastel_blossom',
      );
      setState(() {
        _strips.insert(0, strip);
        _isSnapping = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📸 New 4-Cut Photobooth Strip printed with ${widget.characterName}!'),
            backgroundColor: Colors.pinkAccent.shade700,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSnapping = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing strip: $e')));
      }
    }
  }

  void _inspectStrip(Map<String, dynamic> strip) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Physical-style 4-cut strip container
              Container(
                width: 260,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E9), // Pastel Pink Paper
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: Column(
                  children: [
                    // Header text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.pinkAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.characterName.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2, color: Colors.pink),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.auto_awesome, color: Colors.pinkAccent, size: 14),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 4 shots
                    _buildStripPhoto(strip['shot_1_image'], strip['shot_1_pose']),
                    const SizedBox(height: 8),
                    _buildStripPhoto(strip['shot_2_image'], strip['shot_2_pose']),
                    const SizedBox(height: 8),
                    _buildStripPhoto(strip['shot_3_image'], strip['shot_3_pose']),
                    const SizedBox(height: 8),
                    _buildStripPhoto(strip['shot_4_image'], strip['shot_4_pose']),
                    const SizedBox(height: 12),

                    // Handwritten bottom note
                    Text(
                      strip['handwritten_note'] ?? 'Forever & Always ✨',
                      style: const TextStyle(
                        fontFamily: 'cursive',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A2035),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• PURIKURA PHOTOBOOTH •',
                      style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildStripPhoto(String? url, String? caption) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url ?? '',
          height: 130,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(height: 130, color: Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                const Icon(Icons.photo_album, color: Colors.pinkAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.characterName}'s 4-Cut Photobooth Strips 🧳",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Collect nostalgic Purikura photobooth date keepsakes",
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSnapping ? null : _snapNewStrip,
                  icon: const Icon(Icons.flash_on, color: Colors.amberAccent, size: 14),
                  label: const Text('Snap 4-Cut', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

          if (_isSnapping)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.pink.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent)),
                  const SizedBox(width: 12),
                  Text(
                    "Flashing 4 poses in the photobooth with ${widget.characterName}... ✌️",
                    style: const TextStyle(fontSize: 12, color: Colors.pinkAccent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _strips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.crop_portrait, size: 50, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "No 4-cut photobooth strips snapped yet.",
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _snapNewStrip,
                              icon: const Icon(Icons.camera, size: 16),
                              label: const Text('Take First Photobooth Strip!'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.shade700),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _strips.length,
                        itemBuilder: (context, index) {
                          final strip = _strips[index];
                          return GestureDetector(
                            onTap: () => _inspectStrip(strip),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 14),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE6E8),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        strip['shot_1_image'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade400),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        strip['shot_2_image'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade400),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        strip['shot_3_image'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade400),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        strip['shot_4_image'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade400),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    strip['handwritten_note'] ?? 'Forever ✨',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4A2035)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
