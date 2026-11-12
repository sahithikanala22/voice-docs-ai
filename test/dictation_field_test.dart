import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/core/widgets/dictation_field.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recognition_state.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'support/fakes.dart';

class _Settings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class _ControlledSpeech extends SpeechController {
  @override
  RecognitionState build(String tag) => const RecognitionState();
  void emit(RecognitionState value) => state = value;
}

void main() {
  for (final tag in ['tasks-add', 'add-entry-source']) {
    testWidgets('$tag applies final text after listening has ended', (
      tester,
    ) async {
      final text = TextEditingController();
      final owner = RecordingCoordinator(
        repository: () => FakeSpeech(),
        requestPermission: () async => true,
      );
      final container = ProviderContainer(
        overrides: [
          settingsControllerProvider.overrideWith(_Settings.new),
          recordingCoordinatorProvider.overrideWithValue(owner),
          speechControllerProvider.overrideWith(_ControlledSpeech.new),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(owner.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DictationField(
                controller: text,
                sessionTag: tag,
                localeHint: 'en-US',
              ),
            ),
          ),
        ),
      );
      final controller =
          container.read(speechControllerProvider(tag).notifier)
              as _ControlledSpeech;
      controller.emit(
        const RecognitionState(isListening: true, transcript: 'partial'),
      );
      await tester.pump();
      controller.emit(
        const RecognitionState(
          isListening: false,
          transcript: 'complete final words',
        ),
      );
      await tester.pump();
      expect(text.text, 'complete final words');
      text.text = 'user edited text';
      controller.emit(
        const RecognitionState(
          isListening: false,
          transcript: 'complete final words',
          errorMessage: 'status only',
        ),
      );
      await tester.pump();
      expect(text.text, 'user edited text');
      await tester.pumpWidget(const SizedBox());
      text.dispose();
    });
  }
}
