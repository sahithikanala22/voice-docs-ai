/// One selectable device TTS voice — `name` is the opaque identifier the
/// platform's engine uses internally (what gets persisted/passed back to
/// `setVoice`); `locale` is the region-qualified language it speaks (e.g.
/// `en-US`), used to filter voices down to the ones relevant for whatever
/// language is currently being spoken.
class TtsVoiceOption {
  const TtsVoiceOption({required this.name, required this.locale});

  final String name;
  final String locale;
}
