import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import '../domain/recording_phase.dart';

class PendingRecording {
  const PendingRecording({
    required this.id,
    required this.locale,
    required this.createdAt,
    this.transcript = '',
    this.phase = RecordingPhase.interrupted,
    this.byteLength = 0,
    this.chunks = const {},
    this.historyId,
    this.error,
    this.folderId,
    this.entryDate,
    this.transcriptionBackend = 'googleCloud',
  });
  final String id, locale, transcript;
  final DateTime createdAt;
  final RecordingPhase phase;
  final int byteLength;
  final Map<int, String> chunks;
  final String? historyId, error, folderId;
  final DateTime? entryDate;
  final String transcriptionBackend;
  Duration get duration => Duration(milliseconds: byteLength * 1000 ~/ 32000);
  String get transcriptId => 'recovered-cloud-$id';
}

/// Raw capture is durable and OS-private from the start. After stop it is
/// encrypted in bounded blocks. Failed sealing retains the raw source.
/// Existing V1 encrypted envelopes remain readable without destructive migration.
class PendingRecordingStore {
  PendingRecordingStore(this.store, {Future<Directory> Function()? directory})
    : _directory = directory ?? defaultDirectory;
  final PrivateStore store;
  final Future<Directory> Function() _directory;
  static const maxRecordings = 10;
  static const blockBytes = 512 * 1024;
  static const maxReadBytes = 2 * 1024 * 1024;
  static const maxRecordingBytes = 256 * 1024 * 1024;
  static final _locks = <String, Future<void>>{};
  static final _jobs = <String>{};
  static final _random = Random.secure();
  static Future<Directory> defaultDirectory() async => Directory(
    '${(await getApplicationDocumentsDirectory()).path}/pending_cloud_recordings',
  );
  static Future<PendingRecordingStore> open() async => PendingRecordingStore(
    PrivateStore(await SharedPreferences.getInstance()),
  );

