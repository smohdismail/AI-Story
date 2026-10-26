import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';

class PdfExport {
  static String _clean(String text) {
    // Strip emojis, dingbats, variation selectors, and surrogate characters that crash standard PDF fonts
    return text
        .replaceAll(RegExp(r'[\u{10000}-\u{10FFFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{FE00}-\u{FE0F}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2300}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2B50}-\u{2B55}]', unicode: true), '')
        .trim();
  }

  static Future<Uint8List> generateStoryPdf(
      Map<String, dynamic> story, 
      List<dynamic> characters, 
      List<dynamic> chapters,
      {List<dynamic>? timeline}) async {
    
    // If timeline not passed, fetch from backend timeline API
    if (timeline == null && story['id'] != null) {
      try {
        final timelineData = await ApiService.getStoryTimelineExport(story['id'].toString());
        if (timelineData != null && timelineData['timeline'] is List) {
          timeline = timelineData['timeline'] as List<dynamic>;
        }
      } catch (e) {
        debugPrint('Could not fetch timeline for PDF export: $e');
      }
    }

    final pdf = pw.Document();

    // Use classic Serif font with reliable fallback
    pw.Font font;
    pw.Font fontItalic;
    pw.Font fontBold;

    try {
      font = await PdfGoogleFonts.merriweatherRegular();
      fontItalic = await PdfGoogleFonts.merriweatherItalic();
      fontBold = await PdfGoogleFonts.merriweatherBold();
    } catch (_) {
      font = pw.Font.helvetica();
      fontItalic = pw.Font.helveticaOblique();
      fontBold = pw.Font.helveticaBold();
    }

    final normalStyle = pw.TextStyle(font: font, fontSize: 11, lineSpacing: 2);
    final italicStyle = pw.TextStyle(font: fontItalic, fontSize: 11, lineSpacing: 2);
    final dialogueSpeakerAi = pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.deepPurple800);
    final dialogueSpeakerUser = pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blueGrey800);
    final dialogueText = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 1.5, color: PdfColors.black);
    
    String title = _clean(story['title'] ?? '');
    String subtitle = _clean(story['synopsis'] ?? '');
    
    if (title.isEmpty || title == 'Untitled Story') {
       if (characters.isNotEmpty) {
           final charNames = characters.map((c) => _clean(c['full_name'] ?? c['name'] ?? '')).where((n) => n.isNotEmpty).toList();
           if (charNames.length == 1) {
               title = "The Story of You & ${charNames[0]}";
           } else if (charNames.length > 1) {
               title = "The Story of ${charNames[0]} & ${charNames[1]}";
           } else {
               title = "The Story of You";
           }
       } else {
           title = "The Story of You";
       }
    }

    // Title Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 32), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 16),
                if (story['genre'] != null && story['genre'].toString().isNotEmpty)
                  pw.Text(_clean(story['genre'].toString()).toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.deepPurple700, letterSpacing: 2)),
                pw.SizedBox(height: 30),
                if (subtitle.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                    child: pw.Text(subtitle, style: pw.TextStyle(font: fontItalic, fontSize: 13, lineSpacing: 1.8), textAlign: pw.TextAlign.center),
                  ),
              ],
            ),
          );
        },
      ),
    );

    // Parse asterisks to italics
    List<pw.InlineSpan> parseText(String text) {
      final spans = <pw.InlineSpan>[];
      final parts = text.split('*');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        if (i % 2 == 0) {
          spans.add(pw.TextSpan(text: parts[i], style: normalStyle));
        } else {
          spans.add(pw.TextSpan(text: parts[i], style: italicStyle));
        }
      }
      return spans;
    }

    if (timeline != null && timeline.isNotEmpty) {
      final widgets = <pw.Widget>[];

      for (int i = 0; i < timeline.length; i++) {
        final item = timeline[i];
        final type = item['type'];

        if (type == 'chapter') {
          final chNum = item['chapter_number'] ?? (i + 1);
          final chTitle = _clean((item['title'] ?? 'Chapter $chNum').toString());
          final content = _clean((item['content'] ?? '').toString());

          if (widgets.isNotEmpty) {
            widgets.add(pw.NewPage());
          }

          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CHAPTER $chNum', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.deepPurple, letterSpacing: 2)),
                  pw.SizedBox(height: 4),
                  pw.Text(chTitle, style: pw.TextStyle(font: fontBold, fontSize: 22)),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                ],
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          final paragraphs = content.split('\n\n');
          for (final p in paragraphs) {
            final trimmed = p.trim();
            if (trimmed.isEmpty) continue;
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.RichText(
                  text: pw.TextSpan(children: parseText(trimmed)),
                ),
              ),
            );
          }
        } else if (type == 'chat_section') {
          final secTitle = _clean((item['title'] ?? 'Conversations').toString());
          final chatItems = (item['items'] as List<dynamic>? ?? []);

          if (chatItems.isEmpty) continue;

          widgets.add(pw.SizedBox(height: 20));
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.deepPurple200, width: 0.8)),
              ),
              child: pw.Text(
                '- ${secTitle.toUpperCase()} -',
                style: pw.TextStyle(font: fontBold, fontSize: 10, letterSpacing: 1.5, color: PdfColors.deepPurple900),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          for (final c in chatItems) {
            final speaker = _clean((c['speaker'] ?? (c['is_ai'] == true ? (c['character_name'] ?? 'Character') : 'You')).toString());
            final isAi = c['is_ai'] == true;
            final message = _clean((c['message'] ?? '').toString());
            if (message.isEmpty) continue;

            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: isAi ? PdfColors.purple50 : PdfColors.blueGrey50,
                    border: pw.Border(
                      left: pw.BorderSide(
                        color: isAi ? PdfColors.deepPurple700 : PdfColors.blueGrey700,
                        width: 3.5,
                      ),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        speaker,
                        style: isAi ? dialogueSpeakerAi : dialogueSpeakerUser,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        message,
                        style: dialogueText,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 12));
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => widgets,
        ),
      );
    } else {
      // Fallback: traditional chapters only
      for (var chapter in chapters) {
        final content = _clean((chapter['content'] ?? '').toString());
        if (content.isEmpty) continue;

        final paragraphs = content.split('\n\n');

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Text('Chapter ${chapter['chapter_number']}: ${_clean(chapter['title'] ?? '')}', style: pw.TextStyle(font: fontBold, fontSize: 24)),
                ),
                pw.SizedBox(height: 20),
                ...paragraphs.map((p) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.RichText(
                      text: pw.TextSpan(children: parseText(p.trim())),
                    ),
                  );
                }),
              ];
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  static Future<void> exportAndSharePdf(
      Map<String, dynamic> story, 
      List<dynamic> characters, 
      List<dynamic> chapters,
      {List<dynamic>? timeline}) async {
    final bytes = await generateStoryPdf(story, characters, chapters, timeline: timeline);
    String rawTitle = story['title'] ?? 'Story';
    String cleanFilename = rawTitle.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_').trim();
    if (cleanFilename.isEmpty) {
      cleanFilename = 'Story_Export';
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$cleanFilename.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Exported Story: $rawTitle');
    } catch (e) {
      debugPrint('ShareXFiles failed, falling back to Printing.sharePdf: $e');
      await Printing.sharePdf(bytes: bytes, filename: '$cleanFilename.pdf');
    }
  }
}
