import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class RoomInspectionSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? avatarBase64;

  const RoomInspectionSheet({
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
      builder: (c) => RoomInspectionSheet(
        characterId: characterId,
        characterName: characterName,
        avatarBase64: avatarBase64,
      ),
    );
  }

  @override
  State<RoomInspectionSheet> createState() => _RoomInspectionSheetState();
}

class _RoomInspectionSheetState extends State<RoomInspectionSheet> {
  bool _isLoading = true;
  bool _isExploring = false;
  List<dynamic> _inspections = [];
  int _activeInspectionIndex = 0;
  Map<String, dynamic>? _selectedHotspot;

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getRoomInspections(widget.characterId);
      setState(() {
        _inspections = res;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exploreNewRoom(String roomType) async {
    setState(() => _isExploring = true);
    try {
      final newRoom = await ApiService.generateRoomInspection(
        widget.characterId,
        roomType: roomType,
      );
      setState(() {
        _inspections.insert(0, newRoom);
        _activeInspectionIndex = 0;
        _selectedHotspot = null;
        _isExploring = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔍 Entered ${widget.characterName}\'s ${newRoom['scene_title']}!'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExploring = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exploring room: $e')));
      }
    }
  }

  void _showRoomTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1A2C),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a Sanctuary to Explore 🔍',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bed, color: Colors.purpleAccent),
              title: const Text('Cozy Bedroom & Bedside', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _exploreNewRoom('bedroom');
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.amberAccent),
              title: const Text('Late-Night Study & Writing Desk', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _exploreNewRoom('study_desk');
              },
            ),
            ListTile(
              leading: const Icon(Icons.yard, color: Colors.tealAccent),
              title: const Text('Sunlit Balcony & Plant Sanctuary', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _exploreNewRoom('balcony_sanctuary');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHotspotDetails(Map<String, dynamic> hotspot) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1B1728),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hotspot['item_name'] ?? 'Discovered Item',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What you discovered:', style: TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              hotspot['discovery_lore'] ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${widget.characterName}: ${hotspot['character_secret_dialogue'] ?? ''}",
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close', style: TextStyle(color: Colors.pinkAccent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeInspection = (_inspections.isNotEmpty && _activeInspectionIndex < _inspections.length)
        ? _inspections[_activeInspectionIndex]
        : null;

    List<dynamic> hotspots = [];
    if (activeInspection != null && activeInspection['hotspots_json'] != null) {
      try {
        hotspots = jsonDecode(activeInspection['hotspots_json']);
      } catch (_) {}
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF13101C),
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
                const Icon(Icons.room_preferences, color: Colors.tealAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.characterName}'s Sanctuary Inspection 🔍",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Tap the glowing pins to discover secret keepsakes & lore",
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isExploring ? null : _showRoomTypePicker,
                  icon: const Icon(Icons.explore, size: 14),
                  label: const Text('Explore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          if (_isExploring)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.teal.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)),
                  const SizedBox(width: 12),
                  Text(
                    "Walking quietly into ${widget.characterName}'s personal room...",
                    style: const TextStyle(fontSize: 12, color: Colors.tealAccent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : activeInspection == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 50, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              "No rooms explored yet with ${widget.characterName}.",
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _showRoomTypePicker,
                              icon: const Icon(Icons.explore, size: 16),
                              label: const Text('Explore Her Bedroom Sanctuary'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Interactive Image with Hotspot Pins
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, constraints) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      child: Image.network(
                                        activeInspection['image_url'] ?? '',
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black38,
                                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                                        ),
                                      ),
                                    ),
                                    // Title overlay banner at top
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          activeInspection['scene_title'] ?? 'Private Room',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    // Interactive Pins
                                    ...hotspots.map((hs) {
                                      final double xPercent = ((hs['x_percent'] ?? 50) as num).toDouble();
                                      final double yPercent = ((hs['y_percent'] ?? 50) as num).toDouble();
                                      final left = (xPercent / 100.0) * constraints.maxWidth - 18;
                                      final top = (yPercent / 100.0) * constraints.maxHeight - 18;

                                      return Positioned(
                                        left: left,
                                        top: top,
                                        child: GestureDetector(
                                          onTap: () => _showHotspotDetails(hs),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.pinkAccent.shade700,
                                              boxShadow: [
                                                BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.7), blurRadius: 10, spreadRadius: 2),
                                              ],
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: const Icon(Icons.touch_app, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                            ),
                          ),

                          // Description and hotspots list
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: const Color(0xFF191626),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeInspection['scene_description'] ?? '',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: hotspots.map((hs) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: ActionChip(
                                          avatar: const Icon(Icons.search, size: 14, color: Colors.pinkAccent),
                                          label: Text(hs['item_name'] ?? 'Item', style: const TextStyle(fontSize: 11, color: Colors.white)),
                                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                                          side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                                          onPressed: () => _showHotspotDetails(hs),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
