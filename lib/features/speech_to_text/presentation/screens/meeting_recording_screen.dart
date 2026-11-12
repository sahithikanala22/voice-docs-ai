import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import '../providers/speech_providers.dart';

class MeetingRecordingScreen extends ConsumerWidget {
  const MeetingRecordingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speechControllerProvider('meeting'));
    final settings = ref.watch(settingsControllerProvider).value;
    final language = languageByCode(settings?.sourceLanguageCode ?? 'en');
    final active = state.isListening || state.isProcessing;
    ref.listen(speechControllerProvider('meeting'), (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Record meeting')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Save audio first',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Records directly to this device without internet or a speech model. '
            'Transcribe later from Recover recordings using Google Cloud. '
            'This recorder and live dictation never use the microphone together.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep this screen open. Leaving, locking the phone, a call or a '
            'detected headset disconnection ends capture and keeps the audio already written. '
            'Recording does not automatically resume.',
          ),
          const SizedBox(height: 24),
          Text('Recording language: ${language.name}'),
          Text('State: ${state.phase.name}'),
          Text(
            state.isListening
                ? 'Microphone active · saving audio on this device'
                : state.audioSaved
                ? 'Microphone off · audio retained on this device'
                : 'Microphone off',
          ),
          if (state.isProcessing) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: state.isProcessing
                ? null
                : () {
                    final controller = ref.read(
                      speechControllerProvider('meeting').notifier,
                    );
                    if (state.isListening) {
                      controller.stopListening();
                    } else {
                      controller.startListening(
                        language.localeHint,
                        savedAudioOnly: true,
                        timestamp: DateTime.now(),
                        folderId: settings?.currentFolderId,
                      );
                    }
                  },
            icon: Icon(state.isListening ? Icons.stop : Icons.mic),
            label: Text(
              state.isListening ? 'Stop and keep audio' : 'Start recording',
            ),
          ),
          TextButton.icon(
            onPressed: active
                ? null
                : () => context.push('/recover-recordings'),
            icon: const Icon(Icons.library_music_outlined),
            label: const Text('Open saved recordings'),
          ),
        ],
      ),
    );
  }
}
