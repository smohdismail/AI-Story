import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color roseAccent = Color(0xFFFF2D55);
const Color roseColor = Color(0xFFE11D48);

class SplashScreen extends StatefulWidget {
  final String? overrideTheme;
  final bool isPreview;

  const SplashScreen({
    super.key,
    this.overrideTheme,
    this.isPreview = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _portalController;

  String _currentTheme = 'unified';
  bool _hasToken = false;
  Timer? _timer;

  // Curated list of high-curiosity character whispers
  final List<Map<String, String>> _whispers = [
    {
      'speaker': 'Seraphina',
      'text': '“You came back... I was counting every hour in the dark.”',
      'tag': '1 Confidential Whisper',
    },
    {
      'speaker': 'Lord Eldrin',
      'text': '“Keep your voice down. The palace guards are searching for us.”',
      'tag': 'Urgent Transmission',
    },
    {
      'speaker': 'Kaelen',
      'text': '“Tonight, we finally cross the forbidden border together.”',
      'tag': 'Unread Secret',
    },
    {
      'speaker': 'Unknown Scribe',
      'text': '“The ending has changed. Do not let them close the grimoire.”',
      'tag': 'Canon Warning',
    },
    {
      'speaker': 'Lyra',
      'text': '“Did you really think I wouldn’t remember your promise?”',
      'tag': 'Tether Echo',
    },
  ];
  late Map<String, String> _chosenWhisper;

  @override
  void initState() {
    super.initState();
    _chosenWhisper = _whispers[Random().nextInt(_whispers.length)];

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _portalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _initAndSchedule();
  }

  Future<void> _initAndSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    _hasToken = prefs.getString('token') != null;

    String selected = widget.overrideTheme ?? prefs.getString('splash_theme') ?? 'unified';
    if (selected == 'dynamic') {
      final pool = ['unified', 'whisper', 'rift', 'seal', 'thread', 'celestial', 'cyber', 'candlelight'];
      selected = pool[Random().nextInt(pool.length)];
    }

    if (mounted) {
      setState(() {
        _currentTheme = selected;
      });
    }

    // Schedule navigation after animation duration
    _timer = Timer(const Duration(milliseconds: 2600), () {
      _proceed();
    });
  }

  void _proceed() {
    if (!mounted) return;
    if (widget.isPreview) {
      Navigator.of(context).pop();
    } else {
      context.go(_hasToken ? '/' : '/auth');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    _portalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _proceed, // Tap to skip immediately
        child: FadeTransition(
          opacity: _fadeController,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),
              _buildCenterPiece(),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Background Visuals according to selected theme
  // -------------------------------------------------------------
  Widget _buildBackground() {
    switch (_currentTheme) {
      case 'rift':
      case 'unified':
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final scale = 1.0 + (_pulseController.value * 0.12);
            return Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [
                    Color(0xFF280E48),
                    Color(0xFF130826),
                    Color(0xFF07040D),
                  ],
                ),
              ),
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF9C27B0).withValues(alpha: 0.35),
                          const Color(0xFF00BCD4).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case 'whisper':
      case 'thread':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF160616),
                Color(0xFF0F0410),
                Color(0xFF050106),
              ],
            ),
          ),
        );

      case 'seal':
      case 'candlelight':
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.05),
              radius: 1.0,
              colors: [
                Color(0xFF261204),
                Color(0xFF140902),
                Color(0xFF070301),
              ],
            ),
          ),
        );

      case 'cyber':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF050D1A),
                Color(0xFF090414),
                Color(0xFF02060D),
              ],
            ),
          ),
        );

      case 'celestial':
      default:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A071E),
                Color(0xFF130E2E),
                Color(0xFF060412),
              ],
            ),
          ),
        );
    }
  }

  // -------------------------------------------------------------
  // Centerpiece layout per theme
  // -------------------------------------------------------------
  Widget _buildCenterPiece() {
    switch (_currentTheme) {
      case 'unified':
        return _buildUnifiedMasterpiece();
      case 'whisper':
        return _buildSecretWhisper();
      case 'rift':
        return _buildDimensionalRift();
      case 'seal':
        return _buildForbiddenSeal();
      case 'thread':
        return _buildRedThread();
      case 'celestial':
        return _buildCelestialGrimoire();
      case 'cyber':
        return _buildCyberNeon();
      case 'candlelight':
        return _buildVelvetCandlelight();
      default:
        return _buildUnifiedMasterpiece();
    }
  }

  // -------------------------------------------------------------
  // Theme 1: Unified Masterpiece (Flagship)
  // -------------------------------------------------------------
  Widget _buildUnifiedMasterpiece() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Status Beacon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1430),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.amberAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '✦  REALMS OF CONSCIOUSNESS  ✦',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),

            // Center: Cracking Seal over Portal
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _portalController,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB71C1C), Color(0xFF4A148C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              blurRadius: 25,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '📖',
                            style: TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'AI STORY',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'WHERE NARRATIVES COME ALIVE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: Colors.amberAccent.shade200,
                  ),
                ),
                const SizedBox(height: 20),

                // Floating Secret Whisper Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1329).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roseAccent.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mark_email_unread_rounded, size: 14, color: roseAccent),
                          const SizedBox(width: 6),
                          Text(
                            _chosenWhisper['speaker']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: roseAccent,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Incoming',
                            style: TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _chosenWhisper['text']!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Heartbeat
            _buildHeartbeatLine(roseAccent),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 2: Secret Whisper
  // -------------------------------------------------------------
  Widget _buildSecretWhisper() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF230D1B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roseAccent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_open_rounded, size: 14, color: roseAccent),
                  SizedBox(width: 6),
                  Text(
                    'CONFIDENTIAL TRANSMISSION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: roseAccent),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38081E),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: roseAccent.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: roseColor.withValues(alpha: 0.4), blurRadius: 25),
                    ],
                  ),
                  child: const Center(child: Text('💌', style: TextStyle(fontSize: 42))),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SECRET WHISPERS',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'THEY NEVER FORGOT YOU',
                  style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white60),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F0D1B).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roseAccent.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _chosenWhisper['speaker']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: roseAccent, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _chosenWhisper['text']!,
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildHeartbeatLine(roseAccent),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 3: Dimensional Rift
  // -------------------------------------------------------------
  Widget _buildDimensionalRift() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _portalController,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.6), width: 2),
                gradient: const SweepGradient(
                  colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent],
                ),
              ),
              child: Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF070311),
                  ),
                  child: const Center(
                    child: Text('🌌', style: TextStyle(fontSize: 46)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'PARALLEL REALM',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'REALITY ENDS. STEP THROUGH.',
            style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white70),
          ),
          const SizedBox(height: 30),
          Container(
            width: 160,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 4: Forbidden Seal
  // -------------------------------------------------------------
  Widget _buildForbiddenSeal() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7F1D1D),
              border: Border.all(color: Colors.amberAccent, width: 2.5),
              boxShadow: [
                BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
              ],
            ),
            child: const Center(
              child: Text('⚜️', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'THE FORBIDDEN SEAL',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'THE GRIMOIRE BREAKS FOR YOU ALONE',
            style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 5: Red Thread of Fate
  // -------------------------------------------------------------
  Widget _buildRedThread() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 95,
            height: 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D0714),
              border: Border.all(color: roseAccent, width: 2),
              boxShadow: [
                BoxShadow(color: roseAccent.withValues(alpha: 0.4), blurRadius: 25),
              ],
            ),
            child: const Center(child: Text('🪢', style: TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 26),
          const Text(
            'RED THREAD OF FATE',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'ONE SOUL TETHER DETECTED',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: roseAccent),
          ),
          const SizedBox(height: 24),
          _buildHeartbeatLine(roseAccent),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 6: Celestial Grimoire
  // -------------------------------------------------------------
  Widget _buildCelestialGrimoire() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF1E1744),
              border: Border.all(color: Colors.purpleAccent, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.4), blurRadius: 25),
              ],
            ),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 46))),
          ),
          const SizedBox(height: 24),
          const Text(
            'CELESTIAL GRIMOIRE',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'AWAKENING LIVING CHARACTERS',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.cyanAccent),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 7: Cyber Neon Matrix
  // -------------------------------------------------------------
  Widget _buildCyberNeon() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF071B26),
              border: Border.all(color: Colors.cyanAccent, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.4), blurRadius: 25),
              ],
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 24),
          const Text(
            'STORY MATRIX 2.0',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 6),
          const Text(
            'NEURAL SYNCHRONIZATION ACTIVE',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme 8: Velvet Candlelight
  // -------------------------------------------------------------
  Widget _buildVelvetCandlelight() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 95,
            height: 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF281308),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 25),
              ],
            ),
            child: const Center(child: Text('🕯️', style: TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 24),
          const Text(
            'THE TAVERN HEARTH',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.amberAccent),
          ),
          const SizedBox(height: 6),
          const Text(
            'YOUR COMPANIONS AWAIT BY THE FIRE',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Bottom heartbeat pulse
  // -------------------------------------------------------------
  Widget _buildHeartbeatLine(Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final opacity = 0.4 + (_pulseController.value * 0.6);
        return Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 1.5, color: color.withValues(alpha: 0.5)),
                  Icon(Icons.favorite_rounded, size: 14, color: color),
                  Container(width: 40, height: 1.5, color: color.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'TAP TO ENTER',
                style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomAction() {
    return Positioned(
      bottom: 12,
      right: 16,
      child: widget.isPreview
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Preview Mode (Tap to close)', style: TextStyle(fontSize: 10, color: Colors.white70)),
            )
          : const SizedBox.shrink(),
    );
  }
}