  Future<File> _file(String id, [String suffix = '.json']) async {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const FormatException('Invalid recording ID');
    }
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$id$suffix');
  }

  Future<String> capturePath(String id) async => (await _file(id, '.pcm')).path;
  Future<Map<String, dynamic>> _read(String id) async =>
      jsonDecode(await store.open(await (await _file(id)).readAsString()))
          as Map<String, dynamic>;
  Future<void> _atomic(File file, String text) async {
    final staging = File('${file.path}.tmp');
    await staging.writeAsString(text, flush: true);
    await staging.rename(file.path);
  }

  Future<void> _write(String id, Map<String, dynamic> data) async =>
      _atomic(await _file(id), await store.seal(jsonEncode(data)));
  Future<void> _change(
    String id,
    FutureOr<void> Function(Map<String, dynamic>) change,
  ) async {
    final path = (await _file(id)).path;
    final work = (_locks[path] ?? Future<void>.value()).then((_) async {
      final data = await _read(id);
      await change(data);
      await _write(id, data);
    });
    final settled = work.catchError((Object _) {});
    _locks[path] = settled;
    try {
      await work;
    } finally {
      if (identical(_locks[path], settled)) _locks.remove(path);
    }
  }

  Future<PendingRecording> begin(
    String locale, {
    DateTime? entryDate,
    String? folderId,
  }) async {
    if ((await list()).length >= maxRecordings) {
      throw StateError(
        'Saved recording limit reached. Export or delete one first.',
      );
    }
    final now = DateTime.now();
    final id =
        '${now.microsecondsSinceEpoch}${_random.nextInt(1000000).toString().padLeft(6, '0')}';
    await _write(id, {
      'version': 2,
      'id': id,
      'locale': locale,
      'createdAt': now.toIso8601String(),
      'entryDate': entryDate?.toIso8601String(),
      'folderId': folderId,
      'phase': 'preparing',
      'byteLength': 0,
      'sealed': false,
      'chunks': <String, String>{},
      'transcript': '',
    });
    return get(id);
  }

  Future<PendingRecording> get(String id) async {
    final data = await _read(id);
    if (data['version'] != null && data['version'] != 2) {
      throw const FormatException(
        'Unknown recording format. Original files were kept.',
      );
    }
    final raw = await _file(id, '.pcm');
    final bytes = data['audio'] != null
        ? base64Decode(data['audio'] as String).length
        : data['sealed'] != true && await raw.exists()
        ? await raw.length()
        : data['byteLength'] as int? ?? 0;
    final chunks = <int, String>{};
    for (final entry in ((data['chunks'] as Map?) ?? {}).entries) {
      chunks[int.parse(entry.key as String)] = entry.value as String;
    }
    final text = data['transcript'] as String? ?? '';
    return PendingRecording(
      id: id,
      locale: data['locale'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      transcript: text,
      phase: RecordingPhase.values.byName(
        data['phase'] as String? ??
            (text.isEmpty ? 'interrupted' : 'completed'),
      ),
      byteLength: bytes - bytes % 2,
      chunks: chunks,
      historyId: data['historyId'] as String?,
      error: data['error'] as String?,
      folderId: data['folderId'] as String?,
      entryDate: data['entryDate'] == null
          ? null
          : DateTime.parse(data['entryDate'] as String),
      transcriptionBackend:
          data['transcriptionBackend'] as String? ?? 'googleCloud',
    );
  }

  Future<List<PendingRecording>> list() async {
    final dir = await _directory();
    if (!await dir.exists()) return [];
    final result = <PendingRecording>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (RegExp(r'^\d+\.json$').hasMatch(name)) {
        final id = name.replaceFirst('.json', '');
        try {
          result.add(await get(id));
        } catch (_) {
          result.add(
            PendingRecording(
              id: id,
              locale: 'und',
              createdAt: await entity.lastModified(),
              phase: RecordingPhase.failed,
              error: 'Metadata could not be opened. Original files were kept.',
            ),
          );
        }
      }
    }
    return result..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> setPhase(String id, RecordingPhase phase, {String? error}) =>
      _change(id, (data) {
        data['phase'] = phase.name;
        data['error'] = error;
      });

  /// Startup only: do not call while live capture or transcription is running.
  Future<void> recoverInterrupted() async {
    final dir = await _directory();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File ||
          !RegExp(r'^\d+\.json\.tmp$').hasMatch(entity.uri.pathSegments.last)) {
        continue;
      }
      try {
        final target = File(entity.path.substring(0, entity.path.length - 4));
        if (!await target.exists()) {
          await store.open(await entity.readAsString());
          await entity.rename(target.path);
        }
      } catch (_) {
        // A torn staging write must not prevent healthy recordings recovering.
        // Keep it untouched for a later retry or manual recovery.
      }
    }
    for (final item in await list()) {
      if ({
        RecordingPhase.preparing,
        RecordingPhase.recording,
        RecordingPhase.paused,
        RecordingPhase.saving,
        RecordingPhase.transcribing,
      }.contains(item.phase)) {
        try {
          await setPhase(
            item.id,
            RecordingPhase.interrupted,
            error:
                'Interrupted before completion. Audio and completed chunks are available.',
          );
        } catch (_) {
          // A per-recording storage failure cannot hide other recoverable audio.
        }
      }
    }
  }

  /// Adopt only old app-owned temporary PCM names; their language was not saved.
  Future<void> importLegacyTemporary(Directory temporary) async {
    if (!await temporary.exists()) return;
    await for (final entity in temporary.list(followLinks: false)) {
      if (entity is! File) continue;
      final match = RegExp(
        r'^gcloud_stt_(\d+)\.pcm$',
      ).firstMatch(entity.uri.pathSegments.last);
      if (match == null) continue;
      final id = match.group(1)!;
      final metadata = await _file(id);
      if (!await metadata.exists()) {
        await _write(id, {
          'version': 2,
          'id': id,
          'locale': 'und',
          'createdAt': (await entity.lastModified()).toIso8601String(),
          'phase': 'interrupted',
          'sealed': false,
          'byteLength': 0,
          'chunks': <String, String>{},
          'transcript': '',
          'error':
              'Recovered from an older capture. Select its original language before transcription.',
        });
      }
      final target = File(await capturePath(id));
      if (!await target.exists() ||
          await target.length() != await entity.length()) {
        await entity.copy(target.path);
      }
      final handle = await target.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      await entity.delete();
    }
  }

  Future<void> setUnknownLocale(String id, String locale) =>
      _change(id, (data) {
        if (data['locale'] != 'und' ||
            ((data['chunks'] as Map?)?.isNotEmpty ?? false)) {
          throw StateError('The original recording language is already set.');
        }
        data['locale'] = locale;
      });

  Future<void> sealCapture(String id) async {
    final data = await _read(id);
    if (data['audio'] != null || data['sealed'] == true) return;
    final raw = await _file(id, '.pcm');
    if (!await raw.exists()) {
      throw const FileSystemException('Captured audio is unavailable.');
    }
    final length = await raw.length();
    final input = await raw.open();
    try {
      var index = 0;
      while (true) {
        final bytes = await input.read(blockBytes);
        if (bytes.isEmpty) break;
        await _atomic(
          await _file(id, '.audio.$index'),
          await store.seal(base64Encode(bytes)),
        );
        index++;
      }
      await _change(id, (meta) {
        meta['sealed'] = true;
        meta['byteLength'] = length - length % 2;
        meta['blocks'] = index;
      });
    } finally {
      await input.close();
    }
    // Every block and its metadata have been flushed before removing raw PCM.
    await raw.delete();
  }

  Future<Uint8List> readAudio(String id, int offset, int length) async {
    if (offset < 0 || length < 0 || length > maxReadBytes) {
      throw const FormatException('Invalid audio range');
    }
    final data = await _read(id);
    if (data['audio'] != null) {
      final legacy = base64Decode(data['audio'] as String);
      return Uint8List.sublistView(
        legacy,
        min(offset, legacy.length),
        min(offset + length, legacy.length),
      );
    }
    if (data['sealed'] != true) {
      final input = await (await _file(id, '.pcm')).open();
      try {
        await input.setPosition(offset);
        return await input.read(length);
      } finally {
        await input.close();
      }
    }
    final output = BytesBuilder(copy: false);
    final end = min(offset + length, data['byteLength'] as int);
    for (var position = offset; position < end;) {
      final index = position ~/ blockBytes;
      final bytes = base64Decode(
        await store.open(
          await (await _file(id, '.audio.$index')).readAsString(),
        ),
      );
      final from = position % blockBytes;
      final count = min(bytes.length - from, end - position);
      if (count <= 0) throw const FormatException('Incomplete audio block');
      output.add(Uint8List.sublistView(bytes, from, from + count));
      position += count;
    }
    return output.takeBytes();
  }

  Future<Uint8List> audio(String id) async {
    final item = await get(id);
    if (item.byteLength > maxReadBytes) {
      throw StateError('Use readAudio for long recordings.');
    }
    return readAudio(id, 0, item.byteLength);
  }

  Future<PendingRecording> retain(Uint8List bytes, String locale) async {
    if (bytes.isEmpty || bytes.length > maxReadBytes) {
      throw const FormatException('Invalid recording size');
    }
    final item = await begin(locale);
    await File(await capturePath(item.id)).writeAsBytes(bytes, flush: true);
    await sealCapture(item.id);
    await setPhase(item.id, RecordingPhase.interrupted);
    return get(item.id);
  }

  Future<void> saveChunk(String id, int index, String text) =>
      _change(id, (data) {
        final chunks = Map<String, dynamic>.from(data['chunks'] as Map? ?? {});
        chunks[index.toString()] = text;
        data['chunks'] = chunks;
        final sorted = chunks.keys.map(int.parse).toList()..sort();
        data['transcript'] = sorted
            .map((i) => chunks['$i'] as String)
            .where((s) => s.isNotEmpty)
            .join(' ');
      });

  /// Checkpoints from different engines/chunk layouts must never be mixed.
  /// Keep each attempt so switching back can resume its own completed chunks.
  Future<void> selectTranscriptionBackend(String id, String backend) => _change(
    id,
    (data) {
      final current = data['transcriptionBackend'] as String? ?? 'googleCloud';
      if (current == backend) return;
      final attempts = Map<String, dynamic>.from(
        data['transcriptionAttempts'] as Map? ?? {},
      );
      attempts[current] = {
        'chunks': data['chunks'],
        'transcript': data['transcript'],
      };
      final selected = attempts[backend] as Map?;
      data['chunks'] = selected?['chunks'] ?? <String, String>{};
      data['transcript'] = selected?['transcript'] ?? '';
      data['transcriptionAttempts'] = attempts;
      data['transcriptionBackend'] = backend;
      data['phase'] = 'interrupted';
    },
  );
  Future<void> saveTranscript(String id, String text) => _change(id, (data) {
    data['transcript'] = text;
    data['phase'] = 'completed';
  });
  Future<void> markSaved(String id) => _change(id, (data) {
    data['historyId'] = 'recovered-cloud-$id';
  });
  Future<bool> acquireJob(String id) async => _jobs.add((await _file(id)).path);
  Future<void> releaseJob(String id) async {
    _jobs.remove((await _file(id)).path);
  }

  Future<int> storageBytes() async {
    final dir = await _directory();
    var bytes = 0;
    if (await dir.exists()) {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) bytes += await entity.length();
      }
    }
    return bytes;
  }

  Future<File> exportWav(
    String id,
    Directory destination, {
    int offset = 0,
    int? length,
    String? filename,
  }) async {
    final item = await get(id);
    if (item.byteLength == 0) throw StateError('No audio bytes were captured.');
    final byteLength = length ?? item.byteLength - offset;
    if (offset < 0 ||
        byteLength <= 0 ||
        offset + byteLength > item.byteLength ||
        offset.isOdd ||
        byteLength.isOdd ||
        (filename != null &&
            !RegExp(r'^[a-zA-Z0-9_.-]+\.wav$').hasMatch(filename))) {
      throw const FormatException('Invalid WAV range or filename');
    }
    await destination.create(recursive: true);
    final file = File(
      '${destination.path}/${filename ?? 'voicedocsai_recording_$id.wav'}',
    );
    final header = ByteData(44);
    void label(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        header.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    label(0, 'RIFF');
    header.setUint32(4, 36 + byteLength, Endian.little);
    label(8, 'WAVE');
    label(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    label(36, 'data');
    header.setUint32(40, byteLength, Endian.little);
    final output = await file.open(mode: FileMode.write);
    try {
      await output.writeFrom(header.buffer.asUint8List());
      for (var position = 0; position < byteLength; position += blockBytes) {
        await output.writeFrom(
          await readAudio(
            id,
            offset + position,
            min(blockBytes, byteLength - position),
          ),
        );
      }
      await output.flush();
    } catch (_) {
      await output.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await output.close();
    return file;
  }

  Future<void> delete(String id) async {
    final meta = await _file(id);
    if (_jobs.contains(meta.path)) {
      throw StateError('Cancel transcription before deleting.');
    }
    final dir = await _directory();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('$id.') &&
          entity.path != meta.path) {
        await entity.delete();
      }
    }
    if (await meta.exists()) await meta.delete();
  }
}
