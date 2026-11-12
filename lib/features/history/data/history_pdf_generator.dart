import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/utils/export_filename.dart';
import 'history_item.dart';

/// Uses Flutter's native text shaping and font fallback for all scripts. Text
/// is embedded as high-resolution page images: readable offline, but not
/// selectable/searchable. Each page is laid out at line boundaries, including
/// transcripts longer than one page and mixed-direction paragraphs.
class HistoryPdfGenerator {
  Future<File> generate(HistoryItem item) async {
    final pages = _TranscriptPages();
    await pages.text('Voice Transcript', size: 22, bold: true);
    await pages.text(
      DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp),
      size: 11,
    );
    await pages.text(
      languageByCode(item.sourceLanguageCode).name,
      size: 12,
      bold: true,
    );
    await pages.text(item.sourceText, languageCode: item.sourceLanguageCode);
    return pages.save();
  }

  Future<File> generateDigest(
    List<HistoryItem> items, {
    required String title,
  }) async {
    final sorted = items.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final pages = _TranscriptPages();
    await pages.text(title, size: 22, bold: true);
    await pages.text(
      '${sorted.length} ${sorted.length == 1 ? 'entry' : 'entries'}',
      size: 11,
    );
    for (final item in sorted) {
      await pages.text(
        DateFormat('EEEE, MMM d, yyyy · h:mm a').format(item.timestamp),
        size: 11,
        bold: true,
      );
      await pages.text(item.sourceText, languageCode: item.sourceLanguageCode);
    }
    return pages.save();
  }
}

class _TranscriptPages {
  final _doc = pw.Document();
  final List<pw.Widget> _widgets = [];
  static final _width = PdfPageFormat.a4.width - 64;
  static final _height = PdfPageFormat.a4.height - 64;
  double _used = 0;

  Future<void> text(
    String text, {
    double size = 14,
    bool bold = false,
    String? languageCode,
  }) async {
    // Separate paragraphs to give mixed-direction documents correct local
    // direction and to avoid a single unbounded PDF text widget.
    for (final paragraph in text.split('\n')) {
      if (paragraph.isEmpty) {
        _space(size);
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: paragraph,
          style: TextStyle(
            fontSize: size,
            height: 1.4,
            color: const Color(0xff171725),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: Bidi.detectRtlDirectionality(paragraph)
            ? ui.TextDirection.rtl
            : ui.TextDirection.ltr,
        locale: languageCode == null ? null : ui.Locale(languageCode),
      );
      painter.layout(maxWidth: _width);
      final lines = painter.computeLineMetrics();
      var first = 0;
      while (first < lines.length) {
        final top = first == 0
            ? 0.0
            : lines[first].baseline - lines[first].ascent;
        var last = first;
        var bottom = lines[last].baseline + lines[last].descent + 1;
        if (bottom - top > _height - _used && _widgets.isNotEmpty) _flush();
        while (last + 1 < lines.length &&
            lines[last + 1].baseline + lines[last + 1].descent + 1 - top <=
                _height - _used) {
          last++;
          bottom = lines[last].baseline + lines[last].descent + 1;
        }
        final height = bottom - top;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.scale(2);
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, _width, height),
          ui.Paint()..color = const Color(0xffffffff),
        );
        canvas.clipRect(ui.Rect.fromLTWH(0, 0, _width, height));
        painter.paint(canvas, ui.Offset(0, -top));
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          (_width * 2).ceil(),
          (height * 2).ceil(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        _widgets.add(
          pw.Image(
            pw.MemoryImage(png!.buffer.asUint8List()),
            width: _width,
            height: height,
          ),
        );
        _used += height;
        first = last + 1;
        if (first < lines.length) _flush();
      }
      painter.dispose();
      _space(8);
    }
  }

  void _space(double value) {
    if (_used + value > _height) {
      _flush();
    } else if (_widgets.isNotEmpty) {
      _widgets.add(pw.SizedBox(height: value));
      _used += value;
    }
  }

  void _flush() {
    if (_widgets.isEmpty) return;
    final widgets = List<pw.Widget>.from(_widgets);
    _doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
    _widgets.clear();
    _used = 0;
  }

  Future<File> save() async {
    _flush();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voicedocsai_${exportFilenameStamp()}.pdf');
    await file.writeAsBytes(await _doc.save(), flush: true);
    return file;
  }
}
