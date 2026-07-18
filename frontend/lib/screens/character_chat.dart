import 'package:flutter/material.dart';
import '../api.dart';

class CharacterChatScreen extends StatefulWidget {
  final String characterId;
  final String characterName;

  const CharacterChatScreen({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    try {
      final msgs = await ApiService.getCharacterChat(widget.characterId);
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
        setState(() {
          _isLoading = false;
        });
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
      setState(() {
        _messages = msgs;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
        setState(() {
          _isSending = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.characterName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAi ? Colors.grey[800] : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['message'],
                            style: TextStyle(
                              color: isAi ? Colors.white : Theme.of(context).colorScheme.onPrimary,
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
