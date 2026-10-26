import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../api.dart';
import '../widgets/dynamic_weather_overlay.dart';
import '../widgets/ambience_weather_sheet.dart';
import '../widgets/autonomous_gossip_sheet.dart';
import '../services/ambient_sound_service.dart';
import '../services/real_world_sync_service.dart';
import '../widgets/typing_indicator.dart';

class GroupChatScreen extends StatefulWidget {
  final String storyId;
  final String sessionId;
  final String? backgroundImage;

  const GroupChatScreen({
    super.key,
    required this.storyId,
    required this.sessionId,
    this.backgroundImage,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  List<dynamic> _messages = [];
  List<dynamic> _members = [];
  List<dynamic> _availableCharacters = [];
  String _sessionTitle = 'Tavern (Group Chat)';
  bool _isLoading = true;
  bool _isSending = false;
  bool _showBackgroundImage = true;
  String _currentTheme = 'Dark Mode';
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  final List<String> _quickSparks = [
    'Who caught your eye tonight? 😏',
    'Don\'t hold back—tell the truth.',
    'Stop glaring at each other! 🍷',
    'What were you two whispering about?',
    'Someone pour another drink 🥂',
    'Who here makes the rules? 👑',
    'Let\'s make this interesting...',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadChat();
    _loadMembers();
  }

  Future<void> _loadChat() async {
    try {
      final msgs = await ApiService.getGroupChatMessages(widget.sessionId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      final data = await ApiService.getGroupChatMembers(widget.sessionId);
      if (mounted) {
        setState(() {
          _members = data['members'] ?? [];
          _availableCharacters = data['available_characters'] ?? [];
          if (data['session'] != null && data['session']['title'] != null) {
            _sessionTitle = data['session']['title'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading group chat members: $e');
    }
  }

  Future<void> _addCharacterToChat(Map<String, dynamic> character) async {
    final currentIds = _members.map((m) => m['id'].toString()).toList();
    final newId = character['id'].toString();
    if (!currentIds.contains(newId)) {
      currentIds.add(newId);
    }

    try {
      await ApiService.updateGroupChatMembers(widget.sessionId, currentIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character['name']} entered the tavern!'),
            backgroundColor: Colors.amber[900],
          ),
        );
      }
      await _loadMembers();
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add character: $e')));
      }
    }
  }

  Future<void> _removeCharacterFromChat(Map<String, dynamic> character) async {
    if (_members.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one character must stay in the group chat!')),
      );
      return;
    }

    final currentIds = _members
        .map((m) => m['id'].toString())
        .where((id) => id != character['id'].toString())
        .toList();

    try {
      await ApiService.updateGroupChatMembers(widget.sessionId, currentIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${character['name']} stepped out of the tavern.')),
        );
      }
      await _loadMembers();
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove character: $e')));
      }
    }
  }

  void _showManageMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.groups_outlined, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Tavern Characters',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),

                      // In this chat
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'ACTIVE IN TAVERN (${_members.length})',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      if (_members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No active characters.', style: TextStyle(color: Colors.white54)),
                        )
                      else
                        ..._members.map((char) {
                          final avatar = char['avatar_url'] as String?;
                          return Card(
                            color: Colors.white.withValues(alpha: 0.05),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                backgroundColor: Colors.amber[700],
                                child: avatar == null || avatar.isEmpty
                                    ? Text(char['name']?[0] ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(
                                char['name'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                char['role'] ?? char['personality'] ?? 'Companion',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: _members.length > 1
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                      tooltip: 'Remove from group chat',
                                      onPressed: () async {
                                        await _removeCharacterFromChat(char);
                                        setModalState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          );
                        }),

                      const SizedBox(height: 16),

                      // Available to add
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              'ADD MORE CHARACTERS (${_availableCharacters.length})',
                              style: TextStyle(
                                color: Colors.blueAccent.withValues(alpha: 0.9),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_availableCharacters.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'All characters from this story are already in this Tavern!',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._availableCharacters.map((char) {
                          final avatar = char['avatar_url'] as String?;
                          return Card(
                            color: Colors.white.withValues(alpha: 0.04),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                backgroundColor: Colors.blueGrey,
                                child: avatar == null || avatar.isEmpty
                                    ? Text(char['name']?[0] ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(
                                char['name'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                char['role'] ?? char['personality'] ?? 'Story Character',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () async {
                                  await _addCharacterToChat(char);
                                  setModalState(() {});
                                },
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _messages.add({
        'message': text,
        'speaker_name': 'User',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (presetText == null) {
        _msgController.clear();
      }
    });
    _scrollToBottom();

    try {
      final ambientService = AmbientSoundService();
      final realityService = RealWorldSyncService.instance;
      final msgs = await ApiService.sendGroupChatMessage(
        widget.sessionId, 
        text,
        ambientWeather: ambientService.effectiveWeather,
        localTimeDesc: ambientService.localTimeDesc,
        realWorldContext: realityService.fullRealityContext,
      );
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _continueChat() async {
    setState(() => _isSending = true);
    try {
      final msgs = await ApiService.continueGroupChat(widget.sessionId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error continuing: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _regenerateChat() async {
    setState(() => _isSending = true);
    try {
      final msgs = await ApiService.regenerateGroupChat(widget.sessionId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error regenerating: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _restartChat() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Clear Tavern Messages', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete all messages in this group chat? The active characters will remain in the tavern.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isSending = true);
    try {
      await ApiService.clearGroupChat(widget.sessionId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing: $e')));
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
      await ApiService.deleteGroupChatMessage(widget.sessionId, id);
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting message: $e')));
      }
    }
  }

  Future<void> _rewindChat(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Rewind Chat', style: TextStyle(color: Colors.white)),
        content: const Text('Delete this message and ALL messages after it?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rewind', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.rewindGroupChat(widget.sessionId, id);
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rewinding: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _editMessage(Map<String, dynamic> msg) {
    final TextEditingController editController = TextEditingController(text: msg['message']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black38,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ApiService.editGroupChatMessage(widget.sessionId, msg['id'].toString(), editController.text);
                await _loadChat();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Error editing: $e')));
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
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

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isScrolledUp = (maxScroll - currentScroll) > 150;
    if (isScrolledUp != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isScrolledUp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (_currentTheme) {
      case 'Cyberpunk':
        bgColor = Colors.black87;
        textColor = Colors.cyanAccent;
        break;
      case 'Fantasy':
        bgColor = const Color(0xFF2C1E16);
        textColor = const Color(0xFFD4AF37);
        break;
      case 'Romance':
        bgColor = const Color(0xFF1F0D15);
        textColor = const Color(0xFFFFB6C1);
        break;
      case 'Dark Mode':
      default:
        bgColor = const Color(0xFF121212);
        textColor = Colors.white;
        break;
    }

    final memberNames = _members.map((m) => m['name'] as String? ?? 'Lead').toList();
    final memberSub = memberNames.isEmpty
        ? 'No members yet'
        : '${memberNames.take(3).join(', ')}${memberNames.length > 3 ? ' +${memberNames.length - 3}' : ''} (${_members.length})';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sessionTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              memberSub,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.hearing, color: Color(0xFFA78BFA)),
            tooltip: 'Overheard Hallway Whispers 👥',
            onPressed: () => AutonomousGossipSheet.show(
              context,
              storyId: widget.storyId,
              storyTitle: _sessionTitle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloudy_snowing, color: Color(0xFF38BDF8)),
            tooltip: 'Atmosphere & Ambience Soundscapes',
            onPressed: () => AmbienceWeatherSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.amber),
            tooltip: 'Add / Manage Characters',
            onPressed: _showManageMembersSheet,
          ),
          if (widget.backgroundImage != null)
            IconButton(
              icon: Icon(_showBackgroundImage ? Icons.image_not_supported : Icons.image),
              onPressed: () => setState(() => _showBackgroundImage = !_showBackgroundImage),
              tooltip: 'Toggle Background',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            onSelected: (value) => setState(() => _currentTheme = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Dark Mode', child: Text('Dark Mode')),
              PopupMenuItem(value: 'Cyberpunk', child: Text('Cyberpunk')),
              PopupMenuItem(value: 'Fantasy', child: Text('Fantasy')),
              PopupMenuItem(value: 'Romance', child: Text('Romance')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: _showBackgroundImage && widget.backgroundImage != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.backgroundImage!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
                ),
              )
            : null,
        child: DynamicWeatherOverlay(
          child: Column(
            children: [
              // Character quick pill bar
            if (_members.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.black.withValues(alpha: 0.4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._members.map((char) {
                      final avatar = char['avatar_url'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          avatar: CircleAvatar(
                            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar == null || avatar.isEmpty
                                ? Text(char['name']?[0] ?? '?', style: const TextStyle(fontSize: 10, color: Colors.white))
                                : null,
                          ),
                          label: Text(
                            char['name'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }),
                    ActionChip(
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      avatar: const Icon(Icons.add, size: 14, color: Colors.amber),
                      label: const Text(
                        'Add',
                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showManageMembersSheet,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: textColor.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'The Tavern is quiet.',
                                style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Speak to start banter between characters or pick a spark below!',
                                style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['speaker_name'] == 'User';
                            final isSystem = msg['speaker_name'] == 'System';

                            if (isSystem) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      msg['message'] ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.amber[200],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GestureDetector(
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF1E1E24),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  builder: (context) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.edit, color: Colors.blueAccent),
                                          title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _editMessage(msg);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.history, color: Colors.orangeAccent),
                                          title: const Text('Rewind from here', style: TextStyle(color: Colors.orangeAccent)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _rewindChat(msg['id'].toString());
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.redAccent),
                                          title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _deleteMessage(msg['id'].toString());
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                child: Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? const Color(0xFF2563EB).withValues(alpha: 0.9)
                                          : const Color(0xFF26262B).withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                                        bottomRight: Radius.circular(isUser ? 4 : 16),
                                      ),
                                      border: Border.all(
                                        color: isUser
                                            ? Colors.blueAccent.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.12),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isUser)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                msg['speaker_name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (!isUser) const SizedBox(height: 4),
                                        MarkdownBody(
                                          data: msg['message'] ?? '',
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
                                            em: TextStyle(color: Colors.amber[100], fontStyle: FontStyle.italic),
                                            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (_showScrollToBottom)
                          Positioned(
                            right: 16,
                            bottom: 12,
                            child: AnimatedOpacity(
                              opacity: _showScrollToBottom ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: ClipOval(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.82),
                                  child: InkWell(
                                    onTap: _scrollToBottom,
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.8), width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.amber, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // Typing indicator when characters are responding
            if (_isSending)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TypingBubble(
                    label: 'Characters are bantering in the tavern...',
                    dotColor: Colors.amber,
                    bubbleColor: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),

            // Quick banter spark chips
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Colors.black.withValues(alpha: 0.3),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _quickSparks.length,
                itemBuilder: (context, i) {
                  final spark = _quickSparks[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      label: Text(
                        spark,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      onPressed: _isSending ? null : () => _sendMessage(spark),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: Colors.black.withValues(alpha: 0.5),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _restartChat,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900]?.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _regenerateChat,
                    icon: const Icon(Icons.autorenew, size: 16),
                    label: const Text('Regenerate', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900]?.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _continueChat,
                    icon: const Icon(Icons.fast_forward, size: 16),
                    label: const Text('Continue Banter', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[900]?.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),

            // Text Input Field
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Speak or whisper to the group...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.amber),
                            onPressed: () => _sendMessage(),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
