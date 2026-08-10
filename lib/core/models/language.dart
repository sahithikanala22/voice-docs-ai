import 'package:freezed_annotation/freezed_annotation.dart';

part 'language.freezed.dart';

/// A supported language for speech recognition, translation and TTS.
///
/// [code] is the bare ISO-639-1 code (e.g. `en`) used by the *translation*
/// provider, which doesn't understand region-qualified locales. [localeHint]
/// is a full BCP-47 locale (e.g. `en-US`) used by the on-device speech and
/// TTS providers, which require a region — passing a bare code to either
/// fails with `error_language_not_supported` / `error_language_unavailable`.
/// [flagCountryCode] is the ISO-3166 country code used to render a
/// representative flag icon — several languages (e.g. Arabic, English)
/// intentionally map to one representative country rather than every country
/// that speaks them.
@freezed
class Language with _$Language {
  const factory Language({
    required String code,
    required String localeHint,
    required String name,
    required String nativeName,
    required String flagCountryCode,
  }) = _Language;
}
