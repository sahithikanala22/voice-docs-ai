import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/whisper_model_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/whisper_providers.dart';

class WhisperSpeechSettings extends ConsumerWidget {
  const WhisperSpeechSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whisperModelControllerProvider);
    final controller = ref.read(whisperModelControllerProvider.notifier);
    final percent = state.total > 0
        ? (state.received / state.total).clamp(0.0, 1.0)
        : null;
    final ready = state.phase == WhisperModelPhase.ready;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Whisper multilingual base model · 142 MiB'),
          const SizedBox(height: 8),
          const Text(
            'One internet download, then free offline transcription. '
            'Supports English, Hindi and Telugu language selection. Accuracy varies by language and recording conditions; '
            'review mixed-language speech against your saved audio. '
            'Keep extra free space for recordings and model memory.',
          ),
          const SizedBox(height: 12),
          Text(switch (state.phase) {
            WhisperModelPhase.ready =>
              'Ready — model size and SHA-256 verified',
            WhisperModelPhase.missing =>
              'Model not downloaded. Audio can still be recorded and saved.',
            WhisperModelPhase.checking => 'Checking saved model…',
            WhisperModelPhase.downloading =>
              'Downloading model: ${((percent ?? 0) * 100).toStringAsFixed(0)}% '
                  '(${(state.received / 1048576).toStringAsFixed(1)} / 142 MiB)',
            WhisperModelPhase.verifying => 'Verifying model integrity…',
            WhisperModelPhase.failed =>
              state.error ?? 'Model unavailable. Retry download.',
          }),
          if (state.busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.phase == WhisperModelPhase.downloading
                  ? percent
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (!ready && !state.busy)
                FilledButton.icon(
                  onPressed: controller.download,
                  icon: const Icon(Icons.download),
                  label: Text(
                    state.phase == WhisperModelPhase.failed
                        ? 'Retry download'
                        : 'Download model',
                  ),
                ),
              if (state.phase == WhisperModelPhase.downloading)
                TextButton(
                  onPressed: controller.cancel,
                  child: const Text('Cancel download'),
                ),
              if (!state.busy)
                TextButton(
                  onPressed: controller.refresh,
                  child: const Text('Check model'),
                ),
            ],
          ),
          const Text(
            'Record with the screen awake. After Stop, the microphone is off while Whisper processes locally. '
            'If you leave or cancel, the current native chunk may finish before stopping; its late result is ignored.',
          ),
        ],
      ),
    );
  }
}
