import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import '../../data/pending_recording_store.dart';
import '../../data/providers/google_cloud_speech_provider.dart';
import '../../data/providers/durable_recording_provider.dart';
import '../../data/providers/whisper_speech_provider.dart';
import '../../domain/recording_phase.dart';
import '../../domain/speech_engine.dart';
import '../providers/speech_providers.dart';
import '../providers/whisper_providers.dart';

class RecoverRecordingsScreen extends ConsumerStatefulWidget {
  const RecoverRecordingsScreen({super.key});
  @override
  ConsumerState<RecoverRecordingsScreen> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<RecoverRecordingsScreen>
    with WidgetsBindingObserver {
  late final PendingRecordingStore _store;
  late Future<List<PendingRecording>> _items;
  Future<int>? _usage;
  bool _busy = false;
  DurableRecordingProvider? _retryProvider;
  SpeechEngine _retryEngine = SpeechEngine.whisper;
  AudioPlayer? _player;
  String? _playing;
  StreamSubscription<void>? _completed;
  final _temporaryFiles = <File>[];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = PendingRecordingStore(
      PrivateStore(ref.read(sharedPreferencesProvider)),
    );
    _items = _store.list();
    _usage = _store.storageBytes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_stopPlayback());
      unawaited(_retryProvider?.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_retryProvider?.cancel());
    unawaited(_completed?.cancel());
    unawaited(_player?.dispose());
    for (final file in _temporaryFiles) {
      unawaited(_removeFile(file));
    }
    super.dispose();
  }

  Future<void> _removeFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _items = _store.list();
        _usage = _store.storageBytes();
      });
    }
  }

  Future<void> _stopPlayback() async {
    await _player?.stop();
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(recordingCoordinatorProvider)
          .stop(cancelTranscription: true);
      await _stopPlayback();
      if (mounted) await work();
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not finish. Your original audio has not been deleted. Check storage, permissions and connection.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Recover recordings'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
          tooltip: 'Refresh recordings',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<PendingRecording>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saved recordings could not be opened. No audio was deleted.',
                ),
                TextButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Audio stays on this device until you explicitly delete it, even after saving a transcript. '
              'There is no automatic expiry. Up to 10 recordings and 256 MiB of PCM per recording '
              '(about 2 hours 20 minutes) are supported. Sealing audio needs extra free space. '
              'Whisper retries run on this device after a one-time model download. '
              'Google Cloud is optional and requires explicit upload consent and an API key. '
              'Device dictation audio is not archived. Use Record meeting for durable capture.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SpeechEngine>(
              initialValue: _retryEngine,
              decoration: const InputDecoration(
                labelText: 'Transcription engine',
              ),
              items: [
                for (final engine in [
                  SpeechEngine.whisper,
                  SpeechEngine.googleCloud,
                ])
                  DropdownMenuItem(value: engine, child: Text(engine.label)),
              ],
              onChanged: _busy
                  ? null
                  : (engine) {
                      if (engine != null) setState(() => _retryEngine = engine);
                    },
            ),
            TextButton(
              onPressed: _busy ? null : () => context.push('/settings'),
              child: const Text('Download or check Whisper model in Settings'),
            ),
            FutureBuilder<int>(
              future: _usage,
              builder: (_, usage) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${items.length}/10 recordings · ${usage.hasData ? (usage.data! / (1024 * 1024)).toStringAsFixed(1) : "…"} MiB used',
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_busy && _retryProvider != null)
              TextButton(
                onPressed: () => _retryProvider?.cancel(),
                child: const Text(
                  'Cancel transcription (keep audio and progress)',
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No saved recordings.'),
              ),
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().add_jm().format(item.createdAt),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${item.locale} · ${item.duration.inMinutes}m ${item.duration.inSeconds % 60}s · '
                        '${item.phase.name} · ${item.chunks.length} chunks transcribed',
                      ),
                      Text(
                        item.historyId == null
                            ? 'Audio retained; transcript ${item.transcript.isEmpty ? "pending" : "available"}'
                            : 'Saved to History; original audio retained',
                      ),
                      if (item.error != null)
                        Text(
                          item.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _busy || item.byteLength == 0
                                ? null
                                : () => _play(item),
                            icon: Icon(
                              _playing == item.id
                                  ? Icons.stop
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              _playing == item.id ? 'Stop playback' : 'Play',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _busy || item.byteLength == 0
                                ? null
                                : () => _export(item),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Export WAV'),
                          ),
                          TextButton(
                            onPressed: _busy || item.byteLength == 0
                                ? null
                                : () => _retry(item),
                            child: Text(
                              item.chunks.isEmpty
                                  ? 'Transcribe'
                                  : 'Retry unfinished chunks',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy || item.transcript.isEmpty
                                ? null
                                : () => _run(() => _review(item)),
                            child: const Text('Review transcript'),
                          ),
                          TextButton.icon(
                            onPressed: _busy ? null : () => _delete(item),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete audio'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> _play(PendingRecording item) async {
    if (_playing == item.id) {
      await _stopPlayback();
      return;
    }
    await _run(() async {
      final file = await _store.exportWav(
        item.id,
        await getTemporaryDirectory(),
      );
      _temporaryFiles.add(file);
      if (!mounted) {
        await _removeFile(file);
        return;
      }
      if (_player == null) {
        _player = AudioPlayer();
        _completed = _player!.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = null);
        });
      }
      await _player!.play(DeviceFileSource(file.path, mimeType: 'audio/wav'));
      if (mounted) setState(() => _playing = item.id);
    });
  }

  Future<void> _export(PendingRecording item) => _run(() async {
    final file = await _store.exportWav(item.id, await getTemporaryDirectory());
    _temporaryFiles.add(file);
    if (!mounted) {
      await _removeFile(file);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'audio/wav')],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  });
  Future<void> _delete(PendingRecording item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this recording?'),
        content: const Text(
          'Permanently remove this audio and its recovery transcript/chunks. '
          'A transcript already saved to History and files already shared elsewhere remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await WhisperSpeechProvider.cleanupScratch(
        await getTemporaryDirectory(),
        recordingId: item.id,
      );
      await _store.delete(item.id);
      final temp = File(
        '${(await getTemporaryDirectory()).path}/voicedocsai_recording_${item.id}.wav',
      );
      await _removeFile(temp);
    });
  }

  Future<void> _retry(PendingRecording item) async {
    if (item.locale == 'und') {
      final locale = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Choose the original recording language'),
          children: [
            for (final language in kSupportedLanguages)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, language.localeHint),
                child: Text(language.name),
              ),
          ],
        ),
      );
      if (locale == null || !mounted) return;
      try {
        await _store.setUnknownLocale(item.id, locale);
        item = await _store.get(item.id);
      } catch (_) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Could not update recording language.',
            isError: true,
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final key =
        ref.read(settingsControllerProvider).value?.googleCloudApiKey ?? '';
    if (_retryEngine == SpeechEngine.googleCloud && key.trim().isEmpty) {
      AppSnackbar.show(
        context,
        'Add your Google Cloud API key in Settings before retrying.',
        isError: true,
      );
      return;
    }
    if (_retryEngine == SpeechEngine.whisper) {
      try {
        await ref.read(whisperModelStoreProvider).requireReady();
      } catch (_) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Download or retry the Whisper model in Settings > Speech Recognition. Your saved audio is kept.',
            isError: true,
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final yes =
        _retryEngine == SpeechEngine.whisper ||
        await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Transcribe with Google Cloud?'),
                content: Text(
                  'Upload unfinished chunks of this ${item.locale} recording to Google. '
                  'Completed chunks are reused. Internet and your API key are required; charges may apply.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Upload and retry'),
                  ),
                ],
              ),
            ) ==
            true;
    if (yes != true || !mounted) return;
    await _run(() async {
      final DurableRecordingProvider provider =
          _retryEngine == SpeechEngine.whisper
          ? WhisperSpeechProvider(
              models: ref.read(whisperModelStoreProvider),
              recoveryStore: _store,
            )
          : GoogleCloudSpeechProvider(apiKey: key, recoveryStore: _store);
      setState(() => _retryProvider = provider);
      try {
        await provider.transcribeRetained(item);
        if (mounted) await _review(await _store.get(item.id));
      } finally {
        await provider.cancel();
        if (mounted) setState(() => _retryProvider = null);
      }
    });
  }

  Future<void> _review(PendingRecording item) async {
    final editor = TextEditingController(text: item.transcript);
    var date = item.entryDate ?? item.createdAt;
    try {
      final edited = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
            title: const Text('Review recovered entry'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.phase != RecordingPhase.completed)
                      const Text(
                        'Partial transcript: unfinished audio is still available for retry.',
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat.yMMMd().format(date)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: c,
                          initialDate: date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && c.mounted) {
                          update(() => date = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: editor,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Transcript',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Keep for later'),
              ),
              FilledButton(
                onPressed:
                    item.historyId != null ||
                        item.phase != RecordingPhase.completed
                    ? null
                    : () {
                        if (editor.text.trim().isNotEmpty) {
                          Navigator.pop(c, editor.text.trim());
                        }
                      },
                child: Text(
                  item.historyId == null ? 'Save to History' : 'Already saved',
                ),
              ),
            ],
          ),
        ),
      );
      if (edited != null && mounted) {
        await ref
            .read(historyControllerProvider.notifier)
            .addEntry(
              HistoryItem(
                id: item.transcriptId,
                sourceText: edited,
                sourceLanguageCode: item.locale.split('-').first,
                timestamp: date,
                folderId: item.folderId,
              ),
            );
        await _store.markSaved(item.id);
        if (mounted) {
          AppSnackbar.show(
            context,
            'Transcript saved. Original audio remains available.',
          );
        }
      }
    } finally {
      editor.dispose();
    }
  }
}
