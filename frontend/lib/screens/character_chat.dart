import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../api.dart';

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

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isImmersionMode = false;
  bool _showBackgroundImage = true;
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
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadChat();
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
      _messages.add({'message': text, 'is_ai': 0, 'created_at': DateTime.now().toIso8601String()});
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final msgs = await ApiService.chatWithCharacter(widget.characterId, text);
      final charInfo = await ApiService.getCharacter(widget.characterId);
      setState(() {
        _messages = msgs;
        _intimacyScore = charInfo['intimacy_score'] ?? 0;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
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

  Future<void> _generateThought() async {
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.getCharacterThought(widget.characterId);
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

  Future<void> _regenerateChat() async {
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    try {
      final msgs = await ApiService.regenerateChat(widget.characterId);
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
    try {
      await ApiService.deleteChatMessage(widget.characterId, id);
      await _loadChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _regenerate() async {
    if (_messages.isEmpty) return;
    setState(() => _isSending = true);
    
    try {
      final msgs = await ApiService.regenerateChat(widget.characterId);
      setState(() {
        _messages = msgs;
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

  Future<void> _viewDiary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Character is writing in diary...'),
          ],
        ),
      ),
    );

    try {
      final res = await ApiService.generateCharacterDiary(widget.characterId);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${widget.characterName}\'s Private Diary', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Text(res['diary_entry'] ?? 'No entry.'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _isImmersionMode ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.characterName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.pink, size: 20),
                  const SizedBox(width: 4),
                  Text('$_intimacyScore', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isAudioPlaying ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Ambient Sound',
            onPressed: _toggleAudio,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette, color: Colors.white),
            tooltip: 'Change Theme',
            onSelected: (String newValue) {
              setState(() => _currentTheme = newValue);
            },
            itemBuilder: (BuildContext context) {
              return ['Dark Mode', 'Cyberpunk', 'Fantasy', 'Romance'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(_showBackgroundImage ? Icons.image : Icons.hide_image, color: Colors.white),
            tooltip: 'Toggle Background',
            onPressed: () {
              setState(() {
                _showBackgroundImage = !_showBackgroundImage;
              });
            },
          ),
          if (widget.backgroundImage != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Image',
              onPressed: _downloadImage,
            ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'View Diary',
            onPressed: _isSending ? null : _viewDiary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onDoubleTap: () => setState(() => _isImmersionMode = !_isImmersionMode),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: widget.backgroundImage != null && _showBackgroundImage
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(widget.backgroundImage!)),
                          fit: BoxFit.cover,
                          colorFilter: _isImmersionMode
                              ? null
                              : ColorFilter.mode(
                                  Colors.black.withOpacity(0.6),
                                  BlendMode.darken,
                                ),
                        ),
                      )
                    : null, // Note: For Cyberpunk/Fantasy/Romance, we can also tint this if background is null
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
                          final isAi = msg['is_ai'] == 1;
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
                                    child: MarkdownBody(
                                      data: msg['message'],
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          color: isAi ? Colors.white : Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 15,
                                        ),
                                        em: TextStyle(
                                          color: isAi ? Colors.white70 : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
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
                                  TextButton.icon(icon: const Icon(Icons.restart_alt, size: 16, color: Colors.red), label: const Text('Restart', style: TextStyle(color: Colors.red)), onPressed: _isSending ? null : _restartChat),
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
    );
  }
}
