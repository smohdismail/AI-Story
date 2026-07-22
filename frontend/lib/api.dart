import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use the cloud backend URL
  static const String baseUrl = 'https://ai-story-mo52.onrender.com/api/v1';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<int>?> downloadEpub(String storyId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/stories/$storyId/export/epub'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error downloading EPUB: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  // --- PERSONA API ---
  static Future<Map<String, dynamic>?> getPersona() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/me/persona'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to fetch persona');
  }

  static Future<Map<String, dynamic>> savePersona(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/users/me/persona'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to save persona');
  }

  static Future<List<dynamic>> requestSelfie(String characterId, {String? customPrompt}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/characters/$characterId/chat/request_selfie';
    if (customPrompt != null && customPrompt.isNotEmpty) {
      url += '?custom_prompt=${Uri.encodeComponent(customPrompt)}';
    }
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to request selfie');
  }

  static Future<List<dynamic>> getStories() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stories');
    }
  }

  static Future<Map<String, dynamic>> getStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load story');
    }
  }

  static Future<List<dynamic>> getCharacters(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/characters'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load characters');
    }
  }

  static Future<Map<String, dynamic>> createCharacter(String storyId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/characters'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create character');
    }
  }

  static Future<void> deleteCharacter(String storyId, String characterId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$storyId/characters/$characterId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete character');
    }
  }

  static Future<Map<String, dynamic>> updateCharacter(String storyId, String characterId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/stories/$storyId/characters/$characterId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update character');
    }
  }

  static Future<List<dynamic>> getWorldItems(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/world-items'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load world items');
    }
  }

  static Future<Map<String, dynamic>> createWorldItem(String storyId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/world-items'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create world item');
    }
  }

  static Future<void> deleteWorldItem(String storyId, String itemId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$storyId/world-items/$itemId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete world item');
    }
  }

  static Future<Map<String, dynamic>> createStory(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create story');
    }
  }

  static Future<Map<String, dynamic>> updateStory(String storyId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/stories/$storyId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update story');
    }
  }

  static Future<Map<String, dynamic>> forkStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/fork'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fork story');
    }
  }

  static Future<List<dynamic>> getChapters(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/chapters'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chapters');
    }
  }

  static Future<Map<String, dynamic>> saveChapter(String storyId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/chapters'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to save chapter');
    }
  }

  static Future<void> deleteChapter(String storyId, int chapterNumber) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$storyId/chapters/$chapterNumber'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete chapter');
    }
  }

  static Future<Map<String, dynamic>> updateChapter(String storyId, int chapterNumber, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/stories/$storyId/chapters/$chapterNumber'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update chapter');
    }
  }

  // To support streaming, we'll use http.Client().send() for Server-Sent Events
  static Stream<String> generateChapter(String storyId, String prompt, String context, {String globalCustomRules = ''}) async* {
    final headers = await _getHeaders();
    final request = http.Request('POST', Uri.parse('$baseUrl/generate/chapter'));
    request.headers.addAll(headers);
    request.body = jsonEncode({
      'prompt': prompt, 
      'context': context, 
      'story_id': storyId,
      'global_custom_rules': globalCustomRules,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate chapter');
      }

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        // Simple chunk yielding. Proper SSE parsing might be needed if standard SSE is used.
        yield chunk;
      }
    } finally {
      client.close();
    }
  }

  static Future<void> reorderChapters(String storyId, List<String> chapterIds) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/chapters/reorder'),
      headers: headers,
      body: jsonEncode({'chapter_ids': chapterIds}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to reorder chapters');
    }
  }

  static Future<Map<String, dynamic>> generateImage(String prompt) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/generate-image'),
      headers: headers,
      body: jsonEncode({'prompt': prompt}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate image');
    }
  }

  static Future<Map<String, dynamic>> branchStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/branch'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to branch story');
    }
  }

  static Future<Map<String, dynamic>> copilotEdit(String text, String command, String storyContext) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/ai/copilot'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'command': command,
        'story_context': storyContext
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to run copilot');
    }
  }

  static Future<List<dynamic>> getCharacterChat(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/chat'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat');
    }
  }

  static Future<List<dynamic>> chatWithCharacter(String characterId, String message) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message');
    }
  }

  static Future<void> editChatMessage(String characterId, String chatId, String message) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/characters/$characterId/chat/$chatId'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to edit message');
    }
  }

  static Future<void> rewindChat(String characterId, String chatId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/characters/$characterId/chat/$chatId/rewind'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to rewind chat');
    }
  }

  static Future<List<dynamic>> regenerateChat(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat/regenerate'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to regenerate chat');
    }
  }

  static Future<void> clearChat(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat/clear'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to clear chat');
    }
  }

  static Future<void> deleteChatMessage(String characterId, String chatId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/characters/$characterId/chat/$chatId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete chat message');
    }
  }

  static Future<List<dynamic>> continueChat(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat/continue'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to continue chat');
    }
  }

  static Future<List<String>> getChatSuggestions(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat/suggest'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['suggestions'] ?? []);
    } else {
      throw Exception('Failed to get suggestions');
    }
  }

  static Future<List<dynamic>> getCharacterThought(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat/thought'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get character thought');
    }
  }

  static Future<Map<String, dynamic>> generateCharacterDiary(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/diary'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate diary');
    }
  }

  static Future<Map<String, dynamic>> getCharacter(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/characters/$characterId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load character');
    }
  }

  static Future<Map<String, dynamic>> createGroupChat(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/group_chats'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create group chat');
    }
  }

  static Future<List<dynamic>> getGroupChatMessages(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/group_chats/$sessionId/messages'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load group chat messages');
    }
  }

  static Future<List<dynamic>> sendGroupChatMessage(String sessionId, String message) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/group_chats/$sessionId/messages'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send group chat message');
    }
  }

  static Future<void> editGroupChatMessage(String sessionId, String msgId, String message) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/group_chats/$sessionId/messages/$msgId'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode != 200) throw Exception('Failed to edit group chat message');
  }

  static Future<void> rewindGroupChat(String sessionId, String msgId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/group_chats/$sessionId/messages/$msgId/rewind'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to rewind group chat');
  }

  static Future<void> deleteGroupChatMessage(String sessionId, String msgId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/group_chats/$sessionId/messages/$msgId'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete group chat message');
  }

  static Future<List<dynamic>> continueGroupChat(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/group_chats/$sessionId/continue'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to continue group chat');
  }

  static Future<List<dynamic>> regenerateGroupChat(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/group_chats/$sessionId/regenerate'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to regenerate group chat');
  }

  static Future<void> clearGroupChat(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/group_chats/$sessionId/clear'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to clear group chat');
  }
}
