/// Thrown by data sources / providers. Repositories catch these and convert
/// them into [Failure]s so nothing above the data layer depends on
/// data-layer exception types.
class SpeechException implements Exception {
  const SpeechException(this.message);
  final String message;
}

class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;
}

class TtsException implements Exception {
  const TtsException(this.message);
  final String message;
}

class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.message);
  final String message;
}

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
}
