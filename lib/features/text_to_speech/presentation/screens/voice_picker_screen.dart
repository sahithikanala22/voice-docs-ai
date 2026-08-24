import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/widgets/empty_state.dart';

import '../../domain/tts_voice_option.dart';
import '../providers/tts_providers.dart';

/// Single-select list of the device's TTS voices for one language. Expects
/// `extra: {'languageCode': String, 'languageName': String, 'selectedVoiceName': String?}`
/// and pops with the chosen voice name, or the empty string `''` for
/// "device default" (distinct from `null`, which means "dismissed without a
/// choice" — the same three-way convention `showFolderPicker` uses).
class VoicePickerScreen extends ConsumerStatefulWidget {
  const VoicePickerScreen({
    super.key,
    required this.languageCode,
    required this.languageName,
    required this.selectedVoiceName,
  });

  final String languageCode;
  final String languageName;
  final String? selectedVoiceName;

  @override
  ConsumerState<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends ConsumerState<VoicePickerScreen> {
  late Future<List<TtsVoiceOption>> _voicesFuture;
  String? _previewingVoiceName;

  @override
  void initState() {
    super.initState();
    _voicesFuture = ref.read(ttsControllerProvider.notifier).getVoices(widget.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.languageName} voice')),
      body: SafeArea(
        child: FutureBuilder<List<TtsVoiceOption>>(
          future: _voicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final voices = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                _VoiceRow(
                  label: 'Device default',
                  subtitle: 'Whatever your phone normally uses for this language',
                  selected: widget.selectedVoiceName == null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                if (voices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.record_voice_over_outlined,
                      title: 'No alternate voices found',
                      subtitle: 'Your device only offers one voice for this language.',
                    ),
                  )
                else
                  for (final voice in voices)
                    _VoiceRow(
                      label: _friendlyVoiceName(voice.name),
                      subtitle: voice.locale,
                      selected: widget.selectedVoiceName == voice.name,
                      trailing: IconButton(
                        icon: Icon(
                          _previewingVoiceName == voice.name
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: scheme.primary,
                        ),
                        tooltip: 'Preview',
                        onPressed: () => _preview(voice),
                      ),
                      onTap: () => Navigator.pop(context, voice.name),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _preview(TtsVoiceOption voice) async {
    final controller = ref.read(ttsControllerProvider.notifier);
    if (_previewingVoiceName == voice.name) {
      await controller.stop();
      setState(() => _previewingVoiceName = null);
      return;
    }
    setState(() => _previewingVoiceName = voice.name);
    await ref
        .read(ttsRepositoryProvider)
        .speak('This is what I sound like.', widget.languageCode, voiceName: voice.name);
    if (mounted) setState(() => _previewingVoiceName = null);
  }

  /// Device voice names are usually opaque engine identifiers (e.g.
  /// `en-us-x-sfg-local`) — not pretty, but showing the raw name is more
  /// honest than inventing a "Voice 1/2/3" label that doesn't survive a
  /// device's voice list being reordered between app runs.
  String _friendlyVoiceName(String rawName) => rawName;
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              ?trailing,
              if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
