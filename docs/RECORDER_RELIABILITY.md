# Recorder reliability

2026-10-23 update: Whisper offline transcription has now been added on top of
this durable capture/recovery implementation. See [Whisper setup and verification](WHISPER_OFFLINE.md).
The diagnosis below records the earlier pre-Whisper checkout.

## Rechecked diagnosis

The local checkout has `google_cloud_speech_provider.dart` and
`on_device_speech_provider.dart`. The referenced `google_speech_provider.dart`
and `whisper_speech_provider.dart` are absent. There is no installed Whisper
engine or local model downloader to fix or validate.

The committed baseline (`HEAD`) confirms the Google audio-loss finding: it
records temporary PCM, reads the whole file with `readAsBytes`, and deletes that
file in `_transcribe`'s `finally` block even after transcription errors. The
working checkout already contained an earlier safety change that encrypted a
short capture after Stop and kept it when upload failed. That still left capture
in temporary storage without recovery metadata before Stop. A regression failed
with `Bad state: No element` when reopening recovery during capture. Successful
History acknowledgement also deleted audio in that intermediate implementation.
The working checkout already separated `isProcessing` from `isListening`;
preparation, finalization, natural finals, and restart races still needed explicit
handling. The current implementation below replaces the unsafe capture and
deletion paths while preserving the other local changes.

Before changes, 20 existing recorder/diary tests passed. These source and
automated-test findings are not evidence of microphone accuracy on a phone.

## Follow-up audit (2026-10-22)

The existing retention and retry paths were rechecked rather than replaced.
Five new regression cases reproduced these remaining failures before fixes:

- Native start throwing after opening capture did not call native Stop. A
  metadata write failure after a successful start left `isListening` true.
  Startup now finalizes its own attempted capture, including without a UI
  coordinator, retains available bytes, and defers transcription. This also
  covers a native start that acquires the microphone before throwing.
- The coordinator replaced a cancelled upload's `interrupted` state with
  `completed`, and replaced a transcription failure's `failed` state with
  `interrupted`. It now retains the provider's terminal state while clearing
  microphone/processing indicators. Regression cases verify the UI state and
  retained audio together.
- One corrupt `.json.tmp` staging file aborted all startup recovery. Staging
  errors and per-recording phase-write errors are now isolated; original files
  remain untouched and healthy captures continue recovering. Legacy temporary
  import failures also no longer skip recovery of current recordings.

All five cases passed after the fixes. The regular Android build number is 6.
No Android device was connected during this follow-up audit; microphone quality
and the physical checklist below remain unverified.

## Implementation stages

1. **Durable capture.** Encrypted metadata and a unique ID are committed before
   recording starts. Native capture writes continuous 16 kHz, mono, 16-bit PCM
   into the app documents directory, without stopping at transcription chunk
   boundaries. After Stop, 512 KiB blocks are authenticated/encrypted. The raw
   source is removed only after every block and the final metadata are durable.
   A failed finalization keeps the source. Cancel never calls the recorder's
   destructive `cancel()` API.
2. **Recovery and transcription.** Startup marks unfinished sessions/jobs as
   interrupted. It does not reopen a microphone or automatically upload audio.
   Existing encrypted V1 captures remain readable. Known old temporary PCM
   captures are adopted without deleting the only copy. Their language was
   never saved, so the user must choose it before retrying. Corrupt metadata
   is shown as an error without hiding other recordings or deleting files.
3. **Bounded jobs and stable saves.** Google receives 50-second core intervals,
   with up to two seconds of context on each side (maximum 54 seconds/request).
   Completed chunks are checkpointed and skipped on retry. Word midpoints
   assign overlapped timed words to one interval. If timing is omitted, exact
   suffix/prefix text matching is a fallback; review boundaries against audio.
   Speaker labels are scoped to their segment because independent requests
   cannot guarantee the same speaker identity. Transient errors get at most two
   retries after 500 ms and 1 s. Authentication/other terminal errors need manual
   retry. Empty recognized chunks may be retried manually. Original language,
   date, folder, partial text, and audio are retained.
