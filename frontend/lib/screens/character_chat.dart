import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../api.dart';
import '../widgets/romance_features_dialogs.dart';
import '../widgets/character_memory_vault_sheet.dart';
import '../widgets/vintage_mailbox_sheet.dart';
import '../widgets/shared_dream_sheet.dart';
import '../widgets/domestic_bliss_sheet.dart';
import '../widgets/candid_camera_roll_sheet.dart';
import '../widgets/vhs_memory_clips_sheet.dart';
import '../widgets/story_romance_boutique_sheet.dart';
import '../widgets/photobooth_strip_sheet.dart';
import '../widgets/room_inspection_sheet.dart';
import '../widgets/dynamic_weather_overlay.dart';
import '../widgets/ambience_weather_sheet.dart';
import '../widgets/secret_locked_diary_sheet.dart';
import '../services/ambient_sound_service.dart';
import '../services/real_world_sync_service.dart';
import '../services/character_voice_service.dart';
import '../services/notification_service.dart';
import '../widgets/character_voice_settings_sheet.dart';
import '../widgets/chat_background_picker_sheet.dart';

class CharacterChatScreen extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String? backgroundImage;

  const CharacterChatScreen({
    super.key,
    required this.characterId,
    required this.characterName,
    this.backgroundImage,
  });

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> with WidgetsBindingObserver {
  final CharacterVoiceService _voiceService = CharacterVoiceService();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isImmersionMode = false;
  bool _showBackgroundImage = true;
  String? _activeBackgroundPath;
  double _backgroundDimOpacity = 0.6;
  List<String> _suggestions = [];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Phase 3 State
  int _intimacyScore = 0;
  String _currentTheme = 'Dark Mode';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;
  final String _ambientUrl = 'https://cdn.pixabay.com/download/audio/2022/02/07/audio_c394c86121.mp3'; // Public domain fire sound

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceService.removeListener(_onVoiceUpdate);
    _voiceService.stop();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceService.addListener(_onVoiceUpdate);
    _loadChat();
    _loadCustomBackgroundPreferences();
  }

  Future<void> _loadCustomBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString('active_bg_${widget.characterId}');
    final dim = prefs.getDouble('bg_dim_${widget.characterId}') ?? 0.6;
    if (mounted) {
      setState(() {
        _activeBackgroundPath = active ?? widget.backgroundImage;
        _backgroundDimOpacity = dim;
      });
    }
  }

  void _openWallpaperPicker() {
    ChatBackgroundPickerSheet.show(
      context,
      characterId: widget.characterId,
      characterName: widget.characterName,
      defaultAvatarBase64: widget.backgroundImage,
      currentBackground: _activeBackgroundPath,
      currentDim: _backgroundDimOpacity,
      onBackgroundSelected: (newBg, newDim) {
        setState(() {
          _activeBackgroundPath = newBg;
          _backgroundDimOpacity = newDim;
          _showBackgroundImage = true;
        });
      },
    );
  }

  ImageProvider? _resolveBackgroundImage() {
    if (!_showBackgroundImage) return null;
    final bg = _activeBackgroundPath ?? widget.backgroundImage;
    if (bg == null || bg.isEmpty) return null;

    if (bg.startsWith('http://') || bg.startsWith('https://')) {
      return NetworkImage(bg);
    }
    final file = File(bg);
    if (file.existsSync()) {
      return FileImage(file);
    }
    try {
      return MemoryImage(base64Decode(bg));
    } catch (_) {
      return null;
    }
  }

  void _onVoiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _scheduleSpontaneousPingOnBackground();
    }
  }

  Future<void> _scheduleSpontaneousPingOnBackground() async {
    try {
      final hour = DateTime.now().hour;
      final timeDesc = hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : hour < 22 ? 'Evening' : 'Late Night';
      Future.delayed(const Duration(seconds: 15), () async {
        try {
          final ping = await ApiService.getProactiveNotification(
            widget.characterId,
            localTimeStr: timeDesc,
          );
          await NotificationService().showCharacterPing(
            id: widget.characterId.hashCode,
            title: ping['notification_title'] ?? widget.characterName,
            body: ping['notification_body'] ?? 'Thinking about you right now...',
            subtext: ping['subtext'] ?? '1-on-1 Whisper',
            payloadData: {
              'character_id': widget.characterId,
              'character_name': widget.characterName,
              'avatar_base64': widget.backgroundImage,
            },
          );
        } catch (e) {
          debugPrint('Background proactive ping error: $e');
        }
      });
    } catch (e) {
      debugPrint('Schedule ping error: $e');
    }
  }

  Future<void> _loadChat() async {
    try {
      final msgs = await ApiService.getCharacterChat(widget.characterId);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _isSending = true;
      _messages.add({'message': text, 'is_ai': false, 'created_at': DateTime.now().toIso8601String()});
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final ambientService = AmbientSoundService();
      final realityService = RealWorldSyncService.instance;
      final msgs = await ApiService.chatWithCharacter(
        widget.characterId, 
        text,
        ambientWeather: ambientService.effectiveWeather,
        localTimeDesc: ambientService.localTimeDesc,
        realWorldContext: realityService.fullRealityContext,
      );
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
      if (_voiceService.autoVoiceEnabled && msgs.isNotEmpty) {
        final last = msgs.last;
        if (last['is_ai'] == true || last['is_ai'] == 1) {
          final msgText = last['message']?.toString() ?? '';
          final msgId = last['id']?.toString() ?? 'last';
          _voiceService.playDialogue(
            characterId: widget.characterId,
            text: msgText,
            messageId: msgId,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _requestSelfie() async {
    final promptController = TextEditingController();
    final customPrompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a Photo'),
        content: TextField(
          controller: promptController,
          decoration: const InputDecoration(
            hintText: '(Optional) E.g. wearing a red dress, smiling...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, promptController.text), child: const Text('Request')),
        ],
      ),
    );

    if (customPrompt == null) return; // cancelled

    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.requestSelfie(widget.characterId, customPrompt: customPrompt);
      setState(() {
        _messages = msgs;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _continueChat() async {
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.continueChat(widget.characterId);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _generateThought() async {
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.getCharacterThought(widget.characterId);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _regenerateChat() async {
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.regenerateChat(widget.characterId);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _restartChat() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Chat'),
        content: const Text('Are you sure you want to delete all messages and start over?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restart', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      await ApiService.clearChat(widget.characterId);
      setState(() {
        _messages.clear();
        _isSending = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _getSuggestions() async {
    if (_suggestions.isNotEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    setState(() => _isSending = true);
    try {
      final sugs = await ApiService.getChatSuggestions(widget.characterId);
      setState(() {
        _suggestions = sugs;
        _isSending = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Delete Message?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteChatMessage(widget.characterId, id);
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _insertEmotionalAction(String actionText) {
    if (_msgController.text.trim().isEmpty) {
      _msgController.text = actionText;
    } else {
      _msgController.text = "${_msgController.text.trim()} $actionText";
    }
    _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
  }

  Future<void> _regenerate() async {
    if (_messages.isEmpty) return;
    setState(() => _isSending = true);
    
    try {
      final msgs = await ApiService.regenerateChat(widget.characterId);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error regenerating: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _downloadImage() async {
    if (widget.backgroundImage == null) return;
    try {
      final bytes = base64Decode(widget.backgroundImage!);
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: 'character_${widget.characterId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to Gallery')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
      }
    }
  }

  void _showContextMenu(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white),
                title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg['message']));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.fast_rewind, color: Colors.redAccent),
                title: const Text('Rewind to Here', style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('Deletes this message and everything after it', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRewind(msg);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showEditDialog(Map<String, dynamic> msg) {
    final editController = TextEditingController(text: msg['message']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.editChatMessage(widget.characterId, msg['id'], editController.text);
                Navigator.pop(context);
                _loadChat();
              } catch(e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error editing: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRewind(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rewind Story?'),
        content: const Text('This will delete the selected message and ALL messages that come after it. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.rewindChat(widget.characterId, msg['id']);
                Navigator.pop(context);
                _loadChat();
              } catch(e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rewinding: $e')));
              }
            },
            child: const Text('Rewind', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _viewDiary() {
    SecretLockedDiarySheet.show(
      context,
      characterId: widget.characterId,
      characterName: widget.characterName,
      intimacyScore: _intimacyScore,
      avatarBase64: widget.backgroundImage,
    );
  }

  Future<void> _showIntimacyMilestones() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Loading intimacy milestones...'),
          ],
        ),
      ),
    );

    try {
      final unlocksList = await ApiService.getCharacterUnlocks(widget.characterId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final Map<int, dynamic> claimed = {};
      for (var u in unlocksList) {
        if (u['milestone_level'] != null) {
          claimed[u['milestone_level'] as int] = u;
        }
      }

      final milestones = [
        {'level': 25, 'title': 'Level 25: Secret Backstory Note 🟢', 'type': 'Friendly'},
        {'level': 50, 'title': 'Level 50: Private Diary Entry 🟣', 'type': 'Close Ally'},
        {'level': 75, 'title': 'Level 75: Intimate Side-Quest Scenario 🔴', 'type': 'Romantic'},
        {'level': 100, 'title': 'Level 100: Exclusive Hidden Chapter 👑', 'type': 'Devoted'},
      ];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E1E2C),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.characterName}\'s Intimacy Unlocks',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (_intimacyScore >= 100) ? 1.0 : (_intimacyScore / 100.0),
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Intimacy: $_intimacyScore / 100',
                      style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: milestones.length,
                        itemBuilder: (context, idx) {
                          final m = milestones[idx];
                          final lvl = m['level'] as int;
                          final isUnlocked = _intimacyScore >= lvl;
                          final isClaimed = claimed.containsKey(lvl);

                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: Icon(
                                isClaimed
                                    ? Icons.mark_email_read
                                    : isUnlocked
                                        ? Icons.lock_open
                                        : Icons.lock,
                                color: isClaimed
                                    ? Colors.greenAccent
                                    : isUnlocked
                                        ? Colors.amber
                                        : Colors.grey,
                              ),
                              title: Text(
                                m['title'] as String,
                                style: TextStyle(
                                  color: isUnlocked ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                isClaimed
                                    ? 'Unlocked: ${claimed[lvl]['title']}'
                                    : isUnlocked
                                        ? 'Available to unlock!'
                                        : 'Reach Intimacy Level $lvl to unlock',
                                style: TextStyle(color: isUnlocked ? Colors.white70 : Colors.white38),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isClaimed
                                      ? Colors.deepPurple
                                      : isUnlocked
                                          ? Colors.pinkAccent
                                          : Colors.grey.shade800,
                                ),
                                onPressed: isUnlocked
                                    ? () async {
                                        if (isClaimed) {
                                          _showSecretDialog(claimed[lvl]['title'], claimed[lvl]['unlocked_content']);
                                        } else {
                                          try {
                                            final unlockData = await ApiService.claimCharacterUnlock(widget.characterId, lvl);
                                            claimed[lvl] = unlockData;
                                            setSheetState(() {});
                                            if (mounted) {
                                              _showSecretDialog(unlockData['title'], unlockData['unlocked_content']);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error claiming unlock: $e')));
                                            }
                                          }
                                        }
                                      }
                                    : null,
                                child: Text(
                                  isClaimed ? 'Read' : isUnlocked ? 'Unlock' : 'Locked',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading milestones: $e')));
      }
    }
  }

  void _showSecretDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(title, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied secret to clipboard!')));
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleAudio() async {
    if (_isAudioPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(UrlSource(_ambientUrl));
    }
    setState(() => _isAudioPlaying = !_isAudioPlaying);
  }

  Color get _aiBubbleColor {
    switch (_currentTheme) {
      case 'Cyberpunk': return Colors.purple[900]!;
      case 'Fantasy': return const Color(0xFF5C4033);
      case 'Romance': return Colors.pink[800]!;
      default: return Colors.grey[800]!;
    }
  }

  Color get _userBubbleColor {
    switch (_currentTheme) {
      case 'Cyberpunk': return Colors.cyan[900]!;
      case 'Fantasy': return const Color(0xFF3B4022);
      case 'Romance': return Colors.red[900]!;
      default: return Colors.blue[900]!;
    }
  }

  Color get _bgColor {
    switch (_currentTheme) {
      case 'Cyberpunk': return const Color(0xFF0F0F1A);
      case 'Fantasy': return const Color(0xFF2C2214);
      case 'Romance': return const Color(0xFF3B1A24);
      default: return Theme.of(context).scaffoldBackgroundColor;
    }
  }

  Color get _headerColor {
    switch (_currentTheme) {
      case 'Cyberpunk': return const Color(0xFF131322);
      case 'Fantasy': return const Color(0xFF281E12);
      case 'Romance': return const Color(0xFF38141F);
      default: return const Color(0xFF14141E);
    }
  }

  String _sanitizeDisplayMessage(dynamic raw) {
    if (raw == null) return '';
    return raw.toString().replaceAll(RegExp(r'\[.*?INTIMACY.*?\]', caseSensitive: false), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: _bgColor,
      appBar: _isImmersionMode ? null : AppBar(
        backgroundColor: _headerColor,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black54,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.backgroundImage != null && widget.backgroundImage!.isNotEmpty) ...[
              CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white12,
                backgroundImage: widget.backgroundImage!.startsWith('http')
                    ? NetworkImage(widget.backgroundImage!)
                    : MemoryImage(base64Decode(widget.backgroundImage!)) as ImageProvider,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.characterName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${RealWorldSyncService.instance.displayLocation}${RealWorldSyncService.instance.temperatureDisplay.isNotEmpty ? ' • ${RealWorldSyncService.instance.temperatureDisplay}' : ''}',
                          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: LinearProgressIndicator(
            value: (_intimacyScore >= 100) ? 1.0 : (_intimacyScore / 100.0),
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
               _intimacyScore < 25 ? Colors.lightBlue : _intimacyScore < 50 ? Colors.green : _intimacyScore < 75 ? Colors.orange : Colors.pink,
            ),
          ),
        ),
        actions: [
          // 1. Intimacy score badge
          GestureDetector(
            onTap: _showIntimacyMilestones,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.pinkAccent.withOpacity(0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$_intimacyScore',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          // 2. Direct voice audio button
          IconButton(
            icon: Icon(
              _voiceService.isPlaying
                  ? Icons.graphic_eq
                  : (_voiceService.autoVoiceEnabled ? Icons.volume_up : Icons.record_voice_over),
              color: _voiceService.isPlaying
                  ? Colors.pinkAccent
                  : (_voiceService.autoVoiceEnabled ? Colors.pinkAccent : Colors.tealAccent),
              size: 22,
            ),
            tooltip: 'Neural Voice & Spontaneous Whispers 🎙️',
            onPressed: () => CharacterVoiceSettingsSheet.show(
              context,
              characterId: widget.characterId,
              characterName: widget.characterName,
              avatarBase64: widget.backgroundImage,
            ),
          ),
          // 3. Full Features 3-Dots Menu Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            tooltip: 'All Features & Options',
            onSelected: (String choice) {
              if (choice == 'Change Wallpaper') {
                _openWallpaperPicker();
              } else if (choice == 'Voice Settings') {
                CharacterVoiceSettingsSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Diary') {
                SecretLockedDiarySheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  intimacyScore: _intimacyScore,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Voicemails') {
                CharacterVoicemailsSheet.show(context, {
                  'id': widget.characterId,
                  'name': widget.characterName,
                });
              } else if (choice == 'Mailbox') {
                VintageMailboxSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Dreamworld') {
                SharedDreamSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Memory Vault') {
                CharacterMemoryVaultSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Weather') {
                AmbienceWeatherSheet.show(context);
              } else if (choice == 'Domestic Bliss') {
                DomesticBlissSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Candid Selfies') {
                CandidCameraRollSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'VHS Tape') {
                VhsMemoryClipsSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Boutique Gifts') {
                StoryRomanceBoutiqueSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                  onGiftGiven: _loadChat,
                );
              } else if (choice == 'Photobooth Strip') {
                PhotoboothStripSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Inspect Sanctuary') {
                RoomInspectionSheet.show(
                  context,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarBase64: widget.backgroundImage,
                );
              } else if (choice == 'Intimacy Unlocks') {
                _showIntimacyMilestones();
              } else if (choice == 'Toggle Audio') {
                _toggleAudio();
              } else if (choice == 'Toggle Background') {
                setState(() => _showBackgroundImage = !_showBackgroundImage);
              } else if (choice == 'Download Image') {
                _downloadImage();
              } else if (choice == 'Clear Chat') {
                _restartChat();
              } else if (choice.startsWith('Theme:')) {
                setState(() => _currentTheme = choice.split(': ')[1]);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'Change Wallpaper',
                  child: Row(
                    children: [
                      Icon(Icons.wallpaper_rounded, color: Colors.pinkAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Chat Wallpapers 🖼️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                    ],
                  ),
                ),
                const PopupMenuItem(value: 'Voice Settings', child: Row(children: [Icon(Icons.record_voice_over, color: Colors.tealAccent, size: 20), SizedBox(width: 10), Text('Voice & Whispers 🎙️')])),
                const PopupMenuItem(value: 'Diary', child: Row(children: [Icon(Icons.menu_book, color: Color(0xFFFDE68A), size: 20), SizedBox(width: 10), Text('Secret Locked Diary 💌')])),
                const PopupMenuItem(value: 'Voicemails', child: Row(children: [Icon(Icons.mic, color: Colors.tealAccent, size: 20), SizedBox(width: 10), Text('Midnight Voicemails 🎙️')])),
                const PopupMenuItem(value: 'Mailbox', child: Row(children: [Icon(Icons.markunread_mailbox, color: Colors.amber, size: 20), SizedBox(width: 10), Text('Vintage Mailbox 📬')])),
                const PopupMenuItem(value: 'Dreamworld', child: Row(children: [Icon(Icons.nightlight_round, color: Colors.purpleAccent, size: 20), SizedBox(width: 10), Text('Shared Dreamworld 🌙')])),
                const PopupMenuItem(value: 'Memory Vault', child: Row(children: [Icon(Icons.psychology, color: Colors.cyanAccent, size: 20), SizedBox(width: 10), Text('Memory Vault & Feelings 🧠')])),
                const PopupMenuItem(value: 'Weather', child: Row(children: [Icon(Icons.cloudy_snowing, color: Color(0xFF38BDF8), size: 20), SizedBox(width: 10), Text('Atmosphere & Weather 🌦️')])),
                const PopupMenuItem(value: 'Domestic Bliss', child: Row(children: [Icon(Icons.cottage, color: Colors.orangeAccent, size: 20), SizedBox(width: 10), Text('Domestic Bliss 🏡')])),
                const PopupMenuItem(value: 'Candid Selfies', child: Row(children: [Icon(Icons.camera_alt, color: Colors.pinkAccent, size: 20), SizedBox(width: 10), Text('Candid Camera Roll 📸')])),
                const PopupMenuItem(value: 'VHS Tape', child: Row(children: [Icon(Icons.videocam, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('VHS Camcorder Vault 📹')])),
                const PopupMenuItem(value: 'Boutique Gifts', child: Row(children: [Icon(Icons.card_giftcard, color: Colors.amberAccent, size: 20), SizedBox(width: 10), Text('Romance Boutique 🛍️')])),
                const PopupMenuItem(value: 'Photobooth Strip', child: Row(children: [Icon(Icons.crop_portrait, color: Colors.purpleAccent, size: 20), SizedBox(width: 10), Text('4-Cut Photobooth 🧳')])),
                const PopupMenuItem(value: 'Inspect Sanctuary', child: Row(children: [Icon(Icons.search, color: Colors.tealAccent, size: 20), SizedBox(width: 10), Text('Inspect Sanctuary 🔍')])),
                const PopupMenuItem(value: 'Intimacy Unlocks', child: Row(children: [Icon(Icons.stars, color: Colors.pinkAccent, size: 20), SizedBox(width: 10), Text('Intimacy Milestones 🌟')])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'Toggle Audio', child: Row(children: [Icon(_isAudioPlaying ? Icons.volume_off : Icons.volume_up, size: 20), const SizedBox(width: 10), Text(_isAudioPlaying ? 'Mute Audio' : 'Play Ambient Sound')])),
                PopupMenuItem(value: 'Toggle Background', child: Row(children: [Icon(_showBackgroundImage ? Icons.image_not_supported : Icons.image, size: 20), const SizedBox(width: 10), Text(_showBackgroundImage ? 'Hide Background' : 'Show Background')])),
                if (widget.backgroundImage != null) const PopupMenuItem(value: 'Download Image', child: Row(children: [Icon(Icons.download, size: 20), SizedBox(width: 10), Text('Download Avatar')])),
                const PopupMenuItem(value: 'Clear Chat', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('Clear Chat History 🧹', style: TextStyle(color: Colors.redAccent))])),
                const PopupMenuDivider(),
                ...['Dark Mode', 'Cyberpunk', 'Fantasy', 'Romance'].map((t) => PopupMenuItem(value: 'Theme: $t', child: Text('Theme: $t'))),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onDoubleTap: () => setState(() => _isImmersionMode = !_isImmersionMode),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: _resolveBackgroundImage() != null
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: _resolveBackgroundImage()!,
                          fit: BoxFit.cover,
                          colorFilter: _isImmersionMode
                              ? null
                              : ColorFilter.mode(
                                  Colors.black.withOpacity(_backgroundDimOpacity),
                                  BlendMode.darken,
                                ),
                        ),
                      )
                    : null, // Note: For Cyberpunk/Fantasy/Romance, we can also tint this if background is null
                child: DynamicWeatherOverlay(
                  child: Column(
                    children: [
                      if (!_isImmersionMode)
                        Expanded(
                        child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isAi = msg['is_ai'] == true || msg['is_ai'] == 1;
                          return Align(
                            alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                if (isAi)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                                    child: Text(
                                      widget.characterName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () {
                                    if (msg['id'] != null) {
                                      _showContextMenu(msg);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    decoration: BoxDecoration(
                                      color: isAi ? _aiBubbleColor : _userBubbleColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: (msg['is_image'] == true || msg['is_image'] == 1) && msg['image_url'] != null
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => Dialog(
                                                      backgroundColor: Colors.transparent,
                                                      insetPadding: EdgeInsets.zero,
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          InteractiveViewer(
                                                            child: Image.network(
                                                              msg['image_url'],
                                                              fit: BoxFit.contain,
                                                              headers: const {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'},
                                                            ),
                                                          ),
                                                          Positioned(
                                                            top: 40, right: 20,
                                                            child: Row(
                                                              children: [
                                                                IconButton(
                                                                  icon: const Icon(Icons.download, color: Colors.white, size: 30),
                                                                  onPressed: () async {
                                                                    try {
                                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading image...')));
                                                                      final response = await http.get(
                                                                        Uri.parse(msg['image_url']),
                                                                        headers: const {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'},
                                                                      );
                                                                      final tempDir = await getTemporaryDirectory();
                                                                      final file = File('${tempDir.path}/downloaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                                                      await file.writeAsBytes(response.bodyBytes);
                                                                      await Gal.putImage(file.path);
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to Gallery!')));
                                                                      }
                                                                    } catch (e) {
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
                                                                      }
                                                                    }
                                                                  },
                                                                ),
                                                                const SizedBox(width: 8),
                                                                IconButton(
                                                                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                                  onPressed: () => Navigator.pop(context),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    msg['image_url'],
                                                    height: 250,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    headers: const {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'},
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return SizedBox(
                                                        height: 250,
                                                        child: Center(
                                                          child: CircularProgressIndicator(
                                                            value: loadingProgress.expectedTotalBytes != null
                                                                ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                                                : null,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                                                      height: 250,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.error_outline, color: Colors.red, size: 40),
                                                            SizedBox(height: 8),
                                                            Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              MarkdownBody(
                                                data: _sanitizeDisplayMessage(msg['message']),
                                                styleSheet: MarkdownStyleSheet(
                                                  p: const TextStyle(color: Colors.white, fontSize: 15),
                                                  em: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                            ],
                                          )
                                        : MarkdownBody(
                                            data: _sanitizeDisplayMessage(msg['message']),
                                            styleSheet: MarkdownStyleSheet(
                                              p: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                              em: const TextStyle(
                                                color: Colors.white70,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (msg['id'] != null && !_isImmersionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(onTap: () => _showEditDialog(msg), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit, size: 18, color: Colors.white70))),
                                        InkWell(onTap: () => _confirmRewind(msg), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.fast_rewind, size: 18, color: Colors.white70))),
                                        InkWell(onTap: () => _deleteMessage(msg['id']), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.delete, size: 18, color: Colors.redAccent))),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isSending)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: LinearProgressIndicator(),
                      ),
                    if (!_isImmersionMode)
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.black.withOpacity(0.5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_suggestions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Wrap(
                                  spacing: 8,
                                  children: _suggestions.map((s) => ActionChip(
                                    label: Text(s, style: const TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      _msgController.text = s;
                                      _sendMessage();
                                      setState(() => _suggestions.clear());
                                    },
                                  )).toList(),
                                ),
                              ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Continue'), onPressed: _isSending ? null : _continueChat),
                                  TextButton.icon(icon: const Icon(Icons.lightbulb, size: 16), label: const Text('Suggest'), onPressed: _isSending ? null : _getSuggestions),
                                  TextButton.icon(icon: const Icon(Icons.psychology, size: 16), label: const Text('Thought'), onPressed: _isSending ? null : _generateThought),
                                  TextButton.icon(icon: const Icon(Icons.refresh, size: 16), label: const Text('Regenerate'), onPressed: _isSending ? null : _regenerateChat),
                                  TextButton.icon(
                                    icon: const Icon(Icons.wallpaper, size: 16, color: Colors.cyanAccent),
                                    label: const Text('Wallpaper 🖼️', style: TextStyle(color: Colors.cyanAccent)),
                                    onPressed: _openWallpaperPicker,
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.pinkAccent),
                                    label: const Text('Photo 📸', style: TextStyle(color: Colors.pinkAccent)),
                                    onPressed: () => CandidCameraRollSheet.show(
                                      context,
                                      characterId: widget.characterId,
                                      characterName: widget.characterName,
                                      avatarBase64: widget.backgroundImage,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.card_giftcard, size: 16, color: Colors.amberAccent),
                                    label: const Text('Gift 🛍️', style: TextStyle(color: Colors.amberAccent)),
                                    onPressed: () => StoryRomanceBoutiqueSheet.show(
                                      context,
                                      characterId: widget.characterId,
                                      characterName: widget.characterName,
                                      avatarBase64: widget.backgroundImage,
                                      onGiftGiven: _loadChat,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.videocam, size: 16, color: Colors.redAccent),
                                    label: const Text('VHS 📹', style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () => VhsMemoryClipsSheet.show(
                                      context,
                                      characterId: widget.characterId,
                                      characterName: widget.characterName,
                                      avatarBase64: widget.backgroundImage,
                                    ),
                                  ),
                                  TextButton.icon(icon: const Icon(Icons.restart_alt, size: 16, color: Colors.red), label: const Text('Restart', style: TextStyle(color: Colors.red)), onPressed: _isSending ? null : _restartChat),
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(top: 4.0, bottom: 6.0),
                              child: Row(
                                children: [
                                  const Text('✨ Emotion: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                                  ...[
                                    {'label': 'Smile', 'icon': '😊', 'action': '*smiles warmly at you*'},
                                    {'label': 'Laugh', 'icon': '😄', 'action': '*lets out a soft, amused laugh*'},
                                    {'label': 'Chuckle', 'icon': '😏', 'action': '*chuckles under breath and steps closer*'},
                                    {'label': 'Bite Lip', 'icon': '🫦', 'action': '*bites lower lip in quiet hesitation*'},
                                    {'label': 'Blush', 'icon': '😳', 'action': '*flushes warmly, looking away for a second*'},
                                    {'label': 'Whisper', 'icon': '💬', 'action': '*whispers softly near your ear*'},
                                    {'label': 'Gasp', 'icon': '😮', 'action': '*gasps softly as breath catches*'},
                                    {'label': 'Touch Hand', 'icon': '🤝', 'action': '*gently brushes fingers against yours*'},
                                    {'label': 'Embrace', 'icon': '🫂', 'action': '*pulls you into a warm, lingering embrace*'},
                                  ].map((em) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: ActionChip(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                        avatar: Text(em['icon']!, style: const TextStyle(fontSize: 12)),
                                        label: Text(em['label']!, style: const TextStyle(fontSize: 11)),
                                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                                        onPressed: () => _insertEmotionalAction(em['action']!),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _msgController,
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      filled: true,
                                      fillColor: Colors.grey[900],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Colors.pinkAccent,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                                      onPressed: _isSending ? null : _requestSelfie,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: IconButton(
                                      icon: const Icon(Icons.send, color: Colors.white),
                                      onPressed: _isSending ? null : _sendMessage,
                                    ),
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
            ),
    );
  }
}
