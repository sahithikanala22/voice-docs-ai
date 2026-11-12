# Whisper offline transcription

## Diagnosis (2026-10-23)

The working checkout is on local `master`, committed at `e2854ec`, with extensive
uncommitted diary, privacy, lock and recorder improvements. At inspection it had
no `whisper_ggml` dependency, Whisper provider, model settings widget or Whisper
engine enum value. Its Settings screen offered only device speech and Google
Cloud. The connected V2420 reported installed version code **6**, the artifact
previously built from this checkout. This is source/build evidence for the
missing option; reinstalling that same artifact would not enable Whisper.

A read-only remote comparison followed by `git fetch origin master` found newer
remote `master` at `010f12d`. That revision does contain `whisper_ggml: ^2.6.0`,
the Whisper provider, selector and model-download widget described in the
request. Remote refs were updated; the local branch and working changes were
preserved. The remote integration streams PCM into Whisper without a durable
audio archive and treats model-file existence as readiness. This implementation
uses the same Whisper plugin and multilingual base model with the local durable
recorder, verified downloads and retryable file transcription.

The regular entry point is `lib/main.dart` → `AiVoiceDocsApp` → the app router.
`/settings` uses `SettingsScreen`; the Voice profile action opens that route.
There are no Android product flavors or platform conditions hiding Whisper in
this checkout. Speech Recognition is now the first Settings section, and Voice
has a direct **Whisper — Free Offline** shortcut to it. The offline selector is
always visible. Existing engine preferences are preserved until the user changes
them. The new Android artifact is **1.0.0+7**, package `com.aivoicedocs.app`.

## Implemented flow

1. Select **Whisper — Free Offline** in Settings → Speech Recognition.
2. Download the multilingual **base** model once (147,951,465 bytes, about
   142 MiB). Progress, cancellation, retry, integrity verification and a verified
   Ready state are visible. A partial or corrupt file cannot become Ready.
3. Choose the spoken language on Voice, record, then Stop. One shared recorder
   writes durable 16 kHz mono PCM before transcription. Audio can be captured
   even if the model is missing; a clear error then directs the user to download
   the model and retry the retained recording.
4. Whisper processes local WAV chunks after Stop, with the microphone off.
   No API key, paid speech API, audio upload or automatic Cloud fallback is used.
5. Saved recordings / Recover recordings offers local Whisper retry, playback,
   WAV export, review/save to History and explicit deletion. Google Cloud remains
   an explicitly selected, consent-gated option. It is never an offline failure
   fallback.

The model URL pins upstream revision
`5359861c739e955e79d9a303bcbc70fb988958b1`; expected SHA-256 is
`60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`.
Downloads stream into a `.part` file. Size and SHA-256 are checked before an
atomic promotion; the installed model is verified again on a fresh process and
when its size/modification stamp changes. Inference receives only a verified
local model path. A failed/cancelled download can be retried from the beginning;
HTTP range resume is not implemented. Models are excluded from portable diary
backups. Delete all local data cancels downloads and removes model storage.

## Capture and transcription APIs

Pinned plugin: `whisper_ggml: 2.8.1`. Its published Dart/native source was inspected:
`Whisper.transcribe`, `TranscribeRequest`, timestamped word segments, isolate
execution, audio conversion, native libraries and platform minimums. The
file-transcription API accepts an explicit `modelPath` and does not download a
model or open a microphone. Its controller download helper buffers the model and
checks file existence; the app instead owns streamed, verified model downloads.
The plugin's live microphone API is not used alongside the durable recorder.

Offline jobs use 30-second core intervals with up to two seconds of context on
each side. Only a bounded WAV interval (at most 34 seconds) is exported/read at a
time. Timestamp midpoints assign boundary words to one core interval. Completed
chunks survive failure and relaunch; manual retry reprocesses unfinished/empty
chunks. Google and Whisper keep separate checkpoint maps, so switching engines
does not combine incompatible chunk layouts or discard the other attempt.
Audio and the stable History ID remain unchanged. No automatic retention expiry
or deletion on transcription failure is introduced.

