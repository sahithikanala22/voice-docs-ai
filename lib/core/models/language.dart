import 'package:freezed_annotation/freezed_annotation.dart';

part 'language.freezed.dart';

/// A supported language for speech recognition, translation and TTS.
///
/// [code] is a BCP-47 / ISO-639-1 language code (e.g. `en`, `en-US`) used by
/// the speech, translation and TTS providers. [flagCountryCode] is the
/// ISO-3166 country code used to render a representative flag icon — several
/// languages (e.g. Arabic, English) intentionally map to one representative
/// country rather than every country that speaks them.
@freezed
class Language with _$Language {
  const factory Language({
    required String code,
    required String name,
    required String nativeName,
    required String flagCountryCode,
  }) = _Language;
}
