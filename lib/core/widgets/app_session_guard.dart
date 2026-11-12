import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

class AppSessionGuard extends ConsumerStatefulWidget {
  const AppSessionGuard({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppSessionGuard> createState() => _AppSessionGuardState();
}

class _AppSessionGuardState extends ConsumerState<AppSessionGuard>
    with WidgetsBindingObserver {
  bool _obscured = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _obscured = state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(
        ref.read(recordingCoordinatorProvider).stop(cancelTranscription: true),
      );
      unawaited(ref.read(ttsControllerProvider.notifier).stop());
      ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    children: [
      widget.child,
      if (_obscured)
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0xff151524),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                textDirection: TextDirection.ltr,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
    ],
  );
}
