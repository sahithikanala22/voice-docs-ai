# Voxi Translate

A production-ready Flutter app for real-time speech-to-text, translation, and text-to-speech — rebuilt from a reference speech/translator app screenshot set with a modernized Material 3 interface, clean architecture, and Riverpod state management.

## What it does

- **Voice to Text** — press the mic, see your words transcribed in real time (live partial results), then copy / clear / speak-back / share the transcript.
- **Translator** — type or dictate text in a source language, get an instant translation in a chat-bubble layout, with one tap to swap languages.
- **History** — every transcript and translation is saved locally, searchable, swipe-to-delete, with a detail sheet that can replay the audio.
- **Settings** — light/dark/system theme, default languages, auto-play-translation toggle, haptics, clear-history.
- **34 supported languages** with flag icons, reused across a single shared language picker.

## Redesign vs. the reference screenshots

The reference app used a single flat dark-teal palette and in-page navigation buttons ("VOICE TO TEXT" / "TRANSLATOR" on a home screen, a back-arrow history). This rebuild:

- Uses a **Material 3 seeded color scheme** (light + dark, both derived from the same brand teal) instead of one fixed palette.
- Replaces in-page nav buttons with a **persistent bottom navigation bar** (`StatefulShellRoute`), so each tab keeps its own state when you switch away and back.
- Replaces the static mic icon with an **animated, sound-reactive pulsing mic button** driven by the live microphone amplitude.
- Replaces boxy translation bubbles with **rounded, modern chat bubbles** (outline for source, filled for the translation).
- Adds **swipe-to-delete history rows** with relative timestamps and a search bar.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (stable) / Dart 3, Material 3 |
| State management | `flutter_riverpod` (manual `Notifier`/`AsyncNotifier`, see note below) |
| Navigation | `go_router` (`StatefulShellRoute.indexedStack`) |
| Networking | `dio` (reserved for future cloud-provider stubs), `translator` (free translation) |
| Models | `freezed` + `json_serializable` |
| Local storage | `shared_preferences` |
| Speech-to-text | `speech_to_text` (native OS recognizer) |
| Text-to-speech | `flutter_tts` (native OS engine) |
| Permissions | `permission_handler` |
| UI | `flag` (flag icons), `share_plus` |

### A note on Riverpod code generation

The plan originally called for `riverpod_generator` (`@riverpod` annotations). While wiring this up, `dart run build_runner build` failed to compile: `riverpod_generator`'s transitive dependency `custom_lint_core` ships two internal packages (`analyzer_plugin` and `custom_lint_visitor`) that are each pinned to a different, incompatible slice of the `analyzer` package's API — no single `analyzer` version in this environment's resolvable range satisfies both. This is an upstream dependency conflict, not something fixable from application code.

The fix: all providers use **manual Riverpod syntax** (`Provider`, `NotifierProvider`, `NotifierProvider.family`, `AsyncNotifierProvider`) instead of code-generated ones. This has zero effect on the architecture or how state flows — it only changes provider *declaration* boilerplate. `build_runner` is still used, just for `freezed`/`json_serializable` models only, which don't pull in the broken chain.

## Architecture

Feature-first, clean-architecture-lite: each feature has `data/` (providers + repositories talking to plugins/storage), `domain/` (repository interfaces + entities), and `presentation/` (Riverpod controllers + screens/widgets). Where a separate "domain entity" would just duplicate a data model with no behavioral difference (e.g. history entries), one model is used across all three layers instead of maintaining parallel mapper boilerplate.

