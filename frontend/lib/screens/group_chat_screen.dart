import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../api.dart';

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
  bool _isLoading = true;
  bool _isSending = false;
  bool _showBackgroundImage = true;
  String _currentTheme = 'Dark Mode';
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    try {
      final msgs = await ApiService.getGroupChatMessages(widget.sessionId);
      setState(() {
        _messages = msgs;
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
      _messages.add({'message': text, 'speaker_name': 'User', 'created_at': DateTime.now().toIso8601String()});
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final msgs = await ApiService.sendGroupChatMessage(widget.sessionId, text);
      setState(() {
        _messages = msgs;
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
    setState(() => _isSending = true);
    try {
      final msgs = await ApiService.continueGroupChat(widget.sessionId);
      setState(() {
        _messages = msgs;
        _isSending = false;
      });
      _scrollToBottom();
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

  Future<void> _restartChat() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Tavern'),
        content: const Text('Are you sure you want to delete all messages in this group chat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() => _isSending = true);
    try {
      await ApiService.clearGroupChat(widget.sessionId);
      setState(() {
        _messages.clear();
        _isSending = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(String id) async {
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
        title: const Text('Rewind Chat'),
        content: const Text('Delete this message and ALL messages after it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rewind', style: TextStyle(color: Colors.red))),
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
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ApiService.editGroupChatMessage(widget.sessionId, msg['id'], editController.text);
                await _loadChat();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error editing: $e')));
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color _bgColor;
    Color _textColor;
    
    switch (_currentTheme) {
      case 'Cyberpunk':
        _bgColor = Colors.black87;
        _textColor = Colors.cyanAccent;
        break;
      case 'Fantasy':
        _bgColor = const Color(0xFF2C1E16);
        _textColor = const Color(0xFFD4AF37);
        break;
      case 'Romance':
        _bgColor = const Color(0xFFFFF0F5);
        _textColor = const Color(0xFFC71585);
        break;
      case 'Dark Mode':
      default:
        _bgColor = const Color(0xFF121212);
        _textColor = Colors.white;
        break;
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('Tavern (Group Chat)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (widget.backgroundImage != null)
            IconButton(
              icon: Icon(_showBackgroundImage ? Icons.image_not_supported : Icons.image),
              onPressed: () => setState(() => _showBackgroundImage = !_showBackgroundImage),
              tooltip: 'Toggle Background',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            onSelected: (value) => setState(() => _currentTheme = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Dark Mode', child: Text('Dark Mode')),
              const PopupMenuItem(value: 'Cyberpunk', child: Text('Cyberpunk')),
              const PopupMenuItem(value: 'Fantasy', child: Text('Fantasy')),
              const PopupMenuItem(value: 'Romance', child: Text('Romance')),
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
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                ),
              )
            : null,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: _textColor.withOpacity(0.6))))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['speaker_name'] == 'User';
                            
                            return GestureDetector(
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.edit),
                                          title: const Text('Edit Message'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _editMessage(msg);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.history, color: Colors.orange),
                                          title: const Text('Rewind from here', style: TextStyle(color: Colors.orange)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _rewindChat(msg['id']);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.red),
                                          title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _deleteMessage(msg['id']);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isUser ? Colors.blue.withOpacity(0.8) : Colors.grey[800]?.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isUser ? Colors.blueAccent : Colors.grey[600]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isUser)
                                          Text(
                                            msg['speaker_name'] ?? 'Unknown',
                                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        if (!isUser) const SizedBox(height: 4),
                                        MarkdownBody(
                                          data: msg['message'] ?? '',
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(color: Colors.white, fontSize: 16),
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
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black45,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _restartChat,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _regenerateChat,
                      icon: const Icon(Icons.autorenew, size: 18),
                      label: const Text('Regenerate'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[900]),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _continueChat,
                      icon: const Icon(Icons.fast_forward, size: 18),
                      label: const Text('Continue'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[900]),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            
            // Text Input Field
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Speak to the group...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const CircularProgressIndicator()
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.blue),
                            onPressed: _sendMessage,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
