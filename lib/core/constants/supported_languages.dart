import 'package:ai_voice_docs/core/models/language.dart';

/// Static catalog of languages offered throughout the app for speech
/// recognition, translation and text-to-speech. Kept as plain data (not
/// fetched from a network) so language pickers work instantly and offline.
///
/// `code` (bare, e.g. `en`) feeds the translation provider; `localeHint`
/// (region-qualified, e.g. `en-US`) feeds the on-device speech/TTS providers
/// — see `Language`'s doc comment for why these can't be the same field.
const List<Language> kSupportedLanguages = [
  Language(code: 'en', localeHint: 'en-US', name: 'English', nativeName: 'English', flagCountryCode: 'US'),
  Language(code: 'es', localeHint: 'es-ES', name: 'Spanish', nativeName: 'Español', flagCountryCode: 'ES'),
  Language(code: 'fr', localeHint: 'fr-FR', name: 'French', nativeName: 'Français', flagCountryCode: 'FR'),
  Language(code: 'de', localeHint: 'de-DE', name: 'German', nativeName: 'Deutsch', flagCountryCode: 'DE'),
  Language(code: 'it', localeHint: 'it-IT', name: 'Italian', nativeName: 'Italiano', flagCountryCode: 'IT'),
  Language(code: 'pt', localeHint: 'pt-BR', name: 'Portuguese', nativeName: 'Português', flagCountryCode: 'PT'),
  Language(code: 'nl', localeHint: 'nl-NL', name: 'Dutch', nativeName: 'Nederlands', flagCountryCode: 'NL'),
  Language(code: 'sv', localeHint: 'sv-SE', name: 'Swedish', nativeName: 'Svenska', flagCountryCode: 'SE'),
  Language(code: 'no', localeHint: 'nb-NO', name: 'Norwegian', nativeName: 'Norsk', flagCountryCode: 'NO'),
  Language(code: 'da', localeHint: 'da-DK', name: 'Danish', nativeName: 'Dansk', flagCountryCode: 'DK'),
  Language(code: 'fi', localeHint: 'fi-FI', name: 'Finnish', nativeName: 'Suomi', flagCountryCode: 'FI'),
  Language(code: 'pl', localeHint: 'pl-PL', name: 'Polish', nativeName: 'Polski', flagCountryCode: 'PL'),
  Language(code: 'ru', localeHint: 'ru-RU', name: 'Russian', nativeName: 'Русский', flagCountryCode: 'RU'),
  Language(code: 'uk', localeHint: 'uk-UA', name: 'Ukrainian', nativeName: 'Українська', flagCountryCode: 'UA'),
  Language(code: 'tr', localeHint: 'tr-TR', name: 'Turkish', nativeName: 'Türkçe', flagCountryCode: 'TR'),
  Language(code: 'el', localeHint: 'el-GR', name: 'Greek', nativeName: 'Ελληνικά', flagCountryCode: 'GR'),
  Language(code: 'cs', localeHint: 'cs-CZ', name: 'Czech', nativeName: 'Čeština', flagCountryCode: 'CZ'),
  Language(code: 'ro', localeHint: 'ro-RO', name: 'Romanian', nativeName: 'Română', flagCountryCode: 'RO'),
  Language(code: 'hu', localeHint: 'hu-HU', name: 'Hungarian', nativeName: 'Magyar', flagCountryCode: 'HU'),
  Language(code: 'ar', localeHint: 'ar-SA', name: 'Arabic', nativeName: 'العربية', flagCountryCode: 'SA'),
  Language(code: 'he', localeHint: 'he-IL', name: 'Hebrew', nativeName: 'עברית', flagCountryCode: 'IL'),
  Language(code: 'hi', localeHint: 'hi-IN', name: 'Hindi', nativeName: 'हिन्दी', flagCountryCode: 'IN'),
  Language(code: 'bn', localeHint: 'bn-IN', name: 'Bengali', nativeName: 'বাংলা', flagCountryCode: 'BD'),
  Language(code: 'ur', localeHint: 'ur-PK', name: 'Urdu', nativeName: 'اردو', flagCountryCode: 'PK'),
  Language(code: 'zh-CN', localeHint: 'zh-CN', name: 'Chinese (Simplified)', nativeName: '中文', flagCountryCode: 'CN'),
  Language(code: 'zh-TW', localeHint: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文', flagCountryCode: 'TW'),
  Language(code: 'ja', localeHint: 'ja-JP', name: 'Japanese', nativeName: '日本語', flagCountryCode: 'JP'),
  Language(code: 'ko', localeHint: 'ko-KR', name: 'Korean', nativeName: '한국어', flagCountryCode: 'KR'),
  Language(code: 'th', localeHint: 'th-TH', name: 'Thai', nativeName: 'ไทย', flagCountryCode: 'TH'),
  Language(code: 'vi', localeHint: 'vi-VN', name: 'Vietnamese', nativeName: 'Tiếng Việt', flagCountryCode: 'VN'),
  Language(code: 'id', localeHint: 'id-ID', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flagCountryCode: 'ID'),
  Language(code: 'ms', localeHint: 'ms-MY', name: 'Malay', nativeName: 'Bahasa Melayu', flagCountryCode: 'MY'),
  Language(code: 'sw', localeHint: 'sw-KE', name: 'Swahili', nativeName: 'Kiswahili', flagCountryCode: 'KE'),
  Language(code: 'af', localeHint: 'af-ZA', name: 'Afrikaans', nativeName: 'Afrikaans', flagCountryCode: 'ZA'),
];

Language languageByCode(String code) => kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kSupportedLanguages.first,
    );
