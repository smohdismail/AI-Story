import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExport {
  static Future<Uint8List> generateStoryPdf(
      Map<String, dynamic> story, 
      List<dynamic> characters, 
      List<dynamic> chapters) async {
    
    final pdf = pw.Document();

    // Use a classic Serif font.
    final font = await PdfGoogleFonts.merriweatherRegular();
    final fontItalic = await PdfGoogleFonts.merriweatherItalic();
    final fontBold = await PdfGoogleFonts.merriweatherBold();

    final normalStyle = pw.TextStyle(font: font, fontSize: 12, lineSpacing: 2);
    final italicStyle = pw.TextStyle(font: fontItalic, fontSize: 12, lineSpacing: 2);
    
    String title = story['title'] ?? '';
    String subtitle = story['synopsis'] ?? '';
    
    if (title.isEmpty || title == 'Untitled Story') {
       if (characters.isNotEmpty) {
           final charNames = characters.map((c) => c['full_name']).toList();
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
                pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 36), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 20),
                if (story['genre'] != null && story['genre'].toString().isNotEmpty)
                  pw.Text(story['genre'], style: pw.TextStyle(font: fontItalic, fontSize: 18, color: PdfColors.grey600)),
                pw.SizedBox(height: 40),
                if (subtitle.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 50),
                    child: pw.Text(subtitle, style: pw.TextStyle(font: font, fontSize: 14), textAlign: pw.TextAlign.center),
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
        // Even indices are normal text, odd indices are within asterisks (italic)
        if (i % 2 == 0) {
          spans.add(pw.TextSpan(text: parts[i], style: normalStyle));
        } else {
          spans.add(pw.TextSpan(text: parts[i], style: italicStyle));
        }
      }
      return spans;
    }

    // Chapters
    for (var chapter in chapters) {
      final content = chapter['content'] ?? '';
      if (content.isEmpty) continue;

      // Split content by double newlines to make paragraphs
      final paragraphs = content.split('\n\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Chapter ${chapter['chapter_number']}: ${chapter['title'] ?? ''}', style: pw.TextStyle(font: fontBold, fontSize: 24)),
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

    return pdf.save();
  }

  static Future<void> exportAndSharePdf(Map<String, dynamic> story, List<dynamic> characters, List<dynamic> chapters) async {
    final bytes = await generateStoryPdf(story, characters, chapters);
    String title = story['title'] ?? 'Story';
    if (title.isEmpty || title == 'Untitled Story') {
        title = 'My_Story';
    }
    // Clean filename
    title = title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    
    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }
}
