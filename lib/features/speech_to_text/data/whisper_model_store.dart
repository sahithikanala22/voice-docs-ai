import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum WhisperModelPhase {
  missing,
  checking,
  downloading,
  verifying,
  ready,
  failed,
}

class WhisperModelState {
  const WhisperModelState(
    this.phase, {
    this.received = 0,
    this.total = 0,
    this.error,
  });
  final WhisperModelPhase phase;
  final int received, total;
  final String? error;
  bool get busy => {
    WhisperModelPhase.checking,
    WhisperModelPhase.downloading,
    WhisperModelPhase.verifying,
  }.contains(phase);
}

class WhisperModelArtifact {
  const WhisperModelArtifact({
    required this.uri,
    required this.bytes,
    required this.sha256,
  });
  final String uri, sha256;
  final int bytes;
  // Immutable revision and SHA-256 from the upstream GGML model repository.
  static const base = WhisperModelArtifact(
    uri:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin',
    bytes: 147951465,
    sha256: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
  );
}

/// Model downloads never touch recordings. Only a fully verified staging file
/// can become the installed model. Inference never initiates a download.
class WhisperModelStore {
  WhisperModelStore({
    Dio? dio,
    Future<Directory> Function()? directory,
    this.artifact = WhisperModelArtifact.base,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 2),
             ),
           ),
       _directory = directory ?? defaultDirectory;
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final WhisperModelArtifact artifact;
  final _changes = StreamController<WhisperModelState>.broadcast(sync: true);
  Stream<WhisperModelState> get changes => _changes.stream;
  WhisperModelState state = const WhisperModelState(WhisperModelPhase.missing);
  CancelToken? _downloadToken;
  Future<void>? _download;
  Future<String?>? _checking;
  String? _verifiedStamp;
  bool _disposed = false;
  static Future<Directory> defaultDirectory() async => Directory(
    '${(await getApplicationDocumentsDirectory()).path}/whisper_models',
  );
  void _emit(WhisperModelState next) {
    state = next;
    if (!_disposed) _changes.add(next);
  }

  Future<File> get modelFile async =>
      File('${(await _directory()).path}/ggml-base.bin');
  Future<bool> _valid(File file) async =>
      await file.exists() &&
      await file.length() == artifact.bytes &&
      (await sha256.bind(file.openRead()).first).toString() == artifact.sha256;

  Future<String?> verifiedPath() =>
      _checking ??= _verifyInstalled().whenComplete(() => _checking = null);
  Future<String?> _verifyInstalled() async {
    final file = await modelFile;
    if (!await file.exists()) {
      _verifiedStamp = null;
      return null;
    }
    final stat = await file.stat();
    final stamp =
        '${file.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    if (_verifiedStamp != stamp) {
      if (!await _valid(file)) return null;
      _verifiedStamp = stamp;
    }
    return file.path;
  }

  Future<String> requireReady() async {
    final path = await verifiedPath();
    if (path == null) {
      throw StateError(
        'Whisper model is missing or damaged. Download or retry the model in Settings > Speech Recognition. Audio is kept in Saved recordings.',
      );
    }
    return path;
  }

  Future<void> refresh() async {
    if (_download != null || _disposed) return;
    _emit(const WhisperModelState(WhisperModelPhase.checking));
    try {
      _emit(
        WhisperModelState(
          await verifiedPath() == null
              ? WhisperModelPhase.missing
              : WhisperModelPhase.ready,
        ),
      );
    } catch (_) {
      _emit(
        const WhisperModelState(
          WhisperModelPhase.failed,
          error:
              'Model storage could not be checked. Free space and try again.',
        ),
      );
    }
  }

  Future<void> download() =>
      _download ??= _downloadVerified().whenComplete(() => _download = null);
  Future<void> _downloadVerified() async {
    final token = CancelToken();
    _downloadToken = token;
    File? staging;
    try {
      _emit(const WhisperModelState(WhisperModelPhase.checking));
      if (await verifiedPath() != null) {
        _emit(const WhisperModelState(WhisperModelPhase.ready));
        return;
      }
      final target = await modelFile;
      await target.parent.create(recursive: true);
      staging = File('${target.path}.part');
      _emit(
        WhisperModelState(WhisperModelPhase.downloading, total: artifact.bytes),
      );
      await _dio.download(
        artifact.uri,
        staging.path,
        cancelToken: token,
        onReceiveProgress: (received, _) {
          if (!token.isCancelled) {
            _emit(
              WhisperModelState(
                WhisperModelPhase.downloading,
                received: received,
                total: artifact.bytes,
              ),
            );
          }
        },
      );
      _emit(const WhisperModelState(WhisperModelPhase.verifying));
      if (!await _valid(staging)) {
        throw const FormatException('Model integrity check failed');
      }
      if (token.isCancelled) throw StateError('Download cancelled');
      final handle = await staging.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      await staging.rename(target.path);
      _verifiedStamp = null;
      if (await verifiedPath() == null) {
        throw StateError('Model verification failed');
      }
      _emit(const WhisperModelState(WhisperModelPhase.ready));
    } catch (_) {
      _emit(
        WhisperModelState(
          WhisperModelPhase.failed,
          error: token.isCancelled
              ? 'Download cancelled. Tap Retry download.'
              : 'Download or integrity check failed. Check connection and free space, then retry. Saved audio is unaffected.',
        ),
      );
    } finally {
      if (staging != null && await staging.exists()) await staging.delete();
      _downloadToken = null;
    }
  }

  void cancelDownload() => _downloadToken?.cancel('Model download cancelled');
  Future<void> cancelAndWait() async {
    cancelDownload();
    await _download;
  }

  void dispose() {
    _disposed = true;
    cancelDownload();
    unawaited(_changes.close());
    _dio.close(force: true);
  }
}
