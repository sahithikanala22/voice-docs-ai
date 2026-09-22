import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'package:ai_voice_docs/features/speech_to_text/data/providers/whisper_speech_provider.dart';

/// Shows whether Whisper's offline model has been downloaded yet, and lets
/// it be fetched ahead of time — with no API key to enter, this is the only
/// setup this engine needs. Downloading here means the first real recording
/// doesn't stall on a ~140MB fetch.
class WhisperSpeechSettings extends StatefulWidget {
  const WhisperSpeechSettings({super.key});

  @override
  State<WhisperSpeechSettings> createState() => _WhisperSpeechSettingsState();
}

class _WhisperSpeechSettingsState extends State<WhisperSpeechSettings> {
  final _controller = WhisperController();

  /// null while the initial existence check is still running.
  bool? _downloaded;
  bool _downloading;
  String? _error;

  _WhisperSpeechSettingsState() : _downloading = false;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final path = await _controller.getPath(whisperSpeechModel);
    if (mounted) setState(() => _downloaded = File(path).existsSync());
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await _controller.downloadModel(whisperSpeechModel);
      if (mounted) setState(() => _downloaded = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not download the model: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_downloaded == null)
            Row(
              children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Checking for the offline model…', style: textTheme.bodyMedium),
              ],
            )
          else if (_downloaded!)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline model ready — works without internet from here on',
                    style: textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Model not downloaded yet (~140MB, one time)',
                    style: textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _downloading ? null : _download,
                  child: _downloading
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Download'),
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: textTheme.bodySmall?.copyWith(color: scheme.error)),
          ],
          const SizedBox(height: 10),
          Text(
            'Free and works fully offline once downloaded — no API key, no per-use cost. Runs '
            'OpenAI\'s Whisper model on your phone; generally more accurate than the on-device '
            'engine, especially with accents, at the cost of more battery/CPU per recording. If '
            'you don\'t download it here, the first recording downloads it instead.',
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
