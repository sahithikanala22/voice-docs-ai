import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/data/history_pdf_generator.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('voice_pdf_test_');
    PathProviderPlatform.instance = FakePaths(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));
  test(
    'a long multilingual transcript paginates without overflow',
    () async {
      final text = List.filled(
        150,
        'English text తెలుగు జర్నల్ हिंदी العربية עברית 日本語 中文. Long transcripts must retain every line.',
      ).join('\n');
      final file = await HistoryPdfGenerator().generate(
        HistoryItem.voice(text: text, languageCode: 'te'),
      );
      final bytes = await file.readAsBytes();
      final pdf = latin1.decode(bytes);
      expect(pdf, startsWith('%PDF-'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, greaterThan(2));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'a digest handles an individual paragraph longer than a page',
    () async {
      final item = HistoryItem.voice(
        text: List.filled(
          600,
          'A long unbroken paragraph has to span pages.',
        ).join(' '),
        languageCode: 'en',
      );
      final file = await HistoryPdfGenerator().generateDigest([
        item,
      ], title: 'Monthly journal');
      final pdf = latin1.decode(await file.readAsBytes());
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, greaterThan(2));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
