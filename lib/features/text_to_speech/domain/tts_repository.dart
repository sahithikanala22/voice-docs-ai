abstract class TtsRepository {
  Future<void> speak(String text, String languageCode);

  Future<void> stop();

  void onStart(void Function() callback);

  void onComplete(void Function() callback);

  void onError(void Function(String message) callback);
}
