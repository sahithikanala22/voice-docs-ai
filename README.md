# Voice Docs AI

A Flutter app for voice journal entries, tasks, searchable history, folders,
calendar entries, reminders, and local text-to-speech playback. Translation is
not part of the current app.

## Reproducible setup

Use **Flutter 3.44.8 stable / Dart 3.12.2**, Java 17, and Android SDK 36.
The current app is **1.1.0, build 8**. Keep build numbers increasing when updating an installed app to avoid a downgrade reinstall.
The committed `pubspec.lock` is the application dependency lockfile. Models use
Freezed 3; their source classes are abstract and generated files are ignored.
Regenerate them on every fresh checkout:

```sh
flutter pub get --enforce-lockfile
dart run build_runner build
flutter analyze --fatal-infos
flutter test
flutter devices
flutter run -d <android-device-id>
```

The GitHub Actions workflow uses the same pinned Flutter release, checks the
lockfile, regenerates models, checks formatting, runs analysis and tests, and
builds a debug APK. To update dependencies, update constraints intentionally,
run `flutter pub get`, regenerate, run the checks, and commit the lockfile.

Android and iOS are the intended platforms. The current app imports mobile
plugins and `dart:io`; browser and desktop support are not advertised.

## Today and Library

The four destinations are **Today, Journal, Tasks, and Library**. Today brings
together recording, journal writing, the calendar, upcoming tasks, and recent
notes. Record a note opens the existing voice recorder; Record audio keeps audio
without requiring a speech model. Calendar and voice-history management remain
available from Today and Library respectively.

Library searches the complete local collection of voice transcripts, journal
titles/bodies, tasks, and retained audio transcripts. Filters combine content
type, date, language, and voice/audio folder. Results are displayed in pages of
50; filtering searches the full collection before pagination. Linked audio is
shown with its note instead of a duplicate Library entry.

Whisper and Google Cloud notes link to the retained original recording. The
detail view supports playback, pause, seeking, and jumping to passages using
recognizer timestamps from newly transcribed recordings. Older audio can still
play without timestamps. Device dictation does not archive audio. Deleting a
transcript does not delete its recording; deleted or unavailable audio leaves
the text readable. Portable JSON backups include notes and audio references,
but not the audio archive; export WAV separately when moving recordings.

Playback uses one shared player. Navigating away, dismissing the note, starting
another recording, or backgrounding stops playback. The original remains
encrypted; temporary WAV playback copies are removed on stop and any abandoned
playback cache is cleaned on the next cold start.

## Android first

The current deliverable targets Android 7.0 / API 24 or later and Android SDK 36.
On Windows, run from the project folder with a USB-debugging-authorized phone:

```powershell
./scripts/run_android.ps1                     # build, update in place, launch
./scripts/run_android.ps1 -SkipBuild          # reuse the existing built APK
./scripts/run_android.ps1 -CheckOnly          # verify the APK without a phone
```

Use `-DeviceId <serial>` when multiple devices are connected. The script checks
package/build numbers and the APK signature, refuses downgrades, and installs
with `adb install -r`. It never uninstalls or clears application data.

Android device acceptance checks after unlocking the app:

- Record on Voice, then switch tabs or background the app: recording stops and
  the final transcript is saved once with the original date/folder/language.
- Dictate into Tasks/Add Entry, stop, then save: final words are included.
- Background and reopen: the PIN/biometric gate appears. Existing four-digit
  PINs still work; newly created PINs have six digits.
- Clear history while a task reminder exists: that task reminder remains.
- Back up a custom background/profile photo and restore: images still display.
- Delete a folder: its entries appear under Unfiled. Confirm the chosen playback
  voice and export a long transcript containing the languages you use.

iPhone release validation is deferred; Android is the first device-test target.

## Recording and privacy

One shared recording coordinator owns the microphone. Starting another capture
stops the previous one. Navigation, sheet dismissal and backgrounding stop the
recording; late final results are processed before finishing. Voice-tab entries
save through the coordinator with the language, folder and date captured at
start. Saving never depends on a mounted screen. Multi-speaker transcripts are
preserved in full so navigation cannot discard another speaker's words.
Dictation fields keep their final text; saving a form waits for dictation to
finish. Dismissing a form discards its unsaved draft.

- **Device speech:** uses the phone's OS recognition service. That service may
  send audio to its provider or require a network connection. Offline operation
  depends on device settings, language downloads and recognizer support.
- **Whisper — Free Offline:** select it in Settings → Speech Recognition and
  download the multilingual base model once (about 142 MiB). The app verifies its
  size and SHA-256 before showing Ready. Recording and transcription then work
  locally without an API key or Cloud fallback. Text appears after Stop; audio
  remains available for playback, export and retry. See
  [offline setup, diagnosis and phone tests](docs/WHISPER_OFFLINE.md).
