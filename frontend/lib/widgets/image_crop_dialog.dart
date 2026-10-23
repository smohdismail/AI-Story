import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CropResult {
  final String croppedAvatarBase64;
  final String originalImageBase64;
  final bool wasCropped;

  CropResult({
    required this.croppedAvatarBase64,
    required this.originalImageBase64,
    required this.wasCropped,
  });
}

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String? originalBase64;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.originalBase64,
  });

  static Future<CropResult?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? originalBase64,
  }) {
    return showDialog<CropResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImageCropDialog(
        imageBytes: imageBytes,
        originalBase64: originalBase64,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  bool _isCircle = true;
  bool _isProcessing = false;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentZoom).abs() > 0.05) {
      if (mounted) setState(() => _currentZoom = scale.clamp(0.6, 5.0));
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }

  void _focusFace() {
    // Zooms in and pans toward the upper-third of a full-body portrait where the face is located
    final matrix = Matrix4.identity()
      ..scale(2.3, 2.3, 1.0)
      ..translate(0.0, 45.0, 0.0);
    _transformationController.value = matrix;
    setState(() => _currentZoom = 2.3);
  }

  void _setZoomSlider(double value) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale == 0) return;
    final factor = value / currentScale;
    final matrix = _transformationController.value.clone()..scale(factor, factor, 1.0);
    _transformationController.value = matrix;
    setState(() => _currentZoom = value);
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);
    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Crop boundary not ready');

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to export crop image');

      final Uint8List croppedBytes = byteData.buffer.asUint8List();
      final croppedB64 = base64Encode(croppedBytes);
      final originalB64 = widget.originalBase64 ?? base64Encode(widget.imageBytes);

      if (mounted) {
        Navigator.pop(
          context,
          CropResult(
            croppedAvatarBase64: croppedB64,
            originalImageBase64: originalB64,
            wasCropped: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping avatar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _useFullImage() {
    final originalB64 = widget.originalBase64 ?? base64Encode(widget.imageBytes);
    Navigator.pop(
      context,
      CropResult(
        croppedAvatarBase64: originalB64,
        originalImageBase64: originalB64,
        wasCropped: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14141E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.crop, color: Colors.pinkAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frame Avatar & Wallpaper',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Full image is kept for Chat Wallpaper',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Full Image Preserved Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        widget.imageBytes,
                        width: 32,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Full Photo Preserved 100%',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Your full uncropped photo will be used as the Chat Background. Center the face below for the Avatar.',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Interactive Crop Viewport (270x270)
              Center(
                child: SizedBox(
                  width: 270,
                  height: 270,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Backdrop
                      Container(
                        width: 270,
                        height: 270,
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090D),
                          borderRadius: BorderRadius.circular(_isCircle ? 135 : 18),
                        ),
                      ),
                      // Interactive Viewport captured by RepaintBoundary
                      RepaintBoundary(
                        key: _cropKey,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_isCircle ? 135 : 18),
                          child: Container(
                            width: 270,
                            height: 270,
                            color: const Color(0xFF0C0C12),
                            child: InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 0.6,
                              maxScale: 6.0,
                              boundaryMargin: const EdgeInsets.all(180),
                              clipBehavior: Clip.none,
                              child: Center(
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.contain, // Shows 100% full image without clipping!
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Glowing Guide Frame Overlay
                      IgnorePointer(
                        child: Container(
                          width: 270,
                          height: 270,
                          decoration: BoxDecoration(
                            shape: _isCircle ? BoxShape.circle : BoxShape.rectangle,
                            borderRadius: _isCircle ? null : BorderRadius.circular(18),
                            border: Border.all(color: Colors.pinkAccent, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pinkAccent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Zoom Slider
              Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.white54, size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.pinkAccent,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.pinkAccent,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: _currentZoom.clamp(0.6, 5.0),
                        min: 0.6,
                        max: 5.0,
                        onChanged: _setZoomSlider,
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.white54, size: 18),
                ],
              ),

              // Quick Actions: Focus Face, Full Body Reset, Shape
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _focusFace,
                    icon: const Icon(Icons.face, size: 15, color: Colors.amberAccent),
                    label: const Text('Focus Face 👤', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.accessibility_new, size: 15, color: Colors.cyanAccent),
                    label: const Text('Full Body 🧍', style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isCircle = !_isCircle),
                    icon: Icon(_isCircle ? Icons.crop_square : Icons.circle_outlined, size: 15, color: Colors.white70),
                    label: Text(_isCircle ? 'Square' : 'Circle', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Bottom Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _useFullImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Use Full Image', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _applyCrop,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: const Text(
                        'Done (Set Avatar) ✂️',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
