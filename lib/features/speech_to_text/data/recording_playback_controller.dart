import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'pending_recording_store.dart';

/// One audio player for the app. Decrypted playback files exist only in cache
/// and are removed on stop, navigation, backgrounding, or the next cold start.
class RecordingPlaybackController extends ChangeNotifier {
  RecordingPlaybackController(
    this.store, {
    AudioPlayer Function()? playerFactory,
    Future<Directory> Function()? temporary,
  }) : _playerFactory = playerFactory ?? AudioPlayer.new,
       _temporary = temporary ?? getTemporaryDirectory;
  final PendingRecordingStore store;
  final AudioPlayer Function() _playerFactory;
  final Future<Directory> Function() _temporary;
  AudioPlayer? _player;
  Directory? _scratch;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _operations = Future.value();
  bool _disposed = false;
  int _epoch = 0;
  int _seekEpoch = 0;
  String? recordingId, error;
  bool playing = false, loading = false;
  Duration position = Duration.zero, duration = Duration.zero;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _queue(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.catchError((Object _) {});
    return result;
  }

  Future<void> play(String id, {Duration? from}) {
    final epoch = ++_epoch;
    return _queue(() async {
      if (_disposed || epoch != _epoch) return;
      error = null;
      loading = true;
      _notify();
      try {
        if (recordingId != id || _player == null) {
          await _release();
          final item = await store.get(id);
          final root = await Directory(
            '${(await _temporary()).path}/voicedocsai_playback',
          ).create(recursive: true);
          _scratch = await root.createTemp('clip_');
          final file = await store.exportWav(id, _scratch!);
          if (_disposed || epoch != _epoch) {
            await _release();
            return;
          }
          recordingId = id;
          duration = item.duration;
          position = Duration.zero;
          final player = _player = _playerFactory();
          await player.setReleaseMode(ReleaseMode.stop);
          _subscriptions.add(
            player.onPositionChanged.listen((value) {
              if (_disposed || recordingId != id) return;
              position = _clamp(value);
              _notify();
            }, onError: (Object _) => _playbackFailed(id)),
          );
          _subscriptions.add(
            player.onPlayerComplete.listen((_) {
              if (_disposed || recordingId != id) return;
              playing = false;
              position = Duration.zero;
              _notify();
            }, onError: (Object _) => _playbackFailed(id)),
          );
          await player.setSource(
            DeviceFileSource(file.path, mimeType: 'audio/wav'),
          );
        }
        if (_disposed || epoch != _epoch) {
          await _release();
          return;
        }
        if (from != null) position = _clamp(from);
        await _player!.seek(position);
        if (_disposed || epoch != _epoch) {
          await _release();
          return;
        }
        await _player!.resume();
        if (_disposed || epoch != _epoch) {
          await _release();
          return;
        }
        playing = true;
      } catch (_) {
        await _release();
        error =
            'Original audio could not be played. It may be unavailable on this device. Your text is kept.';
      } finally {
        loading = false;
        _notify();
      }
    });
  }

  Duration _clamp(Duration value) => Duration(
    microseconds: value.inMicroseconds.clamp(0, duration.inMicroseconds),
  );

  void _playbackFailed(String id) {
    if (_disposed || recordingId != id) return;
    error = 'Playback was interrupted. Your original audio is kept. Try again.';
    unawaited(stop());
  }

  Future<void> pause() => _queue(() async {
    if (_disposed || _player == null) return;
    try {
      await _player!.pause();
      playing = false;
    } catch (_) {
      await _release();
      error = 'Playback stopped. Try again.';
    }
    _notify();
  });

  Future<void> seek(Duration value) {
    final epoch = ++_seekEpoch;
    return _queue(() async {
      if (_disposed || _player == null || epoch != _seekEpoch) return;
      try {
        position = _clamp(value);
        await _player!.seek(position);
      } catch (_) {
        error = 'Could not seek. Try playing the recording again.';
      }
      _notify();
    });
  }

  Future<void> stop() {
    _epoch++;
    return _queue(() async {
      await _release();
      loading = false;
      _notify();
    });
  }

  Future<void> _release() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (_) {
      /* Release the cache even if the platform player failed. */
    } finally {
      final scratch = _scratch;
      _scratch = null;
      try {
        if (scratch != null && await scratch.exists()) {
          await scratch.delete(recursive: true);
        }
      } catch (_) {
        /* A cold start retries cleanup of this app-owned cache. */
      } finally {
        recordingId = null;
        playing = false;
        position = Duration.zero;
        duration = Duration.zero;
      }
    }
  }

  static Future<void> cleanupScratch(Directory temporary) async {
    final root = Directory('${temporary.path}/voicedocsai_playback');
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          entity.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('clip_')) {
        await entity.delete(recursive: true);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    unawaited(_queue(_release).catchError((Object _) {}));
    super.dispose();
  }
}
