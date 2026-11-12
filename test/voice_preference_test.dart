import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/core/utils/language_key.dart';

void main() {
  test('locale-qualified playback uses the saved language voice', () {
    expect(preferredVoice({'en': 'chosen'}, 'en-US'), 'chosen');
    expect(preferredVoice({'pt_BR': 'legacy'}, 'pt-PT'), 'legacy');
    expect(languageKey('EN_us'), 'en');
    expect(preferredVoice({'en': 'chosen'}, 'te-IN'), isNull);
  });
}