```
lib/
  main.dart                  Bootstraps SharedPreferences, then runs the app inside a ProviderScope
  app.dart                   MaterialApp.router: wires the theme and go_router config

  core/
    theme/app_theme.dart      Material 3 ColorScheme.fromSeed, light + dark
    router/app_router.dart    All routes: the bottom-nav shell + the language picker route
    constants/                App-wide constants, SharedPreferences key names, the static language catalog
    models/language.dart      Freezed `Language` model (code, name, nativeName, flag country code)
    providers/core_providers.dart   The SharedPreferences provider every feature persists through
    errors/                   Data-layer exceptions + a UI-facing Failure enum
    widgets/                  Shared building blocks: EmptyState, AppSnackbar, LanguageSelectorChip
    utils/time_ago.dart       Hand-rolled relative-time formatting ("2m ago")

  features/
    speech_to_text/
      data/providers/         SpeechProvider interface + OnDeviceSpeechProvider (speech_to_text pkg, default)
                               + CloudSpeechProviderStub (documented, inactive extension point)
      data/repositories/      SpeechRepositoryImpl — the only thing presentation code depends on
      domain/                 SpeechRepository interface, RecognitionState (freezed)
      presentation/           SpeechController (per-screen family, see below), the voice-to-text screen,
                               the animated mic button + sound-wave painter

    translation/
      data/providers/         TranslationProvider interface + FreeGoogleTranslationProvider (default)
                               + CloudTranslationProviderStub (documented, inactive extension point)
      data/repositories/      TranslationRepositoryImpl
      domain/                 TranslationRepository interface, TranslationResult (freezed)
      presentation/           TranslationController (debounced auto-translate, language swap),
                               the translator screen, chat bubble + language swap bar widgets

    text_to_speech/
      data/providers/         TtsProvider interface + DeviceTtsProvider (flutter_tts, default)
      data/repositories/      TtsRepositoryImpl
      domain/                 TtsRepository interface
      presentation/           TtsController — tracks isSpeaking; consumed by other screens, no route of its own

    history/
      data/                   HistoryItem (freezed + json model, used directly as the domain entity too),
                               HistoryLocalDataSource (SharedPreferences, JSON-encoded list),
                               HistoryRepositoryImpl
      domain/                 HistoryRepository interface
      presentation/           HistoryController (AsyncNotifier), the history screen, swipe-to-delete tile

    settings/
      domain/app_settings.dart          Freezed + json AppSettings (theme, default languages, toggles)
      data/                             SettingsLocalDataSource, SettingsRepositoryImpl
      domain/settings_repository.dart   SettingsRepository interface
      presentation/                     SettingsController (AsyncNotifier), the settings screen,
                                         and the shared LanguagePickerScreen used by every "pick a language" flow

  navigation/root_scaffold.dart   The bottom-nav shell wrapping the four StatefulShellBranches
```

### The modular provider pattern

Both speech-to-text and translation define an **abstract provider interface** (`SpeechProvider`, `TranslationProvider`) in their `data/providers/` folder. The repository only ever talks to that interface — never to `speech_to_text`, `flutter_tts`, or `translator` directly. Two implementations exist per interface:

1. The **default, wired-up, free/on-device** implementation (`OnDeviceSpeechProvider`, `FreeGoogleTranslationProvider`).
2. A **documented, inactive stub** (`CloudSpeechProviderStub`, `CloudTranslationProviderStub`) showing exactly which methods to implement to plug in a paid cloud API (e.g. Google Cloud Speech-to-Text, Cloud Translation API) later.

To switch providers, implement the stub and change one line — the Riverpod provider override in `speech_providers.dart` / `translation_providers.dart` (e.g. `Provider<SpeechProvider>((ref) => YourCloudProvider())`). Nothing else in the app changes.

### Why speech state is a `family` provider

