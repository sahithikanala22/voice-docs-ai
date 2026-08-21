import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';

import 'history_item.dart';

/// Renders one [HistoryItem] as a minimal but valid `.docx` (Word) file and
/// writes it to a temp file, ready to hand to `share_plus`.
///
/// A `.docx` is just a zip of a handful of small OOXML parts — hand-rolling
/// those four parts avoids depending on a niche/unmaintained "docx" pub
/// package for what's plain paragraph text with no tables, images, or
/// complex formatting. `archive` (already a transitive dependency via `pdf`)
/// provides the zip writer.
class HistoryWordGenerator {
  Future<File> generate(HistoryItem item) async {
    final sourceLang = languageByCode(item.sourceLanguageCode);

    final body = StringBuffer()
      ..write(_paragraph('Voice Transcript', bold: true, size: 32))
      ..write(_paragraph(DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp), size: 18, colorHex: '666666'))
      ..write(_emptyParagraph())
      ..write(_paragraph(sourceLang.name, bold: true, size: 22))
      ..write(_paragraph(item.sourceText, size: 24));

    final documentXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body<w:sectPr/></w:body>'
        '</w:document>';

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRelsXml))
      ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', _documentRelsXml))
      ..addFile(ArchiveFile.string('word/document.xml', documentXml));

    final bytes = ZipEncoder().encode(archive);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ai_voice_docs_${item.id}.docx');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _paragraph(String text, {bool bold = false, int size = 24, String? colorHex}) {
    final props = StringBuffer();
    if (bold) props.write('<w:b/>');
    if (colorHex != null) props.write('<w:color w:val="$colorHex"/>');
    props.write('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
    return '<w:p><w:r><w:rPr>$props</w:rPr>'
        '<w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';
  }

  String _emptyParagraph() => '<w:p/>';

  String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const _contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const _rootRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  static const _documentRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>';
}
