import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/core/widgets/app_session_guard.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_state.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';
import 'support/fakes.dart';

class _Unlocked extends AppLockController {
  @override
  Future<AppLockState> build() async => const AppLockState(
    account: AppLockAccount(name: 'Owner', pinHash: 'test'),
    isUnlocked: true,
  );
}

class _SilentTts extends TtsController {
  @override
  bool build() => false;
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('backgrounding obscures the app, stops recording, and relocks', (
    tester,
  ) async {
    final speech = FakeSpeech();
    final owner = RecordingCoordinator(
      repository: () => speech,
      requestPermission: () async => true,
    );
    final container = ProviderContainer(
      overrides: [
        appLockControllerProvider.overrideWith(_Unlocked.new),
        recordingCoordinatorProvider.overrideWithValue(owner),
        ttsControllerProvider.overrideWith(_SilentTts.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(owner.dispose);
    await container.read(appLockControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppSessionGuard(
          child: MaterialApp(home: Scaffold(body: Text('Private entry'))),
        ),
      ),
    );
    await owner.start(tag: 'home', locale: 'en-US', onChanged: (_) {});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(
      container.read(appLockControllerProvider).value!.isUnlocked,
      isFalse,
    );
    expect(speech.isListening, isFalse);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      container.read(appLockControllerProvider).value!.isUnlocked,
      isFalse,
    );
  });
}
