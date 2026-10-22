import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../streak_service.dart';
import '../widgets/vip_subscription_sheet.dart';

class ProfileStudioScreen extends StatefulWidget {
  const ProfileStudioScreen({super.key});

  @override
  State<ProfileStudioScreen> createState() => _ProfileStudioScreenState();
}

class _ProfileStudioScreenState extends State<ProfileStudioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(text: "20");
  final _appearanceController = TextEditingController();
  final _personalityController = TextEditingController();
  final _backstoryController = TextEditingController();

  Map<String, dynamic>? _streakInfo;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await StreakService.getStreakInfo();
    try {
      final profile = await ApiService.getMyProfile();
      if (mounted) setState(() => _userProfile = profile);
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
    try {
      final persona = await ApiService.getPersona();
      if (mounted) {
        setState(() {
          _streakInfo = info;
          if (persona != null) {
            _nameController.text = persona['name'] ?? '';
            _ageController.text = persona['age']?.toString() ?? '20';
            _appearanceController.text = persona['appearance'] ?? '';
            _personalityController.text = persona['personality'] ?? '';
            _backstoryController.text = persona['backstory'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _streakInfo = info;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePersona() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.savePersona({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 20,
        'appearance': _appearanceController.text.trim(),
        'personality': _personalityController.text.trim(),
        'backstory': _backstoryController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Author Persona saved successfully! ✨'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Profile & Persona Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'App Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Author Header Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.purple.shade700,
                            child: const Icon(Icons.auto_stories, size: 34, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.isNotEmpty ? _nameController.text : 'Author / Protagonist',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                const Text('Lead Romantic Persona', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.local_fire_department, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_streakInfo?['streak'] ?? 0} Day Writing Streak',
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 👑 Owner Master VIP Badge & Unrestricted Privileges
                  if (_userProfile?['is_owner'] == true) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF831843), Color(0xFF581C87), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amberAccent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.2),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.workspace_premium, color: Colors.black, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '👑 APP OWNER & MASTER CREATOR',
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      'Lifetime VIP Status • Zero Paywalls',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amberAccent),
                                ),
                                child: const Text(
                                  'OWNER',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),
                          _buildOwnerRow(Icons.all_inclusive, 'Free Lifetime Access (No subscription needed)'),
                          const SizedBox(height: 6),
                          _buildOwnerRow(Icons.auto_stories, 'Master Library: Access ALL stories (Public & Private)'),
                          const SizedBox(height: 6),
                          _buildOwnerRow(Icons.people_alt, 'Character Lounge: Full access to EVERY character on platform'),
                        ],
                      ),
                    ),
                  ] else if (_userProfile?['is_vip'] == true) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF831843), Color(0xFF4C1D95)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.pinkAccent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.2),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.pinkAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.diamond, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '👑 ${_userProfile?['subscription_tier'] ?? 'VIP'} ACTIVE',
                                      style: const TextStyle(
                                        color: Colors.pinkAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Text(
                                      'Unlimited Chats & Spoken Voices 24/7',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Free Tier Status & Upgrade Prompt
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bolt, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Free Daily Allowance',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'FREE TIER',
                                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Daily Chats', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_userProfile?['daily_chats_remaining'] ?? 20} / 20 Left',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Daily Stories', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_userProfile?['daily_stories_remaining'] ?? 2} / 2 Left',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
                              label: const Text('Upgrade to Unlimited VIP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2D55),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => VipSubscriptionSheet.show(
                                context,
                                onUpgraded: _loadData,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Writing Stats Banner
                  if (_streakInfo != null)
                    Card(
                      color: const Color(0xFF1E1E2C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Words Today', '${_streakInfo!['todayWords'] ?? 0}'),
                            _buildStatItem('Current Streak', '${_streakInfo!['streak'] ?? 0}d 🔥'),
                            _buildStatItem('Max Streak', '${_streakInfo!['maxStreak'] ?? 0}d 🏆'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Persona Form Section
                  Row(
                    children: [
                      const Icon(Icons.badge, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text('Default Protagonist Persona', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Define the main character details you want the AI to remember when you write stories in first-person mode.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Persona Name', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter a name' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _appearanceController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Appearance',
                            hintText: 'e.g., Violet eyes, silver curls, tall with athletic build...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _personalityController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Personality',
                            hintText: 'e.g., Fiercely protective, quick-witted, guarded against vulnerability...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _backstoryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Backstory / Role',
                            hintText: 'e.g., Heir to a disgraced noble family, skilled in dual blades...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _savePersona,
                            icon: _isSaving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(_isSaving ? 'Saving...' : 'Save Author Persona'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOwnerRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }
}
