import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _customRulesController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customRulesController.text = prefs.getString('global_custom_rules') ?? '';
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
}
