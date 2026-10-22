import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException(this.message);
  @override
  String toString() => message;
}

class UnauthenticatedException implements Exception {
  final String message;
  UnauthenticatedException([this.message = 'Session expired or unauthorized']);
  @override
  String toString() => message;
}

class ApiService {
  static const String defaultCloudUrl = 'https://ai-story-mo52.onrender.com/api/v1';
  static const String defaultLocalUrl = 'http://127.0.0.1:8000/api/v1';
  static const String defaultEmulatorUrl = 'http://10.0.2.2:8000/api/v1';

  static String baseUrl = defaultCloudUrl;

  static Future<void> initApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_api_url');
    if (customUrl != null && customUrl.trim().isNotEmpty && !customUrl.contains('127.0.0.1') && !customUrl.contains('10.0.2.2')) {
      baseUrl = customUrl.trim();
    } else {
      baseUrl = defaultCloudUrl;
    }
  }

  static Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_url', url.trim());
  }

  static Future<void> _checkStatus(http.Response response) async {
    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      throw UnauthenticatedException('Session expired. Please log in again.');
    }
  }

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

  static String extractErrorMessage(String responseBody, String defaultMsg) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map && decoded['detail'] != null) {
        if (decoded['detail'] is List) {
          return (decoded['detail'] as List).map((e) => e['msg'] ?? e.toString()).join(', ');
        }
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return defaultMsg;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(extractErrorMessage(response.body, 'Failed to login (${response.statusCode})'));
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}. If the server was sleeping, please wait a moment and retry.');
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(extractErrorMessage(response.body, 'Failed to login with Google (${response.statusCode})'));
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}. If the server was sleeping, please wait a moment and retry.');
    }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(extractErrorMessage(response.body, 'Failed to register (${response.statusCode})'));
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}. If the server was sleeping, please wait a moment and retry.');
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
    final response = await http.get(Uri.parse('$baseUrl/stories'), headers: headers).timeout(const Duration(seconds: 15));
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stories (${response.statusCode})');
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

  static Future<Map<String, dynamic>> suggestCharacterFromPrompt(String prompt, {String? storyId}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/suggest-from-prompt'),
      headers: headers,
      body: jsonEncode({
        'image_prompt': prompt,
        if (storyId != null) 'story_id': storyId,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['profile'] as Map<String, dynamic>?) ?? {};
    } else {
      throw Exception('Failed to suggest character profile');
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

  static Future<void> deleteStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$storyId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete story');
    }
  }

  static Future<Map<String, dynamic>> illustrateScene(String storyId, {String? chapterId, String? customPrompt, String style = "photorealistic"}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/illustrate_scene'),
      headers: headers,
      body: jsonEncode({
        if (chapterId != null) 'chapter_id': chapterId,
        if (customPrompt != null && customPrompt.isNotEmpty) 'custom_prompt': customPrompt,
        'style': style,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to illustrate scene');
    }
  }

  static Future<List<dynamic>> getIllustrations(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/illustrations'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load illustrations');
    }
  }

  static Future<void> deleteIllustration(String storyId, String illustrationId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$storyId/illustrations/$illustrationId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete illustration');
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

  static Stream<String> generateChapter(String storyId, String prompt, String context, {
    String globalCustomRules = '',
    String? selectedChoice,
    String? povCharacter,
    String? narrativeSpark,
    int? tensionLevel,
    String? prophecy,
    String? ambientWeather,
    String? localTimeDesc,
    String? realWorldContext,
  }) async* {
    final headers = await _getHeaders();
    final request = http.Request('POST', Uri.parse('$baseUrl/generate/chapter'));
    request.headers.addAll(headers);
    request.body = jsonEncode({
      'prompt': prompt, 
      'context': context, 
      'story_id': storyId,
      'global_custom_rules': globalCustomRules,
      if (selectedChoice != null && selectedChoice.isNotEmpty) 'selected_choice': selectedChoice,
      if (povCharacter != null && povCharacter.isNotEmpty) 'pov_character': povCharacter,
      if (narrativeSpark != null && narrativeSpark.isNotEmpty) 'narrative_spark': narrativeSpark,
      if (tensionLevel != null) 'tension_level': tensionLevel,
      if (prophecy != null && prophecy.isNotEmpty) 'prophecy': prophecy,
      if (ambientWeather != null && ambientWeather.isNotEmpty) 'ambient_weather': ambientWeather,
      if (localTimeDesc != null && localTimeDesc.isNotEmpty) 'local_time_desc': localTimeDesc,
      if (realWorldContext != null && realWorldContext.isNotEmpty) 'real_world_context': realWorldContext,
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

  static Future<List<String>> generateChapterChoices(String storyId, String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/chapters/$chapterId/choices'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] is List) {
        return List<String>.from(data['choices']);
      }
    }
    return [];
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

  static Future<Map<String, dynamic>> generateImage(String prompt, {String style = "photorealistic"}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/generate-image'),
      headers: headers,
      body: jsonEncode({'prompt': prompt, 'style': style}),
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

  static Future<List<dynamic>> chatWithCharacter(
    String characterId,
    String message, {
    String? ambientWeather,
    String? localTimeDesc,
    String? realWorldContext,
  }) async {
    final headers = await _getHeaders();
    final body = <String, dynamic>{
      'message': message,
    };
    if (ambientWeather != null && ambientWeather.isNotEmpty) {
      body['ambient_weather'] = ambientWeather;
    }
    if (localTimeDesc != null && localTimeDesc.isNotEmpty) {
      body['local_time_desc'] = localTimeDesc;
    }
    if (realWorldContext != null && realWorldContext.isNotEmpty) {
      body['real_world_context'] = realWorldContext;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/chat'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 402) {
      String msg = 'Daily free message limit reached (20/20). Upgrade to VIP for unlimited chatting!';
      try {
        final d = jsonDecode(response.body);
        if (d is Map && d['detail'] != null) {
          msg = d['detail'].toString();
        }
      } catch (_) {}
      throw QuotaExceededException(msg);
    } else {
      throw Exception('Failed to send message: ${response.body}');
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

  static Future<Map<String, dynamic>> getCharacter(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/characters/$characterId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load character');
    }
  }

  static Future<Map<String, dynamic>> getActiveGroupChat(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/group_chats/active'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get active group chat');
    }
  }

  static Future<List<dynamic>> getStoryGroupChats(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/group_chats'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get story group chats');
    }
  }

  static Future<Map<String, dynamic>> createGroupChat(String storyId, {String? title}) async {
    final headers = await _getHeaders();
    final url = title != null
        ? '$baseUrl/stories/$storyId/group_chats?title=${Uri.encodeComponent(title)}'
        : '$baseUrl/stories/$storyId/group_chats';
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create group chat');
    }
  }

  static Future<Map<String, dynamic>> getGroupChatMembers(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/group_chats/$sessionId/members'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get group chat members');
    }
  }

  static Future<Map<String, dynamic>> updateGroupChatMembers(String sessionId, List<String> characterIds) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/group_chats/$sessionId/members'),
      headers: headers,
      body: jsonEncode({'character_ids': characterIds}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update group chat members');
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

  static Future<List<dynamic>> sendGroupChatMessage(
    String sessionId, 
    String message, {
    String? ambientWeather,
    String? localTimeDesc,
    String? realWorldContext,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/group_chats/$sessionId/messages'),
      headers: headers,
      body: jsonEncode({
        'message': message,
        if (ambientWeather != null && ambientWeather.isNotEmpty) 'ambient_weather': ambientWeather,
        if (localTimeDesc != null && localTimeDesc.isNotEmpty) 'local_time_desc': localTimeDesc,
        if (realWorldContext != null && realWorldContext.isNotEmpty) 'real_world_context': realWorldContext,
      }),
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

  static Future<List<dynamic>> extractLore(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/extract-lore'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to extract world lore');
  }

  static Future<Map<String, dynamic>> analyzePlot(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/analyze-plot'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to analyze story plot');
  }

  static Future<List<dynamic>> getStoryTree(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/tree'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load story tree');
  }

  static Future<List<dynamic>> getRelationships(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/relationships'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load character relationships');
  }

  static Future<List<dynamic>> analyzeRelationships(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/relationships/analyze'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to analyze character relationships');
  }

  static Future<Map<String, dynamic>> publishStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/publish'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to publish story');
  }

  static Future<List<dynamic>> getCommunityFeed() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/community/feed'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(extractErrorMessage(response.body, 'Failed to load community feed'));
  }

  static Future<Map<String, dynamic>> likeStory(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/like'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to like story');
  }

  static Future<List<dynamic>> getCharacterUnlocks(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/characters/$characterId/unlocks'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load character unlocks');
  }

  static Future<Map<String, dynamic>> claimCharacterUnlock(String characterId, int milestoneLevel) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/unlocks/claim'),
      headers: headers,
      body: jsonEncode({'milestone_level': milestoneLevel}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to claim character unlock');
  }

  static Future<Map<String, dynamic>> generateTwist(String twistType, {String? storyId, String? context}) async {
    final headers = await _getHeaders();
    final bodyData = {
      'twist_type': twistType,
      if (storyId != null) 'story_id': storyId,
      if (context != null) 'context': context,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/generate/twist'),
      headers: headers,
      body: jsonEncode(bodyData),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate dramatic twist');
  }

  static Future<List<dynamic>> getWorldLocations(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/locations'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load world locations');
  }

  static Future<Map<String, dynamic>> createWorldLocation(String storyId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/locations'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create world location');
  }

  static Future<void> deleteWorldLocation(String storyId, String locationId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/stories/$storyId/locations/$locationId'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete world location');
  }

  static Future<Map<String, dynamic>> rewriteParagraph(
    String text,
    String action, {
    String? customInstruction,
    String? storyId,
    String? context,
  }) async {
    final headers = await _getHeaders();
    final bodyData = {
      'text': text,
      'action': action,
      if (customInstruction != null) 'custom_instruction': customInstruction,
      if (storyId != null) 'story_id': storyId,
      if (context != null) 'context': context,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/generate/rewrite-paragraph'),
      headers: headers,
      body: jsonEncode(bodyData),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to rewrite paragraph');
  }

  static Future<List<dynamic>> getSocialFeed(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/social-feed'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load social feed');
  }

  static Future<Map<String, dynamic>> generateSocialPost(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/social-feed/generate'), headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to generate social post');
  }

  static Future<Map<String, dynamic>> likeSocialPost(String postId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/social-feed/$postId/like'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to like post');
  }

  static Future<Map<String, dynamic>> commentSocialPost(String postId, String content, {String? authorName}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/social-feed/$postId/comment'),
      headers: headers,
      body: jsonEncode({'author_name': authorName ?? 'Reader', 'content': content}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to comment on post');
  }

  static Future<Map<String, dynamic>> generateMangaComic(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chapters/$chapterId/generate-manga'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate manga comic');
  }

  static Future<Map<String, dynamic>> generatePillowTalk(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chapters/$chapterId/pillow-talk'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate pillow talk epilogue');
  }

  static Future<Map<String, dynamic>> submitDialogueWhisper(String chapterId, String whisperText, {String actionType = 'whisper'}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/$chapterId/whisper-branch'),
      headers: headers,
      body: jsonEncode({'whisper_text': whisperText, 'action_type': actionType}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to submit dialogue whisper');
  }

  static Future<Map<String, dynamic>> updateCharacterChemistry(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/characters/chemistry-update'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update character chemistry');
  }

  static Future<List<dynamic>> getAllUserCharacters() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/me/all-characters'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> getStoryOutlinePlan(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/stories/$storyId/outline-plan'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate story outline plan');
  }

  static Future<Map<String, dynamic>> generateStoryCover(String storyId, {String style = 'Anime/Manga'}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/generate-cover'),
      headers: headers,
      body: jsonEncode({'style': style}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate book cover');
  }

  static Future<Map<String, dynamic>> generateAfterHoursCut(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chapters/$chapterId/after-hours'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate after-hours cut');
  }

  static Future<Map<String, dynamic>> dateEncounterStep(
    String characterId, {
    required String setting,
    String? chatHistory,
    String? userInput,
    String? userAction,
    List<dynamic>? history,
  }) async {
    final headers = await _getHeaders();
    final actualInput = userInput ?? userAction ?? '';
    final actualHistory = chatHistory ?? (history != null ? jsonEncode(history) : '');
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/date-encounter'),
      headers: headers,
      body: jsonEncode({
        'setting': setting,
        'chat_history': actualHistory,
        'user_input': actualInput,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate date encounter step');
  }

  static Future<List<dynamic>> getStoryKeepsakes(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/keepsakes'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['keepsakes'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> getChapterTeaser(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chapters/$chapterId/teaser'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate chapter teaser');
  }

  static Future<Map<String, dynamic>> getChemistryCurve(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/chemistry-curve'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'curve': data};
    }
    return {};
  }

  static Future<Map<String, dynamic>> generateMidnightVoicemail(String characterId, {String? mood}) async {
    final headers = await _getHeaders();
    final body = mood != null ? jsonEncode({'mood': mood}) : null;
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/midnight-voicemail'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate midnight voicemail');
  }

  static Future<List<dynamic>> getUnsentLetters(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/unsent-letters'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['letters'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> generateWhatIfVignette(String chapterId, {required String scenario, int heatLevel = 5}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/$chapterId/what-if'),
      headers: headers,
      body: jsonEncode({'scenario': scenario, 'heat_level': heatLevel}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate what-if vignette');
  }

  static Future<List<dynamic>> getPolaroids(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/polaroids'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['polaroids'] ?? [];
    }
    return [];
  }

  static Future<List<dynamic>> getCharacterSubconscious(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/chapters/$chapterId/subconscious'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['moments'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> generatePovFlip(String chapterId, {String? targetCharacter}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/$chapterId/pov-flip'),
      headers: headers,
      body: jsonEncode({'target_character': targetCharacter}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate POV flip');
  }

  static Future<Map<String, dynamic>> startMidnightPhoneCall(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/phone-call/start'),
      headers: headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to initiate midnight phone call');
  }

  static Future<Map<String, dynamic>> respondMidnightPhoneCall(String characterId, {String? whisper, int turn = 1}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/phone-call/respond'),
      headers: headers,
      body: jsonEncode({'whisper': whisper ?? '', 'turn': turn}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to respond to midnight phone call');
  }

  static Future<Map<String, dynamic>> steerChapterFromMargin(String chapterId, {required String paragraphContext, required String readerScribble}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/$chapterId/steer'),
      headers: headers,
      body: jsonEncode({
        'paragraph_context': paragraphContext,
        'reader_scribble': readerScribble,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to steer chapter from margin');
  }

  static Future<Map<String, dynamic>> getSensoryProfile(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/sensory-profile'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['profile'] ?? {};
    }
    return {};
  }

  static Future<List<dynamic>> getScheduledLetters(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/scheduled-letters'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['letters'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> getSonicScore(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/chapters/$chapterId/sonic-score'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['sonic_score'] ?? {};
    }
    return {};
  }

  static Future<Map<String, dynamic>> getChapterPrivateDiary(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/chapters/$chapterId/private-diary'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['diary'] ?? {};
    }
    return {};
  }

  static Future<Map<String, dynamic>> sendWaxSealedReply(
    String storyId, {
    String? recipientName,
    String stationery = "Parchment",
    String waxColor = "Crimson",
    required String userReply,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/reply-letter'),
      headers: headers,
      body: jsonEncode({
        'recipient_name': recipientName,
        'stationery': stationery,
        'wax_color': waxColor,
        'user_reply': userReply,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send wax-sealed reply');
  }

  static Future<List<dynamic>> getRedThreadCrossings(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/red-thread'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['crossings'] ?? [];
    }
    return [];
  }

  // --- 1. UNIFIED NARRATIVE MEMORY & TIMELINE HUB ---
  static Future<List<dynamic>> getStoryNarrativeMemories(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/narrative-memories'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> createNarrativeMemory(
    String storyId, {
    String source = "custom",
    String? characterName,
    required String eventSummary,
    String? emotionalImpact,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/narrative-memories'),
      headers: headers,
      body: jsonEncode({
        'source': source,
        'character_name': characterName,
        'event_summary': eventSummary,
        'emotional_impact': emotionalImpact,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create narrative memory');
  }

  static Future<Map<String, dynamic>> syncStoryChronicle(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/sync-chronicle'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to sync chronicle');
  }

  // --- 2. TENSION & JEALOUSY DIAL ---
  static Future<void> updateTensionDial(String storyId, int tensionLevel) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/stories/$storyId/tension-dial'),
      headers: headers,
      body: jsonEncode({'tension_level': tensionLevel}),
    );
  }

  // --- 3. THE CLIMAX & PROPOSAL MILESTONE ---
  static Future<Map<String, dynamic>> getClimaxMilestoneStatus(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/climax-milestone'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {"is_unlocked": false, "has_completed": false};
  }

  static Future<Map<String, dynamic>> generateClimaxMilestone(String storyId, {String? leadCharacterName}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/climax-milestone/generate'),
      headers: headers,
      body: jsonEncode({'lead_character_name': leadCharacterName}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate climax milestone');
  }

  static Future<Map<String, dynamic>> saveClimaxChoice(
    String storyId, {
    required String selectedChoice,
    required String leadName,
    required String keepsakeVow,
    String? destinyScore,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/climax-milestone/save-choice'),
      headers: headers,
      body: jsonEncode({
        'selected_choice': selectedChoice,
        'lead_name': leadName,
        'keepsake_vow': keepsakeVow,
        'destiny_score': destinyScore,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to save climax choice');
  }

  // --- 4. CHARACTER VOICEMAIL BOX & MIDNIGHT MEMOS ---
  static Future<List<dynamic>> getCharacterVoicemails(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/characters/$characterId/voicemails'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> generateCharacterVoicemail(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/voicemails/generate'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate character voicemail');
  }

  static Future<void> listenVoicemail(String voicemailId) async {
    final headers = await _getHeaders();
    await http.post(Uri.parse('$baseUrl/voicemails/$voicemailId/listen'), headers: headers);
  }

  // --- 5. DESTINY TAROT & ROMANCE PROPHECIES ---
  static Future<Map<String, dynamic>> drawRomanceTarot(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/stories/$storyId/tarot/draw'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to draw romance tarot spread');
  }

  static Future<Map<String, dynamic>> injectProphecy(String storyId, String prophecyTwist) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/tarot/inject'),
      headers: headers,
      body: jsonEncode({'prophecy_twist': prophecyTwist}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to inject prophecy into story');
  }

  // --- 6. WARDROBE & EVENT STYLIST ---
  static Future<Map<String, dynamic>> getCharacterWardrobe(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/characters/$characterId/wardrobe'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {"outfits": []};
  }

  static Future<Map<String, dynamic>> generateWardrobe(String characterId, String outfitConcept) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/wardrobe/generate'),
      headers: headers,
      body: jsonEncode({'outfit_concept': outfitConcept}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate wardrobe outfit');
  }

  static Future<void> equipWardrobe(String characterId, String outfitId, {bool setAsAvatar = true}) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/characters/$characterId/wardrobe/equip'),
      headers: headers,
      body: jsonEncode({'outfit_id': outfitId, 'set_as_avatar': setAsAvatar}),
    );
  }

  // --- 7. TIMED READER FLOATING REACTIONS ---
  static Future<List<dynamic>> getChapterReactions(String chapterId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/chapters/$chapterId/reactions'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> addChapterReaction(
    String chapterId, {
    int paragraphIndex = 0,
    String emoji = "🔥",
    String? reactionText,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/$chapterId/reactions'),
      headers: headers,
      body: jsonEncode({
        'paragraph_index': paragraphIndex,
        'emoji': emoji,
        'reaction_text': reactionText,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to add chapter reaction');
  }

  // --- 8. 24-HOUR CHARACTER LIVE ROUTINE & CHECK-INS ---
  static Future<Map<String, dynamic>> getCharacterLiveRoutine(
    String characterId, {
    int? hour,
    int? minute,
    bool forceRefresh = false,
  }) async {
    final headers = await _getHeaders();
    final now = DateTime.now();
    final h = hour ?? now.hour;
    final m = minute ?? now.minute;
    final url = '$baseUrl/characters/$characterId/routine?hour=$h&minute=$m&force_refresh=$forceRefresh';
    final response = await http.get(Uri.parse(url), headers: headers);
    await _checkStatus(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['routine'] ?? {};
    }
    throw Exception('Failed to load character live routine');
  }

  static Future<Map<String, dynamic>> distractCharacterRoutine(
    String characterId, {
    required String message,
    String? currentActivity,
    String? location,
    String? innerThought,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/routine/distract'),
      headers: headers,
      body: jsonEncode({
        'message': message,
        'current_activity': currentActivity,
        'location': location,
        'inner_thought': innerThought,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send routine distraction');
  }

  static Future<Map<String, dynamic>> getPrivateWhispers(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/private-whispers'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load private whispers');
  }

  static Future<Map<String, dynamic>> getCharacterMemoryVault(String characterId, {bool forceRefresh = false}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/characters/$characterId/memory-vault?force_refresh=$forceRefresh');
    final response = await http.get(uri, headers: headers);
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load character memory vault');
  }

  static Future<bool> togglePinMemory(String memoryId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/memories/$memoryId/pin'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['is_pinned'] == true;
    }
    return false;
  }

  static Future<bool> deleteMemory(String memoryId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/memories/$memoryId'),
      headers: headers,
    );
    return response.statusCode == 200;
  }


  // ==========================================
  // 💌 1. VINTAGE HANDWRITTEN LETTERS & POLAROID MAILBOX
  // ==========================================
  static Future<List<dynamic>> getCharacterMailbox(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/mailbox'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load mailbox');
  }

  static Future<Map<String, dynamic>> generateMailboxLetter(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/mailbox/generate'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate letter');
  }

  static Future<void> openMailboxLetter(String letterId) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/mailbox/$letterId/open'),
      headers: headers,
    );
  }

  static Future<Map<String, dynamic>> replyMailboxLetter(
    String letterId, {
    required String userReply,
    String? replyCrest,
    String? replyStationery,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/mailbox/$letterId/reply'),
      headers: headers,
      body: jsonEncode({
        'user_reply': userReply,
        'reply_crest': replyCrest ?? 'Golden Rose',
        'reply_stationery': replyStationery ?? 'Vintage Cream',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send letter reply');
  }

  // ==========================================
  // 🌙 2. LATE-NIGHT SHARED DREAMS & ASTRAL REVERIE
  // ==========================================
  static Future<List<dynamic>> getCharacterSharedDreams(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/shared-dreams'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load shared dreams');
  }

  static Future<Map<String, dynamic>> dreamTogether(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/dream-together'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to dream together');
  }

  // ==========================================
  // 🎭 3. JEALOUSY & RIVALRY CONFRONTATION DRAMA
  // ==========================================
  static Future<Map<String, dynamic>> getStoryJealousyHeatmap(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/jealousy-heatmap'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load jealousy heatmap');
  }

  static Future<Map<String, dynamic>> triggerJealousyConfrontation(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/jealousy-confrontation'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to trigger confrontation');
  }

  static Future<Map<String, dynamic>> resolveJealousyConfrontation(
    String confrontationId, {
    required String choiceKey,
    required String choiceAction,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/confrontations/$confrontationId/resolve'),
      headers: headers,
      body: jsonEncode({
        'choice_key': choiceKey,
        'choice_action': choiceAction,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to resolve confrontation');
  }

  // ==========================================
  // 🏡 4. DOMESTIC BLISS & EPILOGUE SIMULATOR
  // ==========================================
  static Future<List<dynamic>> getCharacterDomesticBliss(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/domestic-bliss'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load domestic bliss vignettes');
  }

  static Future<Map<String, dynamic>> generateDomesticBliss(
    String characterId, {
    String? category,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/domestic-bliss/generate'),
      headers: headers,
      body: jsonEncode({
        'category': category ?? 'morning_kitchen',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate domestic bliss vignette');
  }


  // ==========================================
  // BATCH 5: 6 NEXT-LEVEL VISUAL & SENSORY APIS
  // ==========================================

  // 1. 📸 Spontaneous Candid Selfies & Photo Requests
  static Future<Map<String, dynamic>> requestCandidPhoto(
    String characterId, {
    String? category,
    String? promptTheme,
    bool isSpontaneous = false,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/candid_photos/request'),
      headers: headers,
      body: jsonEncode({
        'category': category ?? 'casual_selfie',
        'prompt_theme': promptTheme ?? '',
        'is_spontaneous': isSpontaneous,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to request candid photo');
  }

  static Future<List<dynamic>> getCandidPhotos(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/candid_photos'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load candid photos');
  }

  static Future<bool> toggleFavoriteCandidPhoto(String photoId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/candid_photos/$photoId/favorite'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return res['is_favorited'] == true;
    }
    throw Exception('Failed to toggle favorite');
  }

  // 2. 🎞️ Daily Stories (24-Hour Status Reels)
  static Future<Map<String, dynamic>> generateDailyStory(
    String characterId, {
    String? timePeriod,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/daily_stories/generate'),
      headers: headers,
      body: jsonEncode({
        'time_period': timePeriod ?? 'morning',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate daily story');
  }

  static Future<List<dynamic>> getStoryDailyStories(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/daily_stories'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load daily stories');
  }

  static Future<void> replyToDailyStory(
    String storyItemId, {
    required String replyText,
    String reactionEmoji = '❤️',
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/daily_stories/$storyItemId/reply'),
      headers: headers,
      body: jsonEncode({
        'reply_text': replyText,
        'reaction_emoji': reactionEmoji,
      }),
    );
    await _checkStatus(response);
  }

  // 3. 📹 VHS Camcorder Memory Clips
  static Future<Map<String, dynamic>> generateVhsClip(
    String characterId, {
    String? clipTheme,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/vhs_clips/generate'),
      headers: headers,
      body: jsonEncode({
        'clip_theme': clipTheme ?? 'candid_romantic_moment',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate VHS clip');
  }

  static Future<List<dynamic>> getVhsClips(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/vhs_clips'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load VHS clips');
  }

  // 4. 🛍️ Gift Giving & Try-On Photoshoot
  static Future<List<dynamic>> getBoutiqueCatalog() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/boutique/catalog'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load boutique catalog');
  }

  static Future<Map<String, dynamic>> giveGiftToCharacter(
    String characterId, {
    required String giftName,
    String giftCategory = 'outfit',
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/give_gift'),
      headers: headers,
      body: jsonEncode({
        'gift_name': giftName,
        'gift_category': giftCategory,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to give gift');
  }

  static Future<List<dynamic>> getGiftHistory(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/gift_history'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load gift history');
  }

  // 5. 🧳 Photobooth Strips
  static Future<Map<String, dynamic>> generatePhotoboothStrip(
    String characterId, {
    String? milestoneEvent,
    String? stripTheme,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/photobooth/generate'),
      headers: headers,
      body: jsonEncode({
        'milestone_event': milestoneEvent ?? 'Sweet Date',
        'strip_theme': stripTheme ?? 'pastel_blossom',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate photobooth strip');
  }

  static Future<List<dynamic>> getPhotoboothStrips(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/photobooth_strips'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load photobooth strips');
  }

  // 6. 🔍 Room Inspection
  static Future<Map<String, dynamic>> generateRoomInspection(
    String characterId, {
    String? roomType,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/room_inspection/generate'),
      headers: headers,
      body: jsonEncode({
        'room_type': roomType ?? 'bedroom',
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate room inspection');
  }

  static Future<List<dynamic>> getRoomInspections(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/room_inspections'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load room inspections');
  }

  // ==========================================
  // ⚡ 7. STORY CONTINUITY & SYNCHRONIZED CHAPTER PROMPTS
  // ==========================================
  static Future<Map<String, dynamic>> getSyncedChapterPrompts(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/synced_chapter_prompts'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load synchronized chapter prompts');
  }

  static Future<Map<String, dynamic>> checkChapterContinuity(
    String storyId,
    String proposedPrompt,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/check_chapter_continuity'),
      headers: headers,
      body: jsonEncode({
        'proposed_prompt': proposedPrompt,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to check chapter continuity');
  }

  // ==========================================
  // 👥 8. AUTONOMOUS GOSSIP & CHARACTER-TO-CHARACTER DRAMA
  // ==========================================
  static Future<List<dynamic>> getStoryGossip(String storyId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/gossip'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load overheard gossip');
  }

  static Future<Map<String, dynamic>> generateStoryGossip(String storyId, {String? topicHint}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/gossip/generate'),
      headers: headers,
      body: jsonEncode({
        if (topicHint != null && topicHint.isNotEmpty) 'topic_hint': topicHint,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate overheard gossip');
  }

  // ==========================================
  // 💌 9. SECRET LOCKED DIARY & HER PRIVATE INNER THOUGHTS
  // ==========================================
  static Future<List<dynamic>> getCharacterDiary(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/diary'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load character diary');
  }

  static Future<Map<String, dynamic>> generateCharacterDiary(String characterId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/diary/generate'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to write character diary entry');
  }

  static Future<Map<String, dynamic>> unlockDiaryEntry(String entryId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/diary/$entryId/unlock'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to unlock diary entry');
  }

  // ==========================================
  // 🎙️ 10. DIRECT HIGH-FIDELITY SPOKEN VOICE &
  // 📱 NATIVE SPONTANEOUS NOTIFICATIONS
  // ==========================================
  static Future<List<dynamic>> getAvailableVoices() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/voice/voices'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load available voices');
  }

  static Future<Map<String, dynamic>> getCharacterSpeech(
    String characterId,
    String text, {
    String? voiceId,
    String? rate,
    String? pitch,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/speak'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        if (voiceId != null && voiceId.isNotEmpty) 'voice_id': voiceId,
        if (rate != null) 'rate': rate,
        if (pitch != null) 'pitch': pitch,
      }),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to synthesize character speech');
  }

  static Future<Map<String, dynamic>> setCharacterVoice(String characterId, String voiceId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/characters/$characterId/voice'),
      headers: headers,
      body: jsonEncode({'voice_id': voiceId}),
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update character voice');
  }

  static Future<Map<String, dynamic>> getProactiveNotification(
    String characterId, {
    String? userPersonaName,
    String? localTimeStr,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/characters/$characterId/proactive_ping').replace(
      queryParameters: {
        if (userPersonaName != null) 'user_persona_name': userPersonaName,
        if (localTimeStr != null) 'local_time_str': localTimeStr,
      },
    );
    final response = await http.post(
      uri,
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate spontaneous notification');
  }

  // ==========================================
  // 👑 11. USER PROFILE & MASTER OWNER ACCESS
  // ==========================================
  static Future<Map<String, dynamic>> getMyProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );
    await _checkStatus(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load user profile');
  }

  // ==========================================
  // 👑 12. SUBSCRIPTION & DAILY QUOTA
  // ==========================================
  static Future<Map<String, dynamic>> getUserQuota() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me/quota'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {
      'is_vip': false,
      'is_owner': false,
      'daily_chats_remaining': 20,
      'max_daily_chats': 20,
      'daily_chats_used': 0,
      'daily_stories_remaining': 2,
    };
  }

  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/subscription/plans'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load subscription plans');
  }

  static Future<Map<String, dynamic>> upgradeSubscription(String planId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/subscription/upgrade'),
      headers: headers,
      body: jsonEncode({'plan_id': planId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to upgrade subscription');
  }

  static Future<bool> pingHeartbeat() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/system/heartbeat')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
