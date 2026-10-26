import 'package:flutter/material.dart';

/// An elegant 3 bouncing dots typing indicator (iMessage / Character.ai style).
class ThreeDotsWidget extends StatefulWidget {
  final Color? dotColor;
  final double dotSize;
  final double spacing;

  const ThreeDotsWidget({
    super.key,
    this.dotColor,
    this.dotSize = 7.0,
    this.spacing = 4.0,
  });

  @override
  State<ThreeDotsWidget> createState() => _ThreeDotsWidgetState();
}

class _ThreeDotsWidgetState extends State<ThreeDotsWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final effectiveColor = widget.dotColor ?? Colors.amber;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Staggered timing for each of the 3 dots
        final double delay = index * 0.2;
        double progress = (_controller.value - delay);
        if (progress < 0.0) progress += 1.0;

        // Wave curve: 0 -> peak -> 0
        final double sinVal = (progress < 0.6) 
            ? (1.0 - (progress / 0.3 - 1.0).abs()).clamp(0.0, 1.0)
            : 0.0;

        // Bounce up and down
        final double translateY = -5.0 * sinVal;
        // Scale and opacity pulse
        final double scale = 0.8 + (0.4 * sinVal);
        final double opacity = 0.4 + (0.6 * sinVal);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.4 * sinVal),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}

/// A complete speech bubble containing the 3 animated dots.
class TypingBubble extends StatelessWidget {
  final String? senderName;
  final Color? bubbleColor;
  final Color? dotColor;
  final String? label;

  const TypingBubble({
    super.key,
    this.senderName,
    this.bubbleColor,
    this.dotColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (senderName != null && senderName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(
              senderName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor ?? const Color(0xFF2A2A36),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThreeDotsWidget(
                dotColor: dotColor ?? Colors.amber,
                dotSize: 7.5,
                spacing: 5.0,
              ),
              if (label != null && label!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
