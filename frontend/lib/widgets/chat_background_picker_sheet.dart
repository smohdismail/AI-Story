import '../api.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatBackgroundPickerSheet extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? defaultAvatarBase64;
  final String? currentBackground;
  final double currentDim;
  final Function(String? newBackground, double newDim) onBackgroundSelected;

  const ChatBackgroundPickerSheet({
    super.key,
    required this.characterId,
    required this.characterName,
    this.defaultAvatarBase64,
    this.currentBackground,
    required this.currentDim,
    required this.onBackgroundSelected,
  });

  static void show(
    BuildContext context, {
    required String characterId,
    required String characterName,
    String? defaultAvatarBase64,
    String? currentBackground,
    double currentDim = 0.6,
    required Function(String? newBackground, double newDim) onBackgroundSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => ChatBackgroundPickerSheet(
        characterId: characterId,
        characterName: characterName,
        defaultAvatarBase64: defaultAvatarBase64,
        currentBackground: currentBackground,
        currentDim: currentDim,
        onBackgroundSelected: onBackgroundSelected,
      ),
    );
  }

  @override
  State<ChatBackgroundPickerSheet> createState() => _ChatBackgroundPickerSheetState();
}

class _ChatBackgroundPickerSheetState extends State<ChatBackgroundPickerSheet> {
  List<String> _backgrounds = [];
  String? _selectedBackground;
  double _dimOpacity = 0.6;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedBackground = widget.currentBackground ?? widget.defaultAvatarBase64;
    _dimOpacity = widget.currentDim;
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('custom_bgs_${widget.characterId}') ?? [];
    
    // 1. Initial local files
    final validFiles = savedList.where((p) {
      if (p.startsWith('http') || p.length > 200) return true; // URLs or base64
      return File(p).existsSync();
    }).toList();

    if (mounted) {
      setState(() {
        _backgrounds = validFiles;
        _isLoading = false;
      });
    }

    // 2. Fetch from Database to guarantee persistence across app restarts / reinstalls
    try {
      final charInfo = await ApiService.getCharacter(widget.characterId);
      final List<String> serverWallpapers = [];
      if (charInfo['wallpapers_json'] != null && charInfo['wallpapers_json'].toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(charInfo['wallpapers_json']);
          if (decoded is List) {
            serverWallpapers.addAll(decoded.map((e) => e.toString()));
          }
        } catch (_) {}
      }

      // Also if background_base64 is present and not yet in list, include it
      final serverBg = charInfo['background_base64']?.toString();
      if (serverBg != null && serverBg.isNotEmpty && !serverWallpapers.contains(serverBg)) {
        serverWallpapers.insert(0, serverBg);
      }

      // Merge server wallpapers and local files without duplicates
      final mergedList = <String>[];
      for (final item in [...serverWallpapers, ...validFiles]) {
        if (!mergedList.contains(item)) {
          mergedList.add(item);
        }
      }

      await prefs.setStringList('custom_bgs_${widget.characterId}', mergedList);
      
      final active = prefs.getString('active_bg_${widget.characterId}') ?? serverBg;

