import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/features/diary/presentation/widgets/diary_document.dart';

QuillController _controllerFor(String plainBody) => QuillController(
  document: diaryDocumentFrom(plainBody: plainBody),
  selection: const TextSelection.collapsed(offset: 0),
);

void main() {
  group('diaryDocumentFrom', () {
    test('an empty legacy body produces an empty document', () {
      final doc = diaryDocumentFrom(plainBody: '');
      expect(doc.isEmpty(), isTrue);
    });

    test('a legacy plain body round-trips through the document as-is', () {
      final doc = diaryDocumentFrom(plainBody: 'Dear diary, today was good.');
      expect(doc.toPlainText(), 'Dear diary, today was good.\n');
    });

    test('a saved delta is used over the plain body when both are present', () {
      final delta = jsonEncode(
        (Delta()..insert('styled text')..insert('\n')).toJson(),
      );
      final doc = diaryDocumentFrom(bodyDelta: delta, plainBody: 'stale plain mirror');
      expect(doc.toPlainText(), 'styled text\n');
    });

    test('a corrupted delta falls back to the plain body instead of throwing', () {
      final doc = diaryDocumentFrom(bodyDelta: 'not valid json at all', plainBody: 'fallback text');
      expect(doc.toPlainText(), 'fallback text\n');
    });

    test('an unparsable-but-valid-JSON delta (not a list) also falls back', () {
      final doc = diaryDocumentFrom(bodyDelta: '{"not": "a list"}', plainBody: 'fallback text');
      expect(doc.toPlainText(), 'fallback text\n');
    });
  });

  group('diaryBodyFieldsFrom', () {
    test('plain text has no trailing newline in the extracted plainText', () {
      final controller = _controllerFor('hello world');
      final fields = diaryBodyFieldsFrom(controller);
      expect(fields.plainText, 'hello world');
    });

    test('an empty document extracts as empty plain text', () {
      final controller = _controllerFor('');
      final fields = diaryBodyFieldsFrom(controller);
      expect(fields.plainText, '');
    });

    test('the delta round-trips back through diaryDocumentFrom unchanged', () {
      final controller = _controllerFor('round trip me');
      controller.formatText(0, 5, Attribute.bold);
      final fields = diaryBodyFieldsFrom(controller);

      final reloaded = diaryDocumentFrom(bodyDelta: fields.delta, plainBody: fields.plainText);
      expect(reloaded.toPlainText(), controller.document.toPlainText());
      expect(jsonEncodeDelta(reloaded), fields.delta);
    });

    test('bold formatting survives a save/reload round trip', () {
      final controller = _controllerFor('bold word here');
      controller.formatText(0, 4, Attribute.bold);
      final fields = diaryBodyFieldsFrom(controller);

      final reloaded = diaryDocumentFrom(bodyDelta: fields.delta, plainBody: fields.plainText);
      final ops = reloaded.toDelta().toJson();
      final firstOp = ops.first as Map;
      expect(firstOp['insert'], 'bold');
      expect((firstOp['attributes'] as Map)['bold'], isTrue);
    });
  });

  group('jsonEncodeDelta', () {
    test('two documents with the same content encode identically', () {
      final a = diaryDocumentFrom(plainBody: 'same text');
      final b = diaryDocumentFrom(plainBody: 'same text');
      expect(jsonEncodeDelta(a), jsonEncodeDelta(b));
    });

    test('differing content encodes differently', () {
      final a = diaryDocumentFrom(plainBody: 'first');
      final b = diaryDocumentFrom(plainBody: 'second');
      expect(jsonEncodeDelta(a), isNot(jsonEncodeDelta(b)));
    });
  });
}
