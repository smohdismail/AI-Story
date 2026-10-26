import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pdf_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generateStoryPdf generates valid PDF bytes without crashing', () async {
    final story = {
      'id': '123',
      'title': 'The Adventure: Beginning & Beyond! 😊🚀',
      'genre': 'Fantasy & Sci-Fi',
      'synopsis': 'A thrilling tale of 💬 magic and space.'
    };

    final characters = [
      {'name': 'Lyra', 'full_name': 'Lyra Silvertongue'}
    ];

    final chapters = [
      {
        'chapter_number': 1,
        'title': 'The Awakening 🌟',
        'content': 'Once upon a time in a realm far away... 💬 "Look there!" whispered Lyra.'
      }
    ];

    final timeline = [
      {
        'type': 'chapter',
        'chapter_number': 1,
        'title': 'The Awakening 🌟',
        'content': 'Once upon a time in a realm far away... 💬 "Look there!" whispered Lyra.'
      },
      {
        'type': 'chat_section',
        'title': 'Conversations after Chapter 1',
        'items': [
          {
            'speaker': 'Lyra',
            'is_ai': true,
            'message': 'Did you see that ancient seal? 🗝️✨'
          },
          {
            'speaker': 'You',
            'is_ai': false,
            'message': 'Yes! Let us uncover the mystery.'
          }
        ]
      }
    ];

    final bytes = await PdfExport.generateStoryPdf(
      story,
      characters,
      chapters,
      timeline: timeline,
    );

    expect(bytes, isNotNull);
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes.length, greaterThan(100));
  });
}
