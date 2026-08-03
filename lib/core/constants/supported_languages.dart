import 'package:voxi_translate/core/models/language.dart';

/// Static catalog of languages offered throughout the app for speech
/// recognition, translation and text-to-speech. Kept as plain data (not
/// fetched from a network) so language pickers work instantly and offline.
const List<Language> kSupportedLanguages = [
  Language(code: 'en', name: 'English', nativeName: 'English', flagCountryCode: 'US'),
  Language(code: 'es', name: 'Spanish', nativeName: 'Español', flagCountryCode: 'ES'),
  Language(code: 'fr', name: 'French', nativeName: 'Français', flagCountryCode: 'FR'),
  Language(code: 'de', name: 'German', nativeName: 'Deutsch', flagCountryCode: 'DE'),
  Language(code: 'it', name: 'Italian', nativeName: 'Italiano', flagCountryCode: 'IT'),
  Language(code: 'pt', name: 'Portuguese', nativeName: 'Português', flagCountryCode: 'PT'),
  Language(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flagCountryCode: 'NL'),
  Language(code: 'sv', name: 'Swedish', nativeName: 'Svenska', flagCountryCode: 'SE'),
  Language(code: 'no', name: 'Norwegian', nativeName: 'Norsk', flagCountryCode: 'NO'),
  Language(code: 'da', name: 'Danish', nativeName: 'Dansk', flagCountryCode: 'DK'),
  Language(code: 'fi', name: 'Finnish', nativeName: 'Suomi', flagCountryCode: 'FI'),
  Language(code: 'pl', name: 'Polish', nativeName: 'Polski', flagCountryCode: 'PL'),
  Language(code: 'ru', name: 'Russian', nativeName: 'Русский', flagCountryCode: 'RU'),
  Language(code: 'uk', name: 'Ukrainian', nativeName: 'Українська', flagCountryCode: 'UA'),
  Language(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flagCountryCode: 'TR'),
  Language(code: 'el', name: 'Greek', nativeName: 'Ελληνικά', flagCountryCode: 'GR'),
  Language(code: 'cs', name: 'Czech', nativeName: 'Čeština', flagCountryCode: 'CZ'),
  Language(code: 'ro', name: 'Romanian', nativeName: 'Română', flagCountryCode: 'RO'),
  Language(code: 'hu', name: 'Hungarian', nativeName: 'Magyar', flagCountryCode: 'HU'),
  Language(code: 'ar', name: 'Arabic', nativeName: 'العربية', flagCountryCode: 'SA'),
  Language(code: 'he', name: 'Hebrew', nativeName: 'עברית', flagCountryCode: 'IL'),
  Language(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flagCountryCode: 'IN'),
  Language(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', flagCountryCode: 'BD'),
  Language(code: 'ur', name: 'Urdu', nativeName: 'اردو', flagCountryCode: 'PK'),
  Language(code: 'zh-CN', name: 'Chinese (Simplified)', nativeName: '中文', flagCountryCode: 'CN'),
  Language(code: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文', flagCountryCode: 'TW'),
  Language(code: 'ja', name: 'Japanese', nativeName: '日本語', flagCountryCode: 'JP'),
  Language(code: 'ko', name: 'Korean', nativeName: '한국어', flagCountryCode: 'KR'),
  Language(code: 'th', name: 'Thai', nativeName: 'ไทย', flagCountryCode: 'TH'),
  Language(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', flagCountryCode: 'VN'),
  Language(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flagCountryCode: 'ID'),
  Language(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', flagCountryCode: 'MY'),
  Language(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', flagCountryCode: 'KE'),
  Language(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans', flagCountryCode: 'ZA'),
];

Language languageByCode(String code) => kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kSupportedLanguages.first,
    );
