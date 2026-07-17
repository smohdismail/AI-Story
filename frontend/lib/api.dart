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
  static Stream<String> generateChapter(String storyId, String prompt, String context) async* {
    final headers = await _getHeaders();
    final request = http.Request('POST', Uri.parse('$baseUrl/generate/chapter'));
    request.headers.addAll(headers);
    request.body = jsonEncode({'prompt': prompt, 'context': context, 'story_id': storyId});

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
}
