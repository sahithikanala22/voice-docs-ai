/// Canonical key shared by voice selection and playback.
String languageKey(String locale) =>
    locale.toLowerCase().replaceAll('_', '-').split('-').first;

String? preferredVoice(Map<String, String> voices, String locale) {
  final key = languageKey(locale);
  return voices[key] ??
      voices.entries
          .where((e) => languageKey(e.key) == key)
          .map((e) => e.value)
          .firstOrNull;
}