Recordings stop on backgrounding, screen lock, navigation or detected audio
interruption. They do not continue under a background microphone service and
never auto-resume. Cancellation prevents later chunks/results/saves, but the
plugin's one-shot native inference has no abort API: an active chunk may finish
before teardown completes. CPU work can therefore briefly outlive the screen.
The original recording is retained. Reopening never automatically uploads audio
or starts the microphone.
Known temporary Whisper job directories left by process termination are cleaned
on startup and explicit recording deletion. Cleanup matches only app-owned job
names, does not follow links, and leaves durable audio/model files untouched.

## Languages and limitations

The multilingual model and upstream language table support English (`en`), Hindi
(`hi`) and Telugu (`te`); region-qualified app locales map to these codes.
Translation is disabled. Tests verify this routing, not real speech accuracy.
Mixed-language accuracy, accents, noise and long meetings remain device tests.
Whisper can hallucinate words on silence or unclear audio; review important text
against the original. This implementation produces text after Stop, not live
captions. Native inference loads the model per chunk; latency, peak memory,
battery and thermal behavior have not been profiled on a phone.

Android uses API 24+ and NDK `29.0.13113456`, as required by this plugin. iOS
deployment settings are raised to the plugin/FFmpeg minimum of **15.6**. No iOS
build or physical iPhone test is possible on this Windows host. These are
development artifacts, not a claim of store-release readiness.

Primary references checked during implementation:

