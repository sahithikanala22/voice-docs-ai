import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Builds the Quill [Document] to start editing/reading an entry's body
/// from: its saved [bodyDelta] when there is one, otherwise a plain,
/// unstyled document from [plainBody] — which is what every entry saved
/// before rich text existed has.
///
/// A delta that fails to parse (corrupted prefs, a future format this build
/// doesn't understand) falls back to the plain text rather than losing the
/// entry or crashing the screen.
Document diaryDocumentFrom({String? bodyDelta, required String plainBody}) {
  if (bodyDelta != null) {
    try {
      return Document.fromJson(jsonDecode(bodyDelta) as List);
    } catch (_) {
      // Fall through to the plain-text reconstruction below.
    }
  }
  return _plainTextDocument(plainBody);
}

/// The document's content as a JSON string — used to compare "has this
/// changed since editing began" without holding onto a second `Document`.
String jsonEncodeDelta(Document document) => jsonEncode(document.toDelta().toJson());

Document _plainTextDocument(String text) {
  if (text.isEmpty) return Document();
  return Document.fromDelta(Delta()..insert(text)..insert('\n'));
}

/// The two fields [DiaryEntry] stores for a body: the rich delta (as JSON,
/// ready to persist) and its plain-text mirror (for search/previews).
typedef DiaryBodyFields = ({String plainText, String delta});

/// Extracts both storage fields from a controller's current document.
/// [Document.toPlainText] always carries a trailing newline; trimmed here so
/// [DiaryBodyFields.plainText] matches what a freshly-typed plain body would
/// have been.
DiaryBodyFields diaryBodyFieldsFrom(QuillController controller) {
  final doc = controller.document;
  final plainText = doc.toPlainText().replaceAll(RegExp(r'\n$'), '');
  final delta = jsonEncode(doc.toDelta().toJson());
  return (plainText: plainText, delta: delta);
}
