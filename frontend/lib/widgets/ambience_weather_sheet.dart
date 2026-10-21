import 'package:flutter/material.dart';
import '../services/ambient_sound_service.dart';
import '../services/real_world_sync_service.dart';

class AmbienceWeatherSheet extends StatefulWidget {
  const AmbienceWeatherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => const AmbienceWeatherSheet(),
    );
  }

  @override
  State<AmbienceWeatherSheet> createState() => _AmbienceWeatherSheetState();
}

class _AmbienceWeatherSheetState extends State<AmbienceWeatherSheet> {
  final AmbientSoundService _soundService = AmbientSoundService();

  @override
  void initState() {
    super.initState();
    _soundService.addListener(_onServiceChanged);
    RealWorldSyncService.instance.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _soundService.removeListener(_onServiceChanged);
    RealWorldSyncService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final effectiveWeather = _soundService.effectiveWeather;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF111422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.cloudy_snowing, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Living Atmosphere & Ambience',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Synced with Character Chat & Novel Reading',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
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

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Real-World Auto-Sync Card
                  _buildRealWorldSyncCard(),
                  const SizedBox(height: 18),

                  // 2. Weather Preset Vibes
                  const Row(
                    children: [
                      Icon(Icons.palette_outlined, color: Color(0xFF38BDF8), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Choose Atmospheric Vibe',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildVibeGrid(effectiveWeather),

                  const SizedBox(height: 20),

                  // 3. Soundscape Audio Player & Volume
                  _buildSoundscapePlayerCard(),

                  const SizedBox(height: 16),

                  // 4. Visual Glass Overlay Toggle & Intensity
                  _buildVisualOverlayControls(),

                  const SizedBox(height: 16),

                  // 5. Character Awareness Explanation
                  _buildCharacterAwarenessNotice(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealWorldSyncCard() {
    final reality = RealWorldSyncService.instance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2036),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reality.syncEnabled
              ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.public, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Live Real-World Reality Sync',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('LIVE GPS/IP', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${reality.displayLocation}${reality.temperatureDisplay.isNotEmpty ? ' • ${reality.temperatureDisplay}' : ''} (${reality.weatherDescription})',
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${reality.localTimeFormatted} • ${reality.humanRoutinePhase}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: reality.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                    : const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 20),
                tooltip: 'Refresh Live Location & Weather',
                onPressed: reality.isLoading ? null : () => reality.refreshReality(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Characters in 1-on-1 & Tavern lounge know your real city, live weather, and time',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              ),
              Switch(
                value: reality.syncEnabled,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) => reality.toggleSync(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVibeGrid(String effectiveWeather) {
    final vibes = [
      {
        'id': 'rain',
        'title': 'Rainy Window',
        'icon': '🌧️',
        'desc': 'Soft drops sliding on glass with thunder',
        'color': const Color(0xFF0284C7),
      },
      {
        'id': 'cafe',
        'title': 'Cozy Lo-Fi Cafe',
        'icon': '☕',
        'desc': 'Amber bokeh lights with velvet jazz',
        'color': const Color(0xFFD97706),
      },
      {
        'id': 'night',
        'title': 'Midnight Stars',
        'icon': '🌙',
        'desc': 'Twinkling starlight with garden crickets',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'snow',
        'title': 'Winter Hearth',
        'icon': '❄️',
        'desc': 'Gentle snow with fireplace embers',
        'color': const Color(0xFF06B6D4),
      },
      {
        'id': 'sunny',
        'title': 'Golden Hour',
        'icon': '☀️',
        'desc': 'Warm sunbeams & floating golden motes',
        'color': const Color(0xFFF59E0B),
      },
      {
        'id': 'none',
        'title': 'Clear Minimal',
        'icon': '🍃',
        'desc': 'No weather effects or overlays',
        'color': const Color(0xFF64748B),
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: vibes.length,
      itemBuilder: (context, idx) {
        final v = vibes[idx];
        final bool isSelected = effectiveWeather == v['id'];
        final color = v['color'] as Color;

        return GestureDetector(
          onTap: () {
            if (_soundService.autoSyncWithRealWorld) {
              _soundService.toggleAutoSync(false);
            }
            _soundService.setWeather(v['id'] as String, syncSound: v['id'] != 'none');
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.22) : const Color(0xFF171B2B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(v['icon'] as String, style: const TextStyle(fontSize: 20)),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  v['title'] as String,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                Text(
                  v['desc'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundscapePlayerCard() {
    final isPlaying = _soundService.isPlaying;
    final currentPreset = _soundService.currentPreset;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.teal.withValues(alpha: 0.2) : Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.graphic_eq : Icons.volume_mute,
                  color: isPlaying ? Colors.tealAccent : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Procedural Soundscape',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currentPreset != null ? '${currentPreset.icon} ${currentPreset.name}' : 'No audio playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? Colors.tealAccent : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                color: isPlaying ? Colors.tealAccent : const Color(0xFF38BDF8),
                iconSize: 36,
                onPressed: () {
                  if (isPlaying) {
                    _soundService.pause();
                  } else {
                    _soundService.resume();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.volume_down, size: 16, color: Colors.white.withValues(alpha: 0.5)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: Colors.tealAccent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.tealAccent,
                  ),
                  child: Slider(
                    value: _soundService.volume,
                    onChanged: (val) => _soundService.setVolume(val),
                  ),
                ),
              ),
              Icon(Icons.volume_up, size: 16, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualOverlayControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Screen Glass Overlay (Rain/Snow/Stars)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: _soundService.isOverlayEnabled,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) => _soundService.toggleOverlay(val),
              ),
            ],
          ),
          if (_soundService.isOverlayEnabled) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Effect Opacity',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      trackHeight: 2,
                      activeTrackColor: const Color(0xFF38BDF8),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF38BDF8),
                    ),
                    child: Slider(
                      value: _soundService.weatherIntensity,
                      min: 0.2,
                      max: 1.0,
                      onChanged: (val) => _soundService.setWeatherIntensity(val),
                    ),
                  ),
                ),
                Text(
                  '${(_soundService.weatherIntensity * 100).toInt()}%',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacterAwarenessNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1938),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_outlined, color: Color(0xFFA78BFA), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Character Environmental Awareness',
                  style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Characters in chat and novel chapters naturally notice this atmosphere! If it’s raining, they might wish they could share an umbrella; late at night, they’ll notice you staying up late.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
