import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/whisper_model_store.dart';

final whisperModelStoreProvider = Provider<WhisperModelStore>((ref) {
  final store = WhisperModelStore();
  ref.onDispose(store.dispose);
  return store;
});

final whisperModelControllerProvider =
    StateNotifierProvider<WhisperModelController, WhisperModelState>(
      (ref) => WhisperModelController(ref.watch(whisperModelStoreProvider)),
    );

class WhisperModelController extends StateNotifier<WhisperModelState> {
  WhisperModelController(this.store) : super(store.state) {
    _subscription = store.changes.listen((next) {
      if (mounted) state = next;
    });
    unawaited(store.refresh());
  }
  final WhisperModelStore store;
  late final StreamSubscription<WhisperModelState> _subscription;
  Future<void> download() => store.download();
  Future<void> refresh() => store.refresh();
  void cancel() => store.cancelDownload();
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