- [Plugin package and API](https://pub.dev/packages/whisper_ggml/versions/2.8.1)
- [Plugin source](https://github.com/sk3llo/whisper_ggml)
- [Official GGML model artifacts](https://huggingface.co/ggerganov/whisper.cpp)
- [Whisper language table](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py)

## Installation without removing data

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Connect the V2420, enable USB debugging, accept the computer authorization prompt
and run from the project directory:

```powershell
.\scripts\run_android.ps1 -SkipBuild -DeviceId 10BECA1SM30017C
```

The script verifies package/signature/version, refuses downgrades, uses
`adb install -r`, and launches the app. It never uninstalls or clears app data.
The equivalent manual commands are:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s 10BECA1SM30017C install -r build/app/outputs/flutter-apk/app-debug.apk
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s 10BECA1SM30017C shell am start -W -n com.aivoicedocs.app/.MainActivity
```

If Android rejects the signature/version, stop and inspect the mismatch. Do not
uninstall to work around it. Unlock the existing app profile, select Whisper,
download until **Ready — model size and SHA-256 verified**, then enable airplane
mode for the offline test below. Build 7 must replace build 6 to show the feature.

## Phone acceptance checks

The phone was connected for installed-version inspection but disconnected before
the completed feature could be tested. No real native Whisper inference,
microphone capture, model download on the phone or language accuracy has passed
in this task. Automated tests inject local inference responses and small model
fixtures; they cannot establish native quality/performance.

- Confirm Settings shows Whisper and the model download percentage advances.
  Interrupt the download, retry, restart the app and confirm Ready persists.
- Enable airplane mode after Ready. Record separate 10–20-second English, Hindi
  and Telugu clips. Stop, verify local transcription and audible playback; export
  WAV. Compare against what was actually said. Test mixed speech separately.
- Record for 15–60 minutes with the screen awake; speak across 30-second
  boundaries. Check missing/duplicate words, playback continuity, storage,
  battery, heat and processing latency.
- Leave during recording/transcription, lock the screen, answer a call and
  disconnect Bluetooth. Confirm safe stop, retained audio, no automatic restart
  and retry of unfinished chunks. An active native chunk can delay cancellation.
- Force-stop during capture and transcription. Reopen/unlock; verify original
  language/date/folder, retained audio and completed chunks. Retry locally while
  still offline. Confirm History saves once and audio remains.
- Try rapid taps, permission denial, silence and controlled low storage. Free
  space and retry recovery. Delete only a test recording and verify another
  recording and existing diary/history remain.

## Checks actually run

- `flutter pub get --enforce-lockfile`: passed.
- `dart run build_runner build`: passed. Generated settings serialization includes
  `SpeechEngine.whisper`; saved offline selection survives reload.
- `flutter test --reporter expanded`: **111 tests passed**, including all 12 new
  offline cases and existing diary, calendar, task, backup, lock and recorder
  tests. Native inference and model responses are injected in automated tests.
- `flutter analyze --fatal-infos`: passed, no issues.
- `dart format --output=none --set-exit-if-changed lib test scripts`: passed,
  zero changes across 173 files.
- `git diff --check` on edited tracked application/configuration paths: passed;
  Git emitted only line-ending normalization warnings.
- `flutter build apk --debug --target-platform android-arm64 -t lib/main.dart`:
  passed. Existing Kotlin Gradle Plugin migration warnings, also emitted by the
  new FFmpeg dependency, are non-fatal with the pinned Flutter version.
- `.\scripts\run_android.ps1 -CheckOnly`: passed; regular package
  `com.aivoicedocs.app`, build **7**, signature verified.
- Packaged debug Dart kernel SHA-256 matches the current build output. The
  compiled kernel includes the new scratch-cleanup implementation.
- The 26 packaged arm64/x86_64 native libraries inspected, including Whisper and
  FFmpeg, passed the 16 KB ELF LOAD alignment checks. This is static evidence,
  not a passed 16 KB phone/pre-launch test or a release-bundle validation.

Final APK SHA-256:
`6a767fa11b9ab8602aa2508bb21f096fdb504e4a82378132f34665f72252243a`.
The debug APK is about 164 MiB; it includes native Whisper/FFmpeg libraries, not
the separately downloaded model. Final ADB inspection found no connected phone.
Build 7 was not installed or tested on the V2420 in this task.

## Files changed for this feature

- `pubspec.yaml`, `pubspec.lock`: pin the native Whisper dependency and bump build
  6 to 7; preserve the existing application dependencies.
- `data/providers/durable_recording_provider.dart` and
  `data/providers/google_cloud_speech_provider.dart` under `speech_to_text`:
  extract the shared capture, interruption, durable saving and cancellation code;
  keep Google transcription as a separate implementation.
- `speech_to_text/data/providers/whisper_speech_provider.dart` and
  `speech_to_text/data/whisper_model_store.dart`: local file inference, model
  integrity/download state, bounded chunks, retry and cancellation handling.
- `speech_to_text/data/pending_recording_store.dart`: separate backend attempts
  and bounded WAV interval export while retaining existing recordings.
- `speech_to_text/domain/speech_engine.dart`, speech/Whisper Riverpod providers,
  Voice and recovery screens: engine wiring, direct Settings access and offline
  recovery with the existing one-microphone coordinator.
- `lib/main.dart`: remove abandoned temporary Whisper jobs on startup while
  retaining the existing interrupted-recording recovery.
- Settings screen and `whisper_speech_settings.dart`: visible selector, progress,
  retry, cancellation and verified Ready state.
- `core/privacy/local_data_service.dart`, `core/privacy/privacy_policy.dart`:
  model removal on explicit Delete all local data and accurate offline/network
  disclosures. The app's existing diary storage and PINs are preserved.
- `android/app/build.gradle.kts`, `ios/Podfile`,
  `ios/Runner.xcodeproj/project.pbxproj`: native toolchain/platform requirements.
- `test/whisper_offline_test.dart`: offline regression coverage.
  `test/app_redesign_test.dart` now waits for the appearance-control scroll to
  settle after Speech Recognition moved to the top of Settings; its diary,
  task, calendar and appearance assertions remain in place.
- `README.md`, this document and the recorder reliability cross-reference:
  diagnosis, setup, installation, limits and actual verification evidence.
