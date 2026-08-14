import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ai_voice_docs/core/constants/supported_languages.dart';

import 'history_item.dart';

/// Renders one [HistoryItem] as a single-page PDF and writes it to a temp
/// file, ready to hand to `share_plus`. A fresh file is written per call
/// (named after the item id) rather than cached, since history entries are
/// small and this only runs on an explicit user tap.
class HistoryPdfGenerator {
  Future<File> generate(HistoryItem item) async {
    final isTranslation = item.type == HistoryItemType.translation;
    final sourceLang = languageByCode(item.sourceLanguageCode);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isTranslation ? 'Translation' : 'Voice Transcript',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                sourceLang.name,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(item.sourceText, style: const pw.TextStyle(fontSize: 14)),
              if (isTranslation) ...[
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text(
                  languageByCode(item.targetLanguageCode!).name,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  item.translatedText ?? '',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ai_voice_docs_${item.id}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
