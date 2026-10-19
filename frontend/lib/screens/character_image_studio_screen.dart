import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../utils/name_generator.dart';

class CharacterImageStudioScreen extends StatefulWidget {
  final String storyId;
  final Map<String, dynamic>? existingCharacter;

  const CharacterImageStudioScreen({
    super.key,
    required this.storyId,
    this.existingCharacter,
  });

  @override
  State<CharacterImageStudioScreen> createState() => _CharacterImageStudioScreenState();
}

class _CharacterImageStudioScreenState extends State<CharacterImageStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Prompt & Generation state
  final TextEditingController _promptController = TextEditingController();
  String _selectedStyle = 'photorealistic';
  bool _isGeneratingImage = false;
  String? _selectedBase64Image;
  final List<Map<String, dynamic>> _imageHistory = [];

  // Character details controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _appearanceController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final TextEditingController _dialogueStyleController = TextEditingController();

  bool _isAutoFilling = false;
  bool _isSaving = false;

  final List<Map<String, String>> _styleOptions = [
    {'id': 'photorealistic', 'label': '📸 Photorealistic', 'desc': 'Lifelike 8K portrait'},
    {'id': 'anime', 'label': '🎨 Anime / Manga', 'desc': 'Vibrant manhwa illustration'},
    {'id': 'dark_fantasy', 'label': '🗡️ Dark Fantasy', 'desc': 'Gothic moody oil aesthetics'},
    {'id': 'cyberpunk', 'label': '⚡ Cyberpunk', 'desc': 'Neon rain & futuristic edge'},
    {'id': 'oil_painting', 'label': '🖌️ Classical Oil', 'desc': 'Rich canvas brushstrokes'},
    {'id': '3d_render', 'label': '💎 3D Cinematic', 'desc': 'Unreal Engine lighting'},
  ];

  final List<String> _promptEnhancers = [
    'Piercing eyes',
    'Rainy city background',
    'Candlelight shadows',
    'Tailored dark suit',
    'Velvet robes',
    'Messy hair',
    'Sharp jawline',
    'Tattoos along collarbone',
    'Golden hour lighting',
    'Subtle smirk',
    'Intense brooding gaze',
    'Freckles & gentle warmth',
  ];

  final List<String> _randomPromptSparks = [
    'Brooding billionaire with dark swept-back hair, piercing silver-gray eyes, razor-sharp jawline, standing in a rain-drenched penthouse in a tailored charcoal suit.',
    'Silver-haired high-fae prince with luminous amethyst eyes, dressed in midnight-blue velvet robes with silver embroidery, surrounded by glowing winter mist.',
    'Fierce mafia enforcer with athletic build, tousled black hair, sharp hazel eyes, delicate dark ink creeping up his throat, leather jacket in a dim alley.',
    'Brilliant academic heroine with messy auburn curls, warm amber eyes, round tortoiseshell spectacles, oversized cashmere sweater, holding an antique gold locket.',
    'Seductive vampire aristocrat with pale porcelain skin, crimson silk shirt, raven-black hair, enigmatic half-smile under amber chandelier light.',
    'Sun-kissed royal bodyguard with bronze skin, striking green eyes, unbuttoned white linen shirt, broad shoulders, standing by a sunlit palace balcony.',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.existingCharacter != null) {
      final char = widget.existingCharacter!;
      _nameController.text = char['name'] ?? '';
      _roleController.text = char['role'] ?? '';
      _genderController.text = char['gender'] ?? '';
      _personalityController.text = char['personality'] ?? '';
      _appearanceController.text = char['appearance'] ?? '';
      _relationshipController.text = char['relationship_status'] ?? '';
      _dialogueStyleController.text = char['dialogue_style'] ?? '';
      if (char['avatar_url'] != null && char['avatar_url'].toString().startsWith('data:image')) {
        final raw = char['avatar_url'].toString().split(',').last;
        _selectedBase64Image = raw;
      }
      if (_appearanceController.text.isNotEmpty) {
        _promptController.text = 'Portrait of ${_nameController.text}. ${_appearanceController.text}';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _genderController.dispose();
    _personalityController.dispose();
    _appearanceController.dispose();
    _relationshipController.dispose();
    _dialogueStyleController.dispose();
    super.dispose();
  }

  void _insertPromptSpark() {
    final spark = (_randomPromptSparks..shuffle()).first;
    setState(() {
      _promptController.text = spark;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Injected romantic character prompt spark!'), duration: Duration(seconds: 1)),
    );
  }

  void _appendTagToPrompt(String tag) {
    final current = _promptController.text.trim();
    setState(() {
      if (current.isEmpty) {
        _promptController.text = tag;
      } else {
        _promptController.text = '$current, $tag';
      }
    });
  }

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your character or tap "Surprise Me 🎲" first!')),
      );
      return;
    }

    setState(() => _isGeneratingImage = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await ApiService.generateImage(prompt, style: _selectedStyle);
      final b64 = res['base64_image'] as String?;

      if (b64 != null && b64.isNotEmpty) {
        setState(() {
          _selectedBase64Image = b64;
          _imageHistory.insert(0, {
            'b64': b64,
            'prompt': prompt,
            'style': _selectedStyle,
            'time': DateTime.now(),
          });
          // Update appearance field if blank
          if (_appearanceController.text.isEmpty) {
            _appearanceController.text = prompt;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Portrait generated! Like it or tweak your prompt and regenerate.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('No image data returned');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating portrait: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
      }
    }
  }

  Future<void> _autoFillProfileFromPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty && _selectedBase64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate or enter a character visual prompt first!')),
      );
      return;
    }

    setState(() => _isAutoFilling = true);
    try {
      final profile = await ApiService.suggestCharacterFromPrompt(
        prompt.isNotEmpty ? prompt : 'Striking mysterious romance protagonist',
        storyId: widget.storyId,
      );

      setState(() {
        if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
          _nameController.text = profile['name'];
        }
        if (profile['role'] != null && profile['role'].toString().isNotEmpty) {
          _roleController.text = profile['role'];
        }
        if (profile['gender'] != null && profile['gender'].toString().isNotEmpty) {
          _genderController.text = profile['gender'];
        }
        if (profile['personality'] != null && profile['personality'].toString().isNotEmpty) {
          _personalityController.text = profile['personality'];
        }
        if (profile['appearance'] != null && profile['appearance'].toString().isNotEmpty) {
          _appearanceController.text = profile['appearance'];
        }
        if (profile['relationship_status'] != null && profile['relationship_status'].toString().isNotEmpty) {
          _relationshipController.text = profile['relationship_status'];
        }
        if (profile['dialogue_style'] != null && profile['dialogue_style'].toString().isNotEmpty) {
          _dialogueStyleController.text = profile['dialogue_style'];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI synthesized character profile from the portrait!'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not auto-fill details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoFilling = false);
      }
    }
  }

  Future<void> _saveCharacter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a character name!')),
      );
      _tabController.animateTo(1);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': name,
        'role': _roleController.text.trim().isNotEmpty ? _roleController.text.trim() : 'Companion',
        'gender': _genderController.text.trim(),
        'personality': _personalityController.text.trim(),
        'appearance': _appearanceController.text.trim().isNotEmpty
            ? _appearanceController.text.trim()
            : _promptController.text.trim(),
        'relationship_status': _relationshipController.text.trim(),
        'dialogue_style': _dialogueStyleController.text.trim(),
        if (_selectedBase64Image != null) 'avatar_base64': _selectedBase64Image,
      };

      if (widget.existingCharacter != null && widget.existingCharacter!['id'] != null) {
        await ApiService.updateCharacter(
          widget.storyId,
          widget.existingCharacter!['id'].toString(),
          payload,
        );
      } else {
        await ApiService.createCharacter(widget.storyId, payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Character "$name" successfully created & added to story!'),
            backgroundColor: Colors.green[800],
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving character: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingCharacter != null ? 'Edit Character Portrait' : 'Character Visual Studio',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              '1. Prompt & Generate  ➔  2. Character Details',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              icon: const Icon(Icons.brush, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('1. Portrait Studio'),
                  if (_selectedBase64Image != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                  ],
                ],
              ),
            ),
            Tab(
              icon: const Icon(Icons.badge, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('2. Profile & Details'),
                  if (_nameController.text.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPortraitStudioTab(),
          _buildProfileDetailsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF18181F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          child: Row(
            children: [
              if (_tabController.index == 1)
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              if (_tabController.index == 1) const SizedBox(width: 12),
              Expanded(
                child: _tabController.index == 0
                    ? ElevatedButton.icon(
                        onPressed: _selectedBase64Image != null
                            ? () {
                                if (_appearanceController.text.isEmpty) {
                                  _appearanceController.text = _promptController.text;
                                }
                                _tabController.animateTo(1);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          _selectedBase64Image != null
                              ? 'Use Portrait & Fill Details ➔'
                              : 'Generate an Image to Proceed',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveCharacter,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isSaving ? 'Saving Character...' : 'Create Character & Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent[700],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: Portrait Studio
  Widget _buildPortraitStudioTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Prompt Input Header
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Character Visual Prompt',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _insertPromptSpark,
              icon: const Icon(Icons.casino_outlined, size: 16, color: Colors.amberAccent),
              label: const Text('Surprise Me 🎲', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Text prompt field
        TextField(
          controller: _promptController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Drop or describe your character\'s appearance, hair, eyes, clothes, posture, and lighting...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            suffixIcon: _promptController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                    onPressed: () => setState(() => _promptController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Art Style Selection
        const Text(
          'ART STYLE PRESET',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _styleOptions.map((opt) {
              final isSelected = _selectedStyle == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  selectedColor: Colors.amber,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedStyle = opt['id']!);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Tag Suggestions
        const Text(
          'TAP TO ADD DETAIL CHIPS',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _promptEnhancers.map((tag) {
            return ActionChip(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              label: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              onPressed: () => _appendTagToPrompt(tag),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Generate / Regenerate Button
        ElevatedButton.icon(
          onPressed: _isGeneratingImage ? null : _generateImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedBase64Image != null ? Colors.orange[800] : Colors.amber[700],
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isGeneratingImage
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Icon(_selectedBase64Image != null ? Icons.refresh : Icons.auto_awesome),
          label: Text(
            _isGeneratingImage
                ? 'Creating Character Portrait...'
                : _selectedBase64Image != null
                    ? 'Regenerate Portrait with Updated Prompt'
                    : 'Generate Character Portrait',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 20),

        // Main Image Preview Area
        if (_selectedBase64Image != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Selected Portrait',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedStyle.toUpperCase(),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.memory(
                      base64Decode(_selectedBase64Image!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Prompt fine-tuning suggestions
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Not quite what you wanted? Tweak the prompt above and tap "Regenerate". You can also pick from previous attempts below.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildQuickTweakChip('+ Softer smile', 'with a gentle subtle smile'),
                          _buildQuickTweakChip('+ Darker lighting', 'moody shadows, low rim lighting'),
                          _buildQuickTweakChip('+ Intenser gaze', 'intense piercing eye contact'),
                          _buildQuickTweakChip('+ Silver hair', 'silver-white streaks in hair'),
                          _buildQuickTweakChip('+ Closer portrait', 'close-up cinematic face portrait'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // History Reel
        if (_imageHistory.length > 1) ...[
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Previous Generated Attempts (${_imageHistory.length})',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageHistory.length,
              itemBuilder: (context, i) {
                final item = _imageHistory[i];
                final b64 = item['b64'] as String;
                final isSelected = _selectedBase64Image == b64;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBase64Image = b64;
                      _promptController.text = item['prompt'] ?? '';
                    });
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.white24,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(b64),
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 12, color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildQuickTweakChip(String label, String modifier) {
    return ActionChip(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      label: Text(label, style: const TextStyle(color: Colors.amberAccent, fontSize: 10)),
      onPressed: () {
        _appendTagToPrompt(modifier);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$modifier" to prompt. Tap Regenerate to see results!'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  // TAB 2: Profile & Details
  Widget _buildProfileDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Portrait preview chip & Auto-fill button
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.amber[800],
                backgroundImage: _selectedBase64Image != null
                    ? MemoryImage(base64Decode(_selectedBase64Image!))
                    : null,
                child: _selectedBase64Image == null
                    ? const Icon(Icons.person, size: 36, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBase64Image != null ? 'Portrait Selected' : 'No Portrait Yet',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _tabController.animateTo(0),
                      icon: const Icon(Icons.photo_camera, size: 14, color: Colors.amber),
                      label: const Text('Change Portrait', style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isAutoFilling ? null : _autoFillProfileFromPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isAutoFilling
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Auto-Fill AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Character Name Field
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Character Name *',
            labelStyle: const TextStyle(color: Colors.amber),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.casino, color: Colors.amber),
              tooltip: 'Generate Name',
              onSelected: (value) {
                if (value == 'Fantasy') {
                  _nameController.text = NameGenerator.generateFantasyName();
                } else if (value == 'Sci-Fi') {
                  _nameController.text = NameGenerator.generateSciFiName();
                } else {
                  _nameController.text = NameGenerator.generateModernName();
                }
                setState(() {});
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Modern', child: Text('Modern Romance Name')),
                PopupMenuItem(value: 'Fantasy', child: Text('Fantasy / Fae Name')),
                PopupMenuItem(value: 'Sci-Fi', child: Text('Sci-Fi / Futuristic Name')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Role / Archetype
        TextField(
          controller: _roleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Role / Archetype',
            hintText: 'e.g., Protagonist, Love Interest, Dark Mafia Heir, Royal Bodyguard',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'Love Interest',
              'Protagonist',
              'Rival / Enemy',
              'Secret Protector',
              'Billionaire CEO',
              'Royal Bodyguard',
              'Best Friend',
            ].map((role) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ActionChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  label: Text(role, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  onPressed: () => setState(() => _roleController.text = role),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Gender & Relationship Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _genderController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  hintText: 'Male / Female / etc.',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _relationshipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Relationship to Lead',
                  hintText: 'e.g., Forbidden flame',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Personality
        TextField(
          controller: _personalityController,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Personality & Flaws',
            hintText: 'e.g., Guarded, fiercely protective, dry cynical humor, hides intense vulnerability',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        // Appearance Description
        TextField(
          controller: _appearanceController,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Physical Appearance Notes',
            hintText: 'Hair color, eye color, height, distinctive marks, style',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        // Dialogue Style
        TextField(
          controller: _dialogueStyleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Dialogue & Speech Style',
            hintText: 'e.g., Deep husky cadence, deliberate pauses, teasing smirk in banter',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
