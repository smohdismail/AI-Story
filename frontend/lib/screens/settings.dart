import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme_provider.dart';
import '../api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _customRulesController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  String _selectedSplashTheme = 'unified';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await ApiService.initApiConfig();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customRulesController.text = prefs.getString('global_custom_rules') ?? '';
      _serverUrlController.text = ApiService.baseUrl;
      _selectedSplashTheme = prefs.getString('splash_theme') ?? 'unified';
      _isLoading = false;
    });
  }

  Future<void> _saveCustomRules(String rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_custom_rules', rules);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom AI Rules saved successfully.')),
      );
    }
  }

  Future<void> _saveSplashTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('splash_theme', theme);
    setState(() {
      _selectedSplashTheme = theme;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Splash Screen theme updated!')),
      );
    }
  }

  void _previewSplash(String themeKey) {
    context.push('/splash', extra: {
      'overrideTheme': themeKey,
      'isPreview': true,
    });
  }

  Future<void> _saveServerUrl(String url) async {
    await ApiService.setBaseUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend Server URL set to: ${ApiService.baseUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Backend Server Connection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure the API endpoint URL for AI-Story backend:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Server Base URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.cloud, size: 18),
                      label: const Text('Cloud Server'),
                      onPressed: () {
                        _serverUrlController.text = ApiService.defaultCloudUrl;
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.phone_android, size: 18),
                      label: const Text('Emulator (10.0.2.2)'),
                      onPressed: () {
                        _serverUrlController.text = ApiService.defaultEmulatorUrl;
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 18),
                      label: const Text('Local (127.0.0.1)'),
                      onPressed: () {
                        _serverUrlController.text = ApiService.defaultLocalUrl;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _saveServerUrl(_serverUrlController.text),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Server URL'),
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 32),
          const Text(
            'App Theme',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: AppThemeMode.values.map((mode) {
                return RadioListTile<AppThemeMode>(
                  title: Text(mode.name.toUpperCase()),
                  value: mode,
                  groupValue: themeProvider.themeMode,
                  onChanged: (AppThemeMode? value) {
                    if (value != null) {
                      themeProvider.setTheme(value);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Splash Screen Experience 🎬',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: () => _previewSplash(_selectedSplashTheme),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Test Current'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which cinematic opening screen plays when the app launches:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildSplashRadio('unified', '👑 Unified Masterpiece', 'Grimoire + Crack + Secret Whisper + Heartbeat', Icons.auto_awesome, Colors.amberAccent),
                const Divider(height: 1),
                _buildSplashRadio('dynamic', '🎲 Dynamic Shuffler', 'Surprise opening every launch!', Icons.shuffle, Colors.cyanAccent),
                const Divider(height: 1),
                _buildSplashRadio('whisper', '💌 The Secret Whisper', 'Encrypted character transmission & soundwave', Icons.mark_email_unread_rounded, const Color(0xFFFF2D55)),
                const Divider(height: 1),
                _buildSplashRadio('rift', '🌌 The Dimensional Rift', 'Cosmic void tearing open into parallel reality', Icons.cyclone, Colors.cyan),
                const Divider(height: 1),
                _buildSplashRadio('seal', '📜 The Forbidden Seal', 'Ancient molten wax seal breaking open', Icons.verified_user, Colors.amber),
                const Divider(height: 1),
                _buildSplashRadio('thread', '🫀 Red Thread of Fate', 'Living soul tether & heartbeat sync', Icons.favorite, Colors.redAccent),
                const Divider(height: 1),
                _buildSplashRadio('celestial', '✨ Celestial Grimoire', 'Cosmic starlight & floating spellbook', Icons.auto_stories, Colors.purpleAccent),
                const Divider(height: 1),
                _buildSplashRadio('cyber', '⚡ Cyber Neon Matrix', 'High-tech neural story stream', Icons.bolt, Colors.tealAccent),
                const Divider(height: 1),
                _buildSplashRadio('candlelight', '🕯️ Velvet Candlelight', 'Warm tavern hearth & companion echoes', Icons.local_fire_department, Colors.orangeAccent),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Global AI Rules (Director\'s Chair)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set global rules that the AI will follow for ALL stories unless overridden (e.g., "Write in first person", "Make it gritty").',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customRulesController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter your custom AI rules here...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _saveCustomRules(_customRulesController.text),
            icon: const Icon(Icons.save),
            label: const Text('Save Rules'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplashRadio(String key, String title, String subtitle, IconData icon, Color color) {
    final isSelected = _selectedSplashTheme == key;
    return RadioListTile<String>(
      value: key,
      groupValue: _selectedSplashTheme,
      onChanged: (val) {
        if (val != null) _saveSplashTheme(val);
      },
      title: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 30.0, top: 2),
        child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ),
      secondary: IconButton(
        icon: const Icon(Icons.visibility_outlined, size: 20),
        tooltip: 'Preview Screen',
        onPressed: () => _previewSplash(key),
      ),
    );
  }
}
