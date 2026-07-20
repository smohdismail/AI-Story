import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
        title: Row(
          children: [
            Expanded(child: Text(widget.characterName, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.favorite, color: Colors.pink, size: 20),
            const SizedBox(width: 4),
            Text('$_intimacyScore', style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isAudioPlaying ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Ambient Sound',
            onPressed: _toggleAudio,
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentTheme,
              icon: const Icon(Icons.palette, color: Colors.white),
              onChanged: (String? newValue) {
                if (newValue != null) setState(() => _currentTheme = newValue);
              },
              items: <String>['Dark Mode', 'Cyberpunk', 'Fantasy', 'Romance']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
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
              onTap: () => setState(() => _isImmersionMode = !_isImmersionMode),
              child: Container(
                decoration: widget.backgroundImage != null
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(widget.backgroundImage!)),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(_isImmersionMode ? 0.3 : 0.85),
                            BlendMode.darken,
                          ),
                        ),
                      )
                    : null, // Note: For Cyberpunk/Fantasy/Romance, we can also tint this if background is null
                child: Column(
                  children: [
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
                            child: GestureDetector(
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
                        child: Row(
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
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
