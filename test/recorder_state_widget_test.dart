import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_phase.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/widgets/voice_recording_panel.dart';

void main() {
  testWidgets(
    'transcription is visibly separate from active microphone capture',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecordingPanel(
              listening: false,
              processing: true,
              phase: RecordingPhase.transcribing,
              audioSaved: true,
              level: 0,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('TRANSCRIBING · MICROPHONE OFF'), findsOneWidget);
      expect(find.text('RECORDING'), findsNothing);
      expect(
        find.text('Microphone off. Your audio is kept in Saved recordings.'),
        findsOneWidget,
      );
      expect(find.text('00:00'), findsNothing);
    },
  );
}
