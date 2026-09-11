import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  final _titleController = TextEditingController();
  final _synopsisController = TextEditingController();
  
  // User Persona fields for this story
  final _personaNameController = TextEditingController();
  final _personaAgeController = TextEditingController();
  final _personaAppearanceController = TextEditingController();
  final _personaPersonalityController = TextEditingController();
  final _personaBackstoryController = TextEditingController();
  
  String _selectedGenre = 'Romance';
  String _selectedSubgenre = 'CEO Romance';
  String _selectedTone = '🎭 Comedy & Banter (Witty Banter, Romantic Comedy, Slapstick & Humor)';
  
  final _genres = ['Romance', 'Erotica', 'Dark Romance', 'Paranormal Romance', 'Contemporary Romance', 'Harem / Reverse Harem', 'Omegaverse', 'Married Life Romance', 'Taboo Romance', 'Cultural/Religious Romance', 'Fantasy', 'Sci-Fi', 'Mystery', 'Thriller', 'Horror', 'Cyberpunk', 'Post-Apocalyptic', 'Slice of Life', 'Historical Fiction', 'Daughter'];
  final _subgenres = ['CEO Romance', 'Enemies to Lovers', 'Fake Dating', 'Grumpy x Sunshine', 'Second Chance Romance', 'Slow Burn', 'Mafia Romance', 'Historical Romance', 'Royal / Aristocracy', 'Family Dynamics', 'Step-Family Taboo', 'Age Gap', 'Teacher / Student', 'Forbidden Romance', 'Mom & Son', 'Brother & Sister', 'Step-Mom', 'Step-Sister', 'Master & Slave', 'BDSM / Submissive', 'Bully Romance', 'Stalker Romance', 'Bodyguard Romance', 'Assassin / Hitman', 'Billionaire Romance', 'Werewolf / Shifter', 'Vampire Romance', 'Demon / Angel', 'Monster Romance', 'Tentacle Romance', 'College Romance', 'Office Romance', 'Friends to Lovers', 'Arranged Marriage', 'Forced Marriage', 'Wife', 'Inter-religion Love', 'Inter-religion Marriage', 'Secret Baby / Pregnancy', 'Polyamory', 'Cuckolding', 'Daughter', 'Father / Daughter'];
  final _tones = [
    '🎭 Comedy & Banter (Witty Banter, Romantic Comedy, Slapstick & Humor)',
    '⚡ High Action & Adventure (Action-Packed, High-Stakes Battles, Martial Arts)',
    '❤️‍🔥 Flirty & Flattery (Flirty & Charming, Playful Teasing, Sweet Seduction)',
    '🖤 Dark & Taboo (Dark Fantasy, Taboo Romance, Gritty Realism, Gothic)',
    '🕵️ Mystery & Thriller (Suspenseful, Psychological Thriller, Noir Detective)',
    '🌸 Wholesome & Slice of Life (Cozy & Comforting, Heartfelt, Sweet & Vanilla)',
    '👑 Royal & High Society (Palace Intrigue, Aristocratic Court Drama, Throne Rivals)',
    '🐉 Epic Fantasy & Mythology (Magic & Sorcery, Gods & Deities, Dragon Realm)',
    '🚀 Sci-Fi & Cyberpunk (Futuristic Cyberpunk, Space Opera, AI Romance)',
    '🐺 Supernatural & Shifters (Alpha Pack, Vampire Clan, Demon/Angel Wars)',
    '🗡️ Revenge & Anti-Hero (Vengeance Arc, Dark Mastermind, Betrayal & Power)',
    '🏫 Academy & Campus (Magic Academy, Elite University, Campus Rivalry)',
    '💋 Mafia & Underworld (Dark Mafia Empire, Crime Syndicate, Obsession)',
    '🏝️ Isekai & Reincarnation (Transmigration, Reborn as Villainess, LitRPG)',
    '💍 Arranged Marriage & Forced Proximity (Contract Marriage, Trapped Together)',
    '🔥 Erotic & Dynamic Roles (Dominant/Submissive, Master/Servant, Bondage)',
    '⏳ Time Travel & Timelines (Time Loop, Butterfly Effect, Time Paradox)',
    '🦸 Superhero & Vigilante (Superpowers, Secret Identity, Masked Vigilante)',
    '⛵ Pirates & High Seas (Pirate Crew, High Seas Adventure, Siren Mythos)',
    '🎪 Horror & Survival (Supernatural Horror, Zombie Apocalypse, Deadly Game)',
    'Passionate',
    'Dark & Steamy',
    'Lighthearted & Sweet',
    'Dramatic & Angsty',
  ];

  bool _isSaving = false;

  Future<void> _createStory() async {
    setState(() => _isSaving = true);
    try {
      final storyData = <String, dynamic>{
        'title': _titleController.text,
        'synopsis': _synopsisController.text,
        'genre': _selectedGenre,
        'subgenre': _selectedSubgenre,
        'tone': _selectedTone,
      };
      
      if (_personaNameController.text.trim().isNotEmpty) {
        storyData['user_persona_name'] = _personaNameController.text.trim();
      }
      if (_personaAgeController.text.trim().isNotEmpty) {
        storyData['user_persona_age'] = int.tryParse(_personaAgeController.text.trim());
      }
      if (_personaAppearanceController.text.trim().isNotEmpty) {
        storyData['user_persona_appearance'] = _personaAppearanceController.text.trim();
      }
      if (_personaPersonalityController.text.trim().isNotEmpty) {
        storyData['user_persona_personality'] = _personaPersonalityController.text.trim();
      }
      if (_personaBackstoryController.text.trim().isNotEmpty) {
        storyData['user_persona_backstory'] = _personaBackstoryController.text.trim();
      }
      
      await ApiService.createStory(storyData);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Story')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Story Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _synopsisController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Synopsis / Premise', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGenre,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                  items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (v) => setState(() => _selectedGenre = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSubgenre,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subgenre / Romance Style', border: OutlineInputBorder()),
                  items: _subgenres.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (v) => setState(() => _selectedSubgenre = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTone,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tone / Emotional Intensity', border: OutlineInputBorder()),
                  items: _tones.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (v) => setState(() => _selectedTone = v!),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Your Character / Persona in this Story (Optional)'),
                    subtitle: const Text('Define who you play as in this specific story world'),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _personaNameController,
                              decoration: const InputDecoration(labelText: 'Your Character Name', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _personaAgeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _personaAppearanceController,
                        decoration: const InputDecoration(labelText: 'Appearance (hair, eyes, style)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _personaPersonalityController,
                        decoration: const InputDecoration(labelText: 'Personality Traits', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _personaBackstoryController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Role / Backstory in Story', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _createStory,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving ? const CircularProgressIndicator() : const Text('Initialize Story World', style: TextStyle(fontSize: 18)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
