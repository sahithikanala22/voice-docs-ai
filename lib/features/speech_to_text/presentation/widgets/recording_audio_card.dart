import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';
import '../providers/recording_playback_providers.dart';

String playbackTime(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

class RecordingAudioCard extends ConsumerWidget {
  const RecordingAudioCard({super.key, required this.recordingId});
  final String recordingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(retainedRecordingProvider(recordingId));
    final player = ref.watch(recordingPlaybackProvider);
    final active = player.recordingId == recordingId;
    final scheme = Theme.of(context).colorScheme;
    return recording.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Original audio is unavailable on this device. Your transcript is still here.',
        ),
      ),
      data: (item) {
        final passages = ref.watch(playbackPassagesProvider(recordingId));
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Original recording')),
                    Text(playbackTime(item.duration)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: active && player.playing
                          ? 'Pause original audio'
                          : 'Play original audio',
                      onPressed: player.loading || item.byteLength == 0
                          ? null
                          : () async {
                              await ref
                                  .read(ttsControllerProvider.notifier)
                                  .stop();
                              if (!context.mounted) return;
                              if (active && player.playing) {
                                await player.pause();
                              } else {
                                await player.play(recordingId);
                              }
                            },
                      icon: player.loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              active && player.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    Expanded(
                      child: Slider(
                        label: playbackTime(
                          active ? player.position : Duration.zero,
                        ),
                        value: active
                            ? player.position.inMilliseconds.toDouble().clamp(
                                0,
                                item.duration.inMilliseconds.toDouble(),
                              )
                            : 0,
                        max: item.duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        onChanged: active && !player.loading
                            ? (value) => player.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                    ),
                    Text(
                      playbackTime(active ? player.position : Duration.zero),
                    ),
                  ],
                ),
                if (player.error != null)
                  Text(player.error!, style: TextStyle(color: scheme.error)),
                if (item.segments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Tap a passage to replay',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: (passages.length * 76.0).clamp(90, 220),
                    child: ListView.builder(
                      itemCount: passages.length,
                      itemBuilder: (_, index) {
                        final segment = passages[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            playbackTime(segment.start),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          title: Text(segment.text),
                          selected:
                              active &&
                              player.position >= segment.start &&
                              player.position < segment.end,
                          selectedTileColor: scheme.primaryContainer,
                          onTap: player.loading
                              ? null
                              : () async {
                                  await ref
                                      .read(ttsControllerProvider.notifier)
                                      .stop();
                                  if (!context.mounted) return;
                                  await player.play(
                                    recordingId,
                                    from: segment.start,
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