- **Google Cloud speech:** durable PCM audio is saved before upload. Transcription
  uses 50-second core chunks with two seconds of boundary context on either side,
  checkpointed results, and bounded transient retries. Internet and the user's
  API key are required; usage charges may apply. Transcription appears after Stop.
- **Record meeting:** a separate, durable audio-only recorder works without an
  API key or a speech model. Transcribe later, play, export WAV, or explicitly
  delete from Voice > Saved recordings / Settings > Recover recordings. Audio
  remains even after saving a transcript. No automatic retention expiry applies.
  Capture is limited to 10 saved recordings and approximately 256 MiB of PCM per
  capture. Sealing requires additional free space; storage usage is shown.
- **Playback:** uses the device TTS engine and selected voice. Network use and
  offline availability depend on that voice and installed language resources.
- **History and reminders:** stored locally. Clearing history only cancels those
  entries' reminders; task reminders remain scheduled. Entries are kept until
  explicitly deleted, with history displayed in pages of 50.

## Local data and app lock

Recorder diagnosis, migration details, platform limits, executed checks, and a
physical-device checklist are in [docs/RECORDER_RELIABILITY.md](docs/RECORDER_RELIABILITY.md).

Feature JSON (history, tasks, folders, settings and account) is encrypted with
AES-256-GCM. A random per-installation key is held by Android Keystore / iOS
Keychain through `flutter_secure_storage`. Legacy plaintext preference blobs
migrate on first successful read. Authentication failures fail closed rather
than exposing an unlocked app or silently replacing unreadable data.
Images remain files in the private app directory, protected by the OS; this is
not a separate PIN-derived encrypted filesystem. Rooted/jailbroken devices and
access to an already running, unlocked process are outside this screen lock's
protection. Android automatic backup is disabled and its secure-window flag
blocks app screenshots and task snapshots. iOS enables complete file protection.

The app relocks when backgrounded and obscures its UI while inactive. New PINs
have six digits and use salted PBKDF2-HMAC-SHA256 with 600,000 iterations.
Existing four-digit SHA-256 credentials remain usable and are upgraded after a
successful unlock. Failed PIN attempts persist across restarts; after five
failures a growing cooldown applies. Resetting a forgotten app PIN while keeping
data requires the phone's device passcode or biometrics. Internal pre-reset
snapshots are encrypted with the device key.

Android 8.0 / API 26+ derives PIN hashes with the platform PBKDF2 implementation
on a background task queue. Existing hashes and the 600,000-round setting remain
compatible. Older Android versions and other platforms use the Dart isolate
fallback. The PIN screen shows progress and prevents repeated submissions while
verification is running.

To time the Android implementation against a public known-answer vector, run
`flutter run -d <android-device-id> -t scripts/benchmark_pin.dart`. This temporary
entrypoint never reads account data. Rebuild with `lib/main.dart` afterward to
restore the regular app.

## Backups and exports

Version 2 JSON backups include history, tasks, folders, settings, profile fields,
and the actual bytes of profile/background images. The current entry model has
no separate diary-photo attachment field. PIN credentials, biometric preferences
and Google API keys are excluded. Restore keeps the current PIN/API key and
relinks images to newly created private paths on the destination phone.

Before changing existing data, restore validates the version, all data sections,
model schemas, record IDs, image references, SHA-256 checksums and image decoding.
Failed writes roll preference values back. Unknown backup versions and incomplete
attachments are rejected. Version 1 files remain importable; their old image
paths are cleared because those files never contained the actual image bytes.
Portable backups and shared exports contain readable personal data: store them
privately. Only the internal PIN-recovery snapshot is encrypted automatically.

PDFs paginate at text-line boundaries, including long entries. Flutter's text
shaper and installed font fallback render multilingual and mixed-direction text
offline. Text is embedded as high-resolution images, so PDFs are readable but
not text-selectable/searchable; font coverage depends on the device. Word export
retains editable text.

## iOS release verification

The project includes notification initialization and foreground delegation,
camera/photo/microphone/speech/Face ID purpose strings, permission-handler flags,
and a file-protection entitlement. Use a Mac with Xcode/CocoaPods and iOS 15+:

```sh
flutter pub get --enforce-lockfile
dart run build_runner build
flutter build ios --no-codesign
```

An iPhone is still required to verify permission prompts, denial/retry flows,
notifications when foregrounded/backgrounded, Face ID, gallery/camera return,
lock-on-background, interruption recovery, non-Latin PDF rendering, and restore
to another device. Windows checks do not establish iOS release readiness.
## Play Store release preparation

See [release/README.md](release/README.md) for the signed AAB workflow, public
privacy policy, store listing, Data safety worksheet and device test matrix.
Recording recovery is available in Settings for retained Google Cloud audio.
The local profile can be removed with Settings > Delete all local data.
Do not upload the earlier debug UI preview as a production release.
