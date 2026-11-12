import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'app_snackbar.dart';

/// Applies transcript changes, including final results delivered after stop.
class DictationField extends ConsumerStatefulWidget {
  const DictationField({
    super.key,
    required this.controller,
    required this.sessionTag,
    required this.localeHint,
    this.hint = 'Type or speak',
    this.autofocus = false,
    this.disposeController = false,
    this.maxLines = 3,
    this.minLines = 1,
    this.showPrivacyDescription = true,
  });
  final TextEditingController controller;
  final String sessionTag;
  final String localeHint;
  final String hint;
  final bool autofocus;
  final bool disposeController;
  final int maxLines;
  final int minLines;
  final bool showPrivacyDescription;
  @override
  ConsumerState<DictationField> createState() => _DictationFieldState();
}

class _DictationFieldState extends ConsumerState<DictationField> {
  late final Future<void> Function() _stop;
  @override
  void initState() {
    super.initState();
    final owner = ref.read(recordingCoordinatorProvider);
    final tag = widget.sessionTag;
    _stop = () => owner.stop(tag: tag);
  }

  @override
  void dispose() {
    unawaited(_stop());
    if (widget.disposeController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = speechControllerProvider(widget.sessionTag);
    final recognition = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.transcript != previous?.transcript) {
        widget.controller.value = TextEditingValue(
          text: next.transcript,
          selection: TextSelection.collapsed(offset: next.transcript.length),
        );
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });
    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        helperText: widget.showPrivacyDescription
            ? (ref.watch(settingsControllerProvider).value?.speechEngine ??
                      SpeechEngine.onDevice)
                  .privacyDescription
            : null,
        helperMaxLines: 8,
        hintText: recognition.isProcessing
            ? 'Finishing dictation…'
            : recognition.isListening
            ? 'Listening…'
            : widget.hint,
        suffixIcon: IconButton(
          tooltip: recognition.isListening ? 'Stop' : 'Dictate',
          icon: Icon(
            recognition.isListening
                ? Icons.stop_circle_rounded
                : Icons.mic_rounded,
          ),
          onPressed: recognition.isProcessing
              ? null
              : () async {
                  final controller = ref.read(provider.notifier);
                  if (recognition.isListening) {
                    await controller.stopListening();
                  } else {
                    await controller.startListening(widget.localeHint);
                  }
                },
        ),
      ),
    );
  }
}