      if (mounted) {
        setState(() {
          _backgrounds = mergedList;
          if (_selectedBackground == null || _selectedBackground == widget.defaultAvatarBase64) {
            _selectedBackground = active ?? widget.defaultAvatarBase64;
          }
        });
      }
    } catch (e) {
      debugPrint('Error syncing wallpapers from database: $e');
    }
  }

  Future<void> _pickAndUploadImages() async {
    final picker = ImagePicker();
    try {
      setState(() => _isUploading = true);
      
      // Try multi-image selection
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (pickedFiles.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final List<String> newlyAdded = [];
      String? lastActive;

      for (int i = 0; i < pickedFiles.length; i++) {
        final xFile = pickedFiles[i];
        final bytes = await xFile.readAsBytes();
        final base64Img = base64Encode(bytes);

        try {
          // Save directly to the Database!
          final res = await ApiService.uploadCharacterWallpaper(widget.characterId, base64Img);
          final serverUrl = res['url']?.toString() ?? base64Img;
          newlyAdded.add(serverUrl);
          lastActive = res['active_wallpaper']?.toString() ?? serverUrl;
        } catch (err) {
          // Fallback to local copy if network fails
          debugPrint('Upload wallpaper API failed, fallback to local: $err');
          final dir = await getApplicationDocumentsDirectory();
          final wpDir = Directory('${dir.path}/chat_wallpapers/${widget.characterId}');
          if (!await wpDir.exists()) await wpDir.create(recursive: true);
          final fileExt = xFile.name.contains('.') ? xFile.name.split('.').last : 'jpg';
          final newPath = '${wpDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
          final savedFile = await File(xFile.path).copy(newPath);
          newlyAdded.add(savedFile.path);
          lastActive = savedFile.path;
        }
      }

      final updatedList = [...newlyAdded, ..._backgrounds.where((b) => !newlyAdded.contains(b))];
      await prefs.setStringList('custom_bgs_${widget.characterId}', updatedList);

      final newlySelected = lastActive ?? newlyAdded.first;
      await prefs.setString('active_bg_${widget.characterId}', newlySelected);

      setState(() {
        _backgrounds = updatedList;
        _selectedBackground = newlySelected;
        _isUploading = false;
      });

      widget.onBackgroundSelected(newlySelected, _dimOpacity);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${newlyAdded.length} new wallpaper${newlyAdded.length > 1 ? "s" : ""} to Database!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding images: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _selectBackground(String? path) async {
    setState(() => _selectedBackground = path);
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('active_bg_${widget.characterId}');
    } else {
      await prefs.setString('active_bg_${widget.characterId}', path);
    }
    try {
      await ApiService.setActiveCharacterWallpaper(widget.characterId, path);
    } catch (e) {
      debugPrint('Sync active wallpaper to database failed: $e');
    }
    widget.onBackgroundSelected(path, _dimOpacity);
  }

  Future<void> _deleteBackground(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Delete Background', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this background image from your collection?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await ApiService.deleteCharacterWallpaper(widget.characterId, path);
    } catch (e) {
      debugPrint('Delete wallpaper from database failed: $e');
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    final updated = _backgrounds.where((p) => p != path).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_bgs_${widget.characterId}', updated);

    String? nextSelected = _selectedBackground;
    if (_selectedBackground == path) {
      nextSelected = updated.isNotEmpty ? updated.first : widget.defaultAvatarBase64;
      if (nextSelected != null) {
        await prefs.setString('active_bg_${widget.characterId}', nextSelected);
      } else {
        await prefs.remove('active_bg_${widget.characterId}');
      }
      widget.onBackgroundSelected(nextSelected, _dimOpacity);
    }

    setState(() {
      _backgrounds = updated;
      _selectedBackground = nextSelected;
    });
  }

  Future<void> _updateDim(double val) async {
    setState(() => _dimOpacity = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bg_dim_${widget.characterId}', val);
    widget.onBackgroundSelected(_selectedBackground, val);
  }

  ImageProvider _buildThumbnailProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    try {
      return MemoryImage(base64Decode(path));
    } catch (_) {
      return const AssetImage('assets/placeholder.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF13111C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 25, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wallpaper, color: Colors.pinkAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat Wallpapers',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Upload and switch backgrounds for ${widget.characterName}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
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

          // Upload Button Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: InkWell(
              onTap: _isUploading ? null : _pickAndUploadImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _isUploading ? 'Uploading Images...' : '+ Upload Images from Phone Gallery',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Background Gallery Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: 1 + _backgrounds.length,
                      itemBuilder: (context, index) {
                        // Index 0 is Default Character Avatar
                        if (index == 0) {
                          final isSelected = _selectedBackground == widget.defaultAvatarBase64;
                          return _buildItemCard(
                            title: 'Default Avatar',
                            imageProvider: widget.defaultAvatarBase64 != null
                                ? _buildThumbnailProvider(widget.defaultAvatarBase64!)
                                : null,
                            isSelected: isSelected,
                            onTap: () => _selectBackground(widget.defaultAvatarBase64),
                            onDelete: null,
                          );
                        }

                        final bgPath = _backgrounds[index - 1];
                        final isSelected = _selectedBackground == bgPath;
                        return _buildItemCard(
                          title: 'Custom #${index}',
                          imageProvider: _buildThumbnailProvider(bgPath),
                          isSelected: isSelected,
                          onTap: () => _selectBackground(bgPath),
                          onDelete: () => _deleteBackground(bgPath),
                        );
                      },
                    ),
                  ),
          ),

          // Dim / Tint Slider Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.brightness_medium_rounded, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          'Background Dim / Darkening',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '${(_dimOpacity * 100).round()}%',
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.pinkAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.pinkAccent.withOpacity(0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _dimOpacity,
                    min: 0.1,
                    max: 0.9,
                    onChanged: (val) => _updateDim(val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required String title,
    required ImageProvider? imageProvider,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFEC4899) : Colors.white12,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (imageProvider != null)
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
                ),
              )
            else
              Container(
                color: Colors.grey.shade900,
                child: const Center(child: Icon(Icons.person, color: Colors.white38, size: 36)),
              ),

            // Gradient bottom overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Selected checkmark badge
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEC4899),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),

            // Delete button (for custom images)
            if (onDelete != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
