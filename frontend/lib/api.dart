import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  static Future<List<dynamic>> getStories() async {
    final response = await http.get(Uri.parse('$baseUrl/stories'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stories');
    }
  }

  static Future<Map<String, dynamic>> createStory(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create story');
    }
  }

  // To support streaming, we'll use http.Client().send() for Server-Sent Events
  static Stream<String> generateChapter(String prompt, String context) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/generate/chapter'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'prompt': prompt, 'context': context});

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
