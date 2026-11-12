/// Shared by the offline policy screen and the public-page generator.
class ReleaseIdentity {
  static const developerName = String.fromEnvironment('DEVELOPER_NAME');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const policyDate = '2026-10-23';
}

const privacySections = <String, String>{
  'What the app does':
      'Voice Docs AI helps you dictate notes, keep a diary, add entries to calendar dates, manage tasks and read saved history. Your name and PIN create a local profile, not an online account. No developer-operated account or synchronization server is used.',
  'Information on your device':
      'The app stores your notes, diary text and moods, task details, dates, reminders, folders, appearance settings and optional profile details. Photos you select or take are copied into private app storage. Feature records and API keys are encrypted using a device-held key. Photo files and files you export are not additionally encrypted by the app. PINs are stored as salted hashes. Biometric authentication is performed by your operating system; the app does not receive your fingerprint or face data.',
  'Microphone and device speech':
      'Microphone access starts when you choose voice input and stops when you stop, leave the recording screen or background the app. Device speech uses your phone’s speech recognition provider. That provider may send audio to its servers; offline availability depends on your device and downloaded languages. Voice Docs AI does not archive raw audio from device speech. Recognition may stop or miss words, so review important transcripts.',
  'Optional Google Cloud transcription':
      'Google Cloud recording and Record meeting save PCM audio in durable private app storage with metadata before transcription. Meeting capture needs no API key, internet connection or speech model. During capture, raw audio is protected by the operating system. After Stop, audio is encrypted in blocks; if sealing fails or the process dies, the raw source is kept for recovery. Google transcription uploads short audio chunks and the saved language over HTTPS. It requires your API key and may incur charges. Completed chunks are checkpointed and reused when retrying. Audio remains until you explicitly delete it, including after saving a transcript. Up to 10 recordings and approximately 256 MiB of PCM per capture are supported; sealing needs extra free storage. Recover recordings offers playback, WAV export, retry and deletion. Playback/export creates readable temporary files. Audio is excluded from portable backups. Google processing is subject to its service terms and retention practices; the app cannot delete copies already processed by Google.',
  'Whisper — Free Offline':
      'Whisper uses the same durable audio capture and recovery storage. Downloading the multilingual model contacts Hugging Face over HTTPS; that host receives normal connection information. The app verifies the model before use. After download, Whisper transcription uses local files on this device, without an API key, paid speech API, audio upload or automatic cloud fallback. Completed offline chunks are checkpointed separately from Google chunks. Temporary WAV chunks are removed when the job ends; originals remain until explicitly deleted. Cancellation waits for any current native chunk to finish and discards its late result. Model and transcription accuracy vary by language and device. Delete all local data also removes the downloaded model.',
  'Playback, photos and reminders':
      'Read-aloud uses your device’s text-to-speech provider, whose voices may use a network. Camera/photo access is used only when you choose an image. Notifications are optional and used for reminders you create. Exact reminder timing depends on device permissions and battery settings. Bluetooth access supports a connected microphone. Permissions can be changed in Android Settings.',
  'Sharing and backups':
      'The app does not include advertising, analytics or developer-operated tracking. It does not sell your personal data. Your entries are not uploaded to a developer server. You can explicitly export or share content using another app; that app’s practices then apply. Portable backups and PDF/Word exports contain readable personal content. Backups exclude PIN credentials and API keys. Keep exported files private. Internal PIN-recovery snapshots are encrypted on this device.',
  'Retention and deletion':
      'Local entries remain until you delete them. Use Settings > Delete all local data to remove the local profile, diary, history, tasks, settings, saved recovery audio, app-owned photos, internal recovery snapshots and app-generated temporary exports, and cancel reminders. This action is permanent. Files you already saved or shared outside the app and data processed by speech or playback providers are not removed. You can also uninstall the app to remove its private Android storage. There is no server account to delete.',
  'Security and your choices':
      'You can use typed entries without microphone access, decline notifications and photos, choose device speech instead of Google Cloud, remove your Cloud API key, and export or delete entries. The app stops recording in the background and locks when appropriate. Device loss, exported files and a compromised operating system can still expose information. No app can promise perfect security or transcription accuracy.',
  'Changes and contact':
      'Policy changes are included in app updates and the published policy page. Contact the developer shown below for questions about this app’s data practices. Do not send diary text, recordings, PINs or API keys with support requests.',
};
