import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/edit_chapter.dart';
import 'package:frontend/screens/zen_reader.dart';

void main() {
  testWidgets('edit chapter renders', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      print('FLUTTER ERROR: ${details.exception}');
      print(details.stack);
    };
    try {
      await tester.pumpWidget(MaterialApp(
        home: EditChapterScreen(storyId: 'test', chapterNumber: 1, chapterData: {'content': 'test'}),
      ));
      await tester.pumpAndSettle();
      print('Edit chapter rendered successfully');
    } catch (e) {
      print('CAUGHT ERROR: $e');
    }
  });
}