4. **Lifecycle and visible recovery.** Preparing, recording, saving,
   transcribing, completed, interrupted, and failed are explicit states. A native
   pause/focus interruption stops capture rather than auto-resuming. Observed
   device removal/noisy-route events stop capture. Start/stop operations are
   serialized; repeat taps, duplicate finals, stale callbacks, and callbacks to
   disposed UI are guarded. Navigation/backgrounding/disposal cancel uploads
   while retaining progress. Saving History uses the same stable ID in automatic
   and recovery paths; a crash before acknowledgement cannot duplicate it.

The **Record meeting** action is an audio-only capture path independent of the
selected dictation engine. It needs no model, network, or Cloud key. Transcribe
later with Google, or play/export without transcription. Native live dictation
remains available for diary/task fields. It does not expose an audio file; this
app never tries to run a second microphone consumer beside it. Native restarts
now ignore duplicate/old callbacks, retain available partial text, back off,
and stop after bounded consecutive empty failures. OS session restarts can still
miss speech; use durable meeting capture for important audio.

## Retention, storage, and privacy

- Audio stays until explicitly deleted, including after saving History. There
  is no age-based expiry. History deletion and audio deletion are separate.
- The recovery screen shows count, duration, state, completed chunk count, and
  actual disk usage. It offers playback, WAV export, retry, review, and deletion.
- New capture is limited to 10 saved recordings. A 256 MiB raw-audio safety
  threshold is checked every two seconds, so a small overshoot is possible.
  At 32,000 bytes/second this is approximately 2 hours 20 minutes.
- Capture is OS-private PCM until successful sealing. Completed blocks and
  metadata use the existing device-key AES-GCM store. If interrupted or storage
  is full, the raw file can remain until successful sealing or explicit deletion.
  Sealing needs additional disk space. Base64/envelope overhead means stored
  ciphertext occupies more than the PCM size. Long export and transcription
  use bounded reads; no complete meeting is read into memory. Peak process
  memory has not been profiled on a device.
- Playback and WAV export make readable private temporary files. The screen
  cleans up files it creates, and explicit audio deletion removes its known WAV
  cache. Files already shared outside the app remain outside its control.
  Recordings are excluded from portable diary backups: export important audio
  separately. Uninstalling/deleting all local data removes private recordings.
- Retry explicitly uploads to Google and may incur charges. Tests use fake
  HTTP responses; no real Google transcription or billing has been exercised.

## Platform behavior and official references

This change implements foreground capture with stop-and-recover on background,
screen lock, navigation, and detected interruption. It does **not** advertise
continuous locked-screen/background recording, restart on boot, or recovery of
audio never written by the OS. Process termination may lose the final buffered
samples. Reopen/unlock the app to recover bytes already on disk. Calls, routes,
OEM power management, and low-storage behavior still require physical tests.