`StatefulShellRoute` keeps every bottom-nav tab alive once visited (that's what makes state persist when you switch tabs). If the speech controller were a single global provider, starting a recording on the Translator tab would also update the Home tab's transcript, since both would be watching the same state. `speechControllerProvider` is keyed by a `sessionTag` (`'home'` / `'translator'`) so each screen gets its own independent live-recognition state, while both still route through the same underlying native-recognizer singleton (the OS itself only supports one active recognition session anyway).

## Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
- `RECORD_AUDIO` — microphone access for speech recognition.
- `INTERNET` — required for the translation network call (see caveat below).
- A `<queries>` entry for `android.speech.RecognitionService`, required on API 30+ for the app to see the on-device speech recognizer at all (package-visibility rules).

**iOS** (`ios/Runner/Info.plist`):
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Both are also requested at runtime via `permission_handler` before the mic is used, with the result surfaced as a snackbar if denied.

### iOS Podfile (manual step required)

This project was scaffolded and verified on Windows, where CocoaPods and Xcode aren't available, so `ios/Podfile` doesn't exist yet — Flutter generates it lazily on first `pod install` on a Mac. Once you run `flutter build ios` or open the project in Xcode on a Mac for the first time, add this to the generated `Podfile`, inside the `post_install` block (see `permission_handler`'s README for the canonical version), so the microphone/speech permission dialogs actually fire on iOS:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << [
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_SPEECH_RECOGNIZER=1',
      ]
    end
  end
end
```

## Important: what's actually offline

- **Speech-to-text and text-to-speech are on-device and work offline** (they use the native OS engines via `speech_to_text` / `flutter_tts`, no API key, no network call).
- **Translation requires an internet connection.** The `translator` package calls Google's free, unofficial translate endpoint — there's no API key, but it is a network call. There is no true offline translator without a large on-device model (e.g. ML Kit, which is Android-only and requires per-language model downloads); if you need that, implement it behind `TranslationProvider` the same way the cloud stub is documented.

## Setup

### Prerequisites
- Flutter SDK (stable channel), this project was built against Flutter 3.44 / Dart 3.12.
- Android Studio / Xcode set up for your target platform(s).
- A device or emulator/simulator with a microphone for testing speech features (the Windows/Linux/macOS desktop simulators generally don't expose a mic to the emulator).

### First-time setup

```bash
cd voxi_translate
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.freezed.dart / *.g.dart
```

### Run

```bash
flutter run                 # runs on whatever device/emulator is connected
flutter run -d chrome       # web (speech recognition support varies by browser)
```

### Regenerating code after model changes

Anytime you touch a `@freezed` class or JSON model (i.e. anything under `domain/`, `data/`, that has a `part '*.freezed.dart'` or `part '*.g.dart'`), re-run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Or keep it watching during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Static analysis & tests

```bash
flutter analyze
flutter test
```

## Testing checklist

Automated (run these yourself, they're already passing):
- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — all tests pass (a widget smoke test, plus unit tests for the translation controller's debounce/swap/history-save behavior and the history repository's persistence)

Manual (needs a real device or an emulator with mic support):
- [ ] First mic tap prompts for microphone permission; denying shows a clear error instead of silently failing
- [ ] Speaking produces live, partial transcript updates (not just a final result after you stop)
- [ ] Stopping a non-empty voice session saves an entry to History
- [ ] Copy / Clear / Speak / Share all work on a transcript
- [ ] Translator: typing pauses briefly then auto-translates; swapping languages swaps both the language pair and the text
- [ ] Translator: dictating into the source field (mic icon in the text field) fills the field and triggers translation
- [ ] Auto-play-translation setting actually speaks the result when enabled, stays silent when disabled
- [ ] History: search filters by source or translated text; swipe removes one entry; "Clear all" asks for confirmation first
- [ ] History persists across an app restart (kill and relaunch the app)
- [ ] Settings: theme mode switches immediately and also persists across restart; default language changes apply to new sessions
- [ ] Turn off Wi-Fi/data: speech-to-text and text-to-speech still work; translation fails with a readable error instead of hanging
- [ ] Rotate the device / try a small phone screen: nothing overflows, especially the empty states

## Known limitations / honest scope boundaries

- The app's own UI chrome (button labels, screen titles) is English-only; only the *content* you speak/translate is multilingual. Full UI localization would mean adding `flutter_localizations` + `.arb` files per language, which wasn't in scope here but slots in cleanly given the existing `intl` dependency.
- No automated integration/E2E tests exercising real microphone input — plugin method channels aren't mockable at that depth without a physical device or a much heavier test harness.
- iOS was authored and analyzed on Windows and could not be built or run here; see the Podfile note above.
