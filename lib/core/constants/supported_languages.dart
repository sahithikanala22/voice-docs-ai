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

  // Indian regional languages
  Language(code: 'te', localeHint: 'te-IN', name: 'Telugu', nativeName: 'తెలుగు', flagCountryCode: 'IN'),
  Language(code: 'ta', localeHint: 'ta-IN', name: 'Tamil', nativeName: 'தமிழ்', flagCountryCode: 'IN'),
  Language(code: 'kn', localeHint: 'kn-IN', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flagCountryCode: 'IN'),
  Language(code: 'ml', localeHint: 'ml-IN', name: 'Malayalam', nativeName: 'മലയാളം', flagCountryCode: 'IN'),
  Language(code: 'mr', localeHint: 'mr-IN', name: 'Marathi', nativeName: 'मराठी', flagCountryCode: 'IN'),
  Language(code: 'gu', localeHint: 'gu-IN', name: 'Gujarati', nativeName: 'ગુજરાતી', flagCountryCode: 'IN'),
  Language(code: 'pa', localeHint: 'pa-IN', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', flagCountryCode: 'IN'),
  Language(code: 'or', localeHint: 'or-IN', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', flagCountryCode: 'IN'),
  Language(code: 'as', localeHint: 'as-IN', name: 'Assamese', nativeName: 'অসমীয়া', flagCountryCode: 'IN'),
  Language(code: 'ne', localeHint: 'ne-NP', name: 'Nepali', nativeName: 'नेपाली', flagCountryCode: 'NP'),
  Language(code: 'si', localeHint: 'si-LK', name: 'Sinhala', nativeName: 'සිංහල', flagCountryCode: 'LK'),

  // Additional world languages
  Language(code: 'fa', localeHint: 'fa-IR', name: 'Persian', nativeName: 'فارسی', flagCountryCode: 'IR'),
  Language(code: 'tl', localeHint: 'fil-PH', name: 'Filipino', nativeName: 'Filipino', flagCountryCode: 'PH'),
  Language(code: 'my', localeHint: 'my-MM', name: 'Burmese', nativeName: 'မြန်မာ', flagCountryCode: 'MM'),
  Language(code: 'km', localeHint: 'km-KH', name: 'Khmer', nativeName: 'ខ្មែរ', flagCountryCode: 'KH'),
  Language(code: 'lo', localeHint: 'lo-LA', name: 'Lao', nativeName: 'ລາວ', flagCountryCode: 'LA'),
  Language(code: 'mn', localeHint: 'mn-MN', name: 'Mongolian', nativeName: 'Монгол', flagCountryCode: 'MN'),
  Language(code: 'ka', localeHint: 'ka-GE', name: 'Georgian', nativeName: 'ქართული', flagCountryCode: 'GE'),
  Language(code: 'hy', localeHint: 'hy-AM', name: 'Armenian', nativeName: 'Հայերեն', flagCountryCode: 'AM'),
  Language(code: 'az', localeHint: 'az-AZ', name: 'Azerbaijani', nativeName: 'Azərbaycan', flagCountryCode: 'AZ'),
  Language(code: 'kk', localeHint: 'kk-KZ', name: 'Kazakh', nativeName: 'Қазақ', flagCountryCode: 'KZ'),
  Language(code: 'uz', localeHint: 'uz-UZ', name: 'Uzbek', nativeName: 'Oʻzbek', flagCountryCode: 'UZ'),
  Language(code: 'am', localeHint: 'am-ET', name: 'Amharic', nativeName: 'አማርኛ', flagCountryCode: 'ET'),
  Language(code: 'zu', localeHint: 'zu-ZA', name: 'Zulu', nativeName: 'isiZulu', flagCountryCode: 'ZA'),
  Language(code: 'sr', localeHint: 'sr-RS', name: 'Serbian', nativeName: 'Српски', flagCountryCode: 'RS'),
  Language(code: 'bg', localeHint: 'bg-BG', name: 'Bulgarian', nativeName: 'Български', flagCountryCode: 'BG'),
  Language(code: 'hr', localeHint: 'hr-HR', name: 'Croatian', nativeName: 'Hrvatski', flagCountryCode: 'HR'),
  Language(code: 'sk', localeHint: 'sk-SK', name: 'Slovak', nativeName: 'Slovenčina', flagCountryCode: 'SK'),
  Language(code: 'sl', localeHint: 'sl-SI', name: 'Slovenian', nativeName: 'Slovenščina', flagCountryCode: 'SI'),
  Language(code: 'lt', localeHint: 'lt-LT', name: 'Lithuanian', nativeName: 'Lietuvių', flagCountryCode: 'LT'),
  Language(code: 'lv', localeHint: 'lv-LV', name: 'Latvian', nativeName: 'Latviešu', flagCountryCode: 'LV'),
  Language(code: 'et', localeHint: 'et-EE', name: 'Estonian', nativeName: 'Eesti', flagCountryCode: 'EE'),
  Language(code: 'ca', localeHint: 'ca-ES', name: 'Catalan', nativeName: 'Català', flagCountryCode: 'ES'),
  Language(code: 'is', localeHint: 'is-IS', name: 'Icelandic', nativeName: 'Íslenska', flagCountryCode: 'IS'),
];

Language languageByCode(String code) => kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kSupportedLanguages.first,
    );