Android retains `RECORD_AUDIO`, Bluetooth access, and the existing app lock.
No microphone foreground service is declared because no background capture
service is implemented. Android 9+ restricts background microphone access;
Android 14+ microphone foreground services require the appropriate type and
permission, with restrictions on starting them from the background.
See [MediaRecorder](https://developer.android.com/media/platform/mediarecorder)
and [foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types).

iOS retains the microphone/speech purpose strings and existing file protection.
Audio-only capture does not request speech-service permission. The recorder
manages its audio session; interruption/route events are observed. No `audio`
background mode is added. A future continuous background recorder would need
an appropriate AVAudioSession category, the audio background capability, and
physical validation alongside the app's lock policy. See Apple's
[recording category and background requirements](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record)
and [audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).

The Cloud request plan stays below the documented synchronous duration and
request-size limits. See [Google Cloud STT V1 quotas](https://docs.cloud.google.com/speech-to-text/docs/v1/quotas).

Official Android microphone/foreground-service guidance, Apple's recording
category/interruption guidance, and Google's synchronous quotas were rechecked
on 2026-10-22. The implementation remains foreground-only with stop-and-recover
on background or interruption; it adds no background microphone capability.

## Validation and phone checklist

Executed automated checks:

- `dart run build_runner build`: passed; regenerated ignored model outputs.
- `flutter analyze --fatal-infos`: passed with no issues after fixing lints.
- `flutter test --reporter compact`: **99 tests passed**, including recorder,
  diary, backup, app-lock, lifecycle, reminder, and export regressions.
- `flutter build apk --debug --target-platform android-arm64`: passed for build
  6 using the regular `lib/main.dart` entry point. Existing plugin KGP migration
  warnings remain non-fatal.
- `git diff --check` for the edited application paths: passed.
- `flutter pub get --enforce-lockfile`: passed.
- `dart format --output=none --set-exit-if-changed lib test scripts`: passed
  with zero changes across 167 files.

Physical validation initially found no connected phone. After reconnecting,
the first V2420 diagnostic retained/decrypted audio but its first-second
microphone sample check contained only zeros. Android app-ops reported a recent
foreground-only microphone rejection. This attempt is **not** a passed signal,
playback, or process-kill recovery test. The diagnostic was adjusted to wait for
its foreground frame and examine the whole short recording. The connection
dropped during the next installation attempt. After reconnecting, the diagnostic
was installed/launched, but another screen was foreground, so a valid foreground
capture/recovery run could not be completed. The regular build was then restored
without clearing app data. Microphone signal, audible playback, and physical
process-kill recovery remain **unverified**. Any failed diagnostic capture is
retained in Saved recordings and can be explicitly deleted after review.

No iPhone/Xcode environment is available on this Windows host. Automated tests
do not establish iOS release readiness. Long meetings, real calls, headset
changes, actual low-storage conditions, and live Cloud transcription still need
the physical checklist below.

Install/update without removing app data:

```powershell
./scripts/run_android.ps1
```

On the phone, unlock the app and open **Voice > Record meeting**:

1. Record 30 seconds in airplane mode, stop, open Saved recordings, play it,
   export WAV, and play the exported file in another app. Confirm the language
   shown is the one chosen at capture start.
2. Record a 15–60 minute meeting with the screen awake. Speak distinctive phrases
   across each 50-second boundary. Verify duration, playback continuity, exported
   file length, memory/storage behavior, and transcript boundary words.
3. Stop a Cloud recording with the network unavailable. Relaunch and confirm
   audio remains. Restore the network and retry; completed chunks must remain
   and only unfinished/empty chunks should be requested again.
4. During capture lock the screen, change tabs, or background the app. Expect
   capture to stop, the app to relock, and already-written audio to remain.
   Do not expect recording to continue while locked or automatically resume.
5. During another capture answer a call, disconnect Bluetooth/headphones, and
   change audio devices. Confirm safe stop and recovery of captured audio.
6. Force-stop the app during capture and during transcription; reopen, unlock,
   and recover. Check the partial transcript, original language/date/folder,
   and completed chunks. No microphone/upload should restart by itself.
7. Rapidly tap Start/Stop, change engines, and navigate while permission/start
   is pending. Confirm one microphone session and one saved History entry.
8. Deny microphone access, including permanently, and disable/remove the native
   language model. Typed diary entries must keep working. Meeting capture should
   work without a speech model once microphone access is granted.
9. With controlled low storage, test a start failure and a finalization failure.
   Free space, relaunch, play/export/retry the retained capture. Do not fill the
   phone containing your only important recording.
10. Save a transcript, reopen recovery, and verify audio remains and History is
    not duplicated. Delete one test recording; verify its audio/chunks/cache are
    removed while another recording and previously saved History remain.

For a controlled developer diagnostic after connecting/unlocking an Android
phone, run `flutter run -d <id> -t scripts/check_recorder_device.dart`. It captures
short ambient test audio, tests native WAV playback/export, and prints
`READY_FOR_PROCESS_KILL`. Force-stop `com.aivoicedocs.app` and relaunch the same
diagnostic to validate interrupted-file recovery. It uploads nothing and
deletes only its own successful diagnostic recordings. Restore the regular app
with `./scripts/run_android.ps1` afterward.
