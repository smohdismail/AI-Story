import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ambient_sound_service.dart';

class DynamicWeatherOverlay extends StatefulWidget {
  final Widget? child;
  final String? overrideWeather; // 'rain', 'snow', 'night', 'cafe', 'sunny', 'none'
  final bool isBackground;

  const DynamicWeatherOverlay({
    super.key,
    this.child,
    this.overrideWeather,
    this.isBackground = false,
  });

  @override
  State<DynamicWeatherOverlay> createState() => _DynamicWeatherOverlayState();
}

class _DynamicWeatherOverlayState extends State<DynamicWeatherOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final AmbientSoundService _soundService = AmbientSoundService();
  late List<_Particle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _soundService.addListener(_onServiceChanged);
    _initParticles();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _initParticles() {
    _particles = List.generate(45, (i) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.15 + _random.nextDouble() * 0.45,
        size: 1.5 + _random.nextDouble() * 3.5,
        opacity: 0.2 + _random.nextDouble() * 0.6,
        swayPhase: _random.nextDouble() * math.pi * 2,
        swaySpeed: 1.0 + _random.nextDouble() * 2.0,
      );
    });
  }

  @override
  void dispose() {
    _soundService.removeListener(_onServiceChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.overrideWeather ?? _soundService.effectiveWeather;
    final isEnabled = _soundService.isOverlayEnabled && weather != 'none';

    Widget overlay = isEnabled
        ? IgnorePointer(
            ignoring: true,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _WeatherPainter(
                    weather: weather,
                    progress: _animController.value,
                    particles: _particles,
                    intensity: _soundService.weatherIntensity,
                  ),
                );
              },
            ),
          )
        : const SizedBox.shrink();

    if (widget.child == null) {
      return overlay;
    }

    if (widget.isBackground) {
      return Stack(
        fit: StackFit.expand,
        children: [
          overlay,
          widget.child!,
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child!,
        overlay,
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  double swayPhase;
  double swaySpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.swayPhase,
    required this.swaySpeed,
  });
}

class _WeatherPainter extends CustomPainter {
  final String weather;
  final double progress;
  final List<_Particle> particles;
  final double intensity;

  _WeatherPainter({
    required this.weather,
    required this.progress,
    required this.particles,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    switch (weather) {
      case 'rain':
        _paintRain(canvas, size);
        break;
      case 'snow':
        _paintSnow(canvas, size);
        break;
      case 'night':
        _paintNightStars(canvas, size);
        break;
      case 'sunny':
        _paintSunbeams(canvas, size);
        break;
      case 'cafe':
        _paintCafeBokeh(canvas, size);
        break;
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    // 1. Slanted falling rain streaks
    final streakPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.28 * intensity)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final double slantX = -12.0;
    final double streakLen = 22.0;

    for (var p in particles) {
      double curY = ((p.y + progress * (p.speed * 2.8)) % 1.0) * size.height;
      double curX = ((p.x + progress * 0.15) % 1.0) * size.width;

      canvas.drawLine(
        Offset(curX, curY),
        Offset(curX + slantX, curY + streakLen),
        streakPaint,
      );
    }

    // 2. Slow glass window droplets running down
    final dropPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40 * intensity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      var p = particles[i];
      double dropY = ((p.y + progress * (p.speed * 0.35)) % 1.0) * size.height;
      double dropX = p.x * size.width;

      // Draw oval water droplet on glass
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dropX, dropY),
          width: p.size * 1.2,
          height: p.size * 2.2,
        ),
        dropPaint,
      );

      // Faint droplet trail
      final trailPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * intensity)
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(dropX, dropY - 14),
        Offset(dropX, dropY),
        trailPaint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final snowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var p in particles) {
      double curY = ((p.y + progress * (p.speed * 0.7)) % 1.0) * size.height;
      double sway = math.sin((progress * math.pi * 2 * p.swaySpeed) + p.swayPhase) * 16.0;
      double curX = (p.x * size.width + sway) % size.width;

      snowPaint.color = Colors.white.withValues(alpha: (p.opacity * intensity).clamp(0.1, 0.85));
      canvas.drawCircle(Offset(curX, curY), p.size * 1.1, snowPaint);
    }
  }

  void _paintNightStars(Canvas canvas, Size size) {
    // Soft vignette glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 1.2,
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.08 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      double curX = p.x * size.width;
      double curY = p.y * size.height;
      double pulse = 0.5 + 0.5 * math.sin((progress * math.pi * 4 * p.speed) + p.swayPhase);
      double alpha = (p.opacity * pulse * intensity).clamp(0.05, 0.9);

      starPaint.color = Colors.amber.shade100.withValues(alpha: alpha);
      canvas.drawCircle(Offset(curX, curY), p.size * 0.9, starPaint);

      // Star cross sparkle for larger stars
      if (p.size > 3.0 && pulse > 0.7) {
        final crossPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.6)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(curX - 4, curY), Offset(curX + 4, curY), crossPaint);
        canvas.drawLine(Offset(curX, curY - 4), Offset(curX, curY + 4), crossPaint);
      }
    }
  }

  void _paintSunbeams(Canvas canvas, Size size) {
    // Warm sunbeam overlay
    final sunbeamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Colors.amber.shade300.withValues(alpha: 0.09 * intensity),
          Colors.orangeAccent.withValues(alpha: 0.04 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sunbeamPaint);

    // Floating golden dust motes drifting upward
    final motePaint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      double curY = ((p.y - progress * (p.speed * 0.4)) % 1.0) * size.height;
      if (curY < 0) curY += size.height;
      double sway = math.sin((progress * math.pi * 2 * p.swaySpeed) + p.swayPhase) * 12.0;
      double curX = (p.x * size.width + sway) % size.width;

      motePaint.color = Colors.amber.shade200.withValues(alpha: (p.opacity * 0.5 * intensity).clamp(0.05, 0.6));
      canvas.drawCircle(Offset(curX, curY), p.size * 0.8, motePaint);
    }
  }

  void _paintCafeBokeh(Canvas canvas, Size size) {
    final bokehPaint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // Warm amber bokeh balls floating gently upward
      double curY = ((p.y - progress * (p.speed * 0.3)) % 1.0) * size.height;
      if (curY < 0) curY += size.height;
      double curX = (p.x * size.width + math.sin(progress * 2 + p.swayPhase) * 10) % size.width;

      final color = p.speed > 0.3 ? const Color(0xFFF59E0B) : const Color(0xFFEC4899);
      bokehPaint.color = color.withValues(alpha: (p.opacity * 0.22 * intensity).clamp(0.04, 0.35));
      canvas.drawCircle(Offset(curX, curY), p.size * 3.5, bokehPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.weather != weather ||
        oldDelegate.intensity != intensity;
  }
}
