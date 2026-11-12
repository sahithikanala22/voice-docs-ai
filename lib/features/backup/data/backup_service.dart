import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/core/utils/export_filename.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/folders/data/folder.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';

const _keys = {
  'history': PrefsKeys.history,
  'settings': PrefsKeys.settings,
  'folders': PrefsKeys.folders,
  'tasks': PrefsKeys.tasks,
  'diary': PrefsKeys.diary,
};
const _assetPrefix = 'backup-attachment:';
const _maxBackupBytes = 100 * 1024 * 1024;

/// Portable backups contain personal data and images, never PIN hashes or API
/// keys. Internal recovery snapshots are additionally encrypted on this device.
class BackupService {
  BackupService(this._prefs);
  final SharedPreferences _prefs;
  PrivateStore get _store => PrivateStore(_prefs);

  Future<Map<String, dynamic>> _buildPayload() async {
    final data = <String, dynamic>{};
    final assets = <String, dynamic>{};
    for (final entry in _keys.entries) {
      final raw = await _store.read(entry.value);
      if (raw == null) continue;
      var value = jsonDecode(raw);
      if (entry.key == 'settings') {
        value = Map<String, dynamic>.from(value as Map)
          ..remove('googleCloudApiKey');
        value['biometricUnlockEnabled'] = false;
      }
      data[entry.key] = jsonEncode(await _packImages(value, assets));
    }
    final accountRaw = await _store.read(PrefsKeys.appLockAccount);
    if (accountRaw != null) {
      final profile = Map<String, dynamic>.from(jsonDecode(accountRaw) as Map)
        ..remove('pinHash');
      data['profile'] = jsonEncode(await _packImages(profile, assets));
    }
    return {
      'app': AppConstants.appName,
      'formatVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
      'attachments': assets,
    };
  }

  Future<dynamic> _packImages(
    dynamic value,
    Map<String, dynamic> assets,
  ) async {
    if (value is List) {
      return Future.wait(value.map((v) => _packImages(v, assets)));
    }
    if (value is! Map) return value;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key.toString().endsWith('Path') && entry.value is String) {
        final file = File(entry.value as String);
        final root = await (await getApplicationDocumentsDirectory())
            .resolveSymbolicLinks();
        final resolved = await file.resolveSymbolicLinks();
        if (!resolved.startsWith('$root${Platform.pathSeparator}')) {
          throw const StorageException(
            'An image is outside the app storage. Choose it again before backing up.',
          );
        }
        if (await file.length() > 20 * 1024 * 1024) {
          throw const StorageException('An image is too large to back up.');
        }
        final bytes = await file.readAsBytes();
        await _validateImage(bytes);
        final id = sha256.convert(bytes).toString();
        assets[id] = {'sha256': id, 'bytes': base64Encode(bytes)};
        result[entry.key as String] = '$_assetPrefix$id';
      } else {
        result[entry.key as String] = await _packImages(entry.value, assets);
      }
    }
    return result;
  }

  Future<File> exportToFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voicedocsai_${exportFilenameStamp()}.json');
    final encoded = jsonEncode(await _buildPayload());
    if (utf8.encode(encoded).length > _maxBackupBytes) {
      throw const StorageException('The backup is too large.');
    }
    await file.writeAsString(encoded, flush: true);
    await _readAndValidate(file);
    return file;
  }

  Future<void> importFromFile(File file) async =>
      _apply(await _readAndValidate(file));
  Future<File> _autoBackupFile() async => File(
    '${(await getApplicationDocumentsDirectory()).path}/auto_backup_before_reset.json',
  );
  Future<void> saveAutoBackupBeforeReset() async {
    final file = await _autoBackupFile();
    await file.writeAsString(
      await _store.seal(jsonEncode(await _buildPayload())),
      flush: true,
    );
    await _readAndValidate(file);
  }

  Future<bool> hasAutoBackup() async => (await _autoBackupFile()).exists();
  Future<void> restoreAutoBackupAfterReset() async {
    final file = await _autoBackupFile();
    if (!await file.exists()) return;
    await _apply(await _readAndValidate(file), includeProfile: false);
    await file.delete();
  }

  Future<Map<String, dynamic>> _readAndValidate(File file) async {
    try {
      if (await file.length() > _maxBackupBytes) {
        throw const FormatException('Backup too large');
      }
      var text = await file.readAsString();
      var payload = jsonDecode(text) as Map<String, dynamic>;
      if (payload['encrypted'] == 1) {
        text = await _store.open(text);
        payload = jsonDecode(text) as Map<String, dynamic>;
      }
      final version = payload['formatVersion'];
      if (payload['app'] != AppConstants.appName ||
          (version != 1 && version != 2)) {
        throw const FormatException('Unsupported backup version');
      }
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      if (!data.keys.any((k) => _keys.containsKey(k))) {
        throw const FormatException('Empty backup');
      }
      if (data.keys.any(
        (key) =>
            !_keys.containsKey(key) &&
            key != 'profile' &&
            key != 'appLockAccount',
      )) {
        throw const FormatException('Unknown data section');
      }
      for (final entry in data.entries) {
        if (entry.value != null && entry.value is! String) {
          throw const FormatException('Invalid data section');
        }
        if (entry.value != null) jsonDecode(entry.value as String);
      }
      void validateList(
        String key,
        dynamic Function(Map<String, dynamic>) parse,
      ) {
        if (data[key] == null) return;
        final rows = jsonDecode(data[key] as String) as List;
        final ids = <String>{};
        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['id'] as String;
          if (id.isEmpty || !ids.add(id)) {
            throw const FormatException('Duplicate or empty id');
          }
          parse(map);
        }
      }

      validateList('history', HistoryItem.fromJson);
      validateList('folders', Folder.fromJson);
      validateList('tasks', Task.fromJson);
      validateList('diary', DiaryEntry.fromJson);
      if (data['settings'] != null) {
        final settings = AppSettings.fromJson(
          jsonDecode(data['settings'] as String) as Map<String, dynamic>,
        );
        data['settings'] = jsonEncode(
          settings
              .copyWith(googleCloudApiKey: null, biometricUnlockEnabled: false)
              .toJson(),
        );
      }
      if (version == 1 && data['appLockAccount'] != null) {
        final account = AppLockAccount.fromJson(
          jsonDecode(data['appLockAccount'] as String) as Map<String, dynamic>,
        );
        data['profile'] = jsonEncode(account.toJson()..remove('pinHash'));
      }
      data.remove('appLockAccount');
      if (data['profile'] != null) {
        final profile =
            jsonDecode(data['profile'] as String) as Map<String, dynamic>;
        AppLockAccount.fromJson({...profile, 'pinHash': 'validation-only'});
        profile.remove('pinHash');
        data['profile'] = jsonEncode(profile);
      }
      final attachments = Map<String, dynamic>.from(
        payload['attachments'] as Map? ?? {},
      );
      var total = 0;
      for (final entry in attachments.entries) {
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key)) {
          throw const FormatException('Invalid attachment id');
        }
        final asset = entry.value as Map;
        final bytes = base64Decode(asset['bytes'] as String);
        total += bytes.length;
        if (bytes.length > 20 * 1024 * 1024 ||
            total > _maxBackupBytes ||
            asset['sha256'] != entry.key ||
            sha256.convert(bytes).toString() != entry.key) {
          throw const FormatException('Corrupt attachment');
        }
        await _validateImage(bytes);
      }
      // Validate every reference before any files or preferences are changed.
      for (final key in data.keys.toList()) {
        if (data[key] != null) {
          data[key] = jsonEncode(
            _images(jsonDecode(data[key] as String), (path) {
              if (version == 1) return null; // v1 never included image bytes.
              if (!path.startsWith(_assetPrefix) ||
                  !attachments.containsKey(
                    path.substring(_assetPrefix.length),
                  )) {
                throw const FormatException('Missing image attachment');
              }
              return path;
            }),
          );
        }
      }
      payload['data'] = data;
      payload['attachments'] = attachments;
      return payload;
    } catch (_) {
      throw const StorageException(
        'Invalid, incomplete, corrupt, or unsupported backup. No data was changed.',
      );
    }
  }

  static Future<void> _validateImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1,
      targetHeight: 1,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  dynamic _images(dynamic value, String? Function(String) map) {
    if (value is List) return value.map((v) => _images(v, map)).toList();
    if (value is! Map) return value;
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String:
            entry.key.toString().endsWith('Path') && entry.value is String
            ? map(entry.value as String)
            : _images(entry.value, map),
    };
  }

  Future<void> _apply(
    Map<String, dynamic> payload, {
    bool includeProfile = true,
  }) async {
    final data = payload['data'] as Map<String, dynamic>;
    final assets = payload['attachments'] as Map<String, dynamic>;
    final root = await getApplicationDocumentsDirectory();
    final imageRoot = await Directory(
      '${root.path}/restored_images',
    ).create(recursive: true);
    final staging = await imageRoot.createTemp('restore_');
    final original = <String, String?>{};
    try {
      for (final entry in assets.entries) {
        await File('${staging.path}/${entry.key}.image').writeAsBytes(
          base64Decode((entry.value as Map)['bytes'] as String),
          flush: true,
        );
      }
      final updates = <String, String>{};
      String? replace(String path) =>
          '${staging.path}/${path.substring(_assetPrefix.length)}.image';
      for (final entry in _keys.entries) {
        if (data[entry.key] == null) continue;
        var decoded = _images(jsonDecode(data[entry.key] as String), replace);
        if (entry.key == 'settings') {
          // Credentials are device-local and never replaced from a backup.
          final current = await _store.read(PrefsKeys.settings);
          if (current != null) {
            decoded['googleCloudApiKey'] =
                (jsonDecode(current) as Map)['googleCloudApiKey'];
          }
        }
        updates[entry.value] = jsonEncode(decoded);
      }
      if (includeProfile && data['profile'] != null) {
        final current = await _store.read(PrefsKeys.appLockAccount);
        if (current != null) {
          final account = jsonDecode(current) as Map<String, dynamic>;
          final profile =
              _images(jsonDecode(data['profile'] as String), replace) as Map;
          updates[PrefsKeys.appLockAccount] = jsonEncode({
            ...account,
            ...profile,
            'pinHash': account['pinHash'],
          });
        }
      }
      for (final key in updates.keys) {
        original[key] = _prefs.getString(key);
      }
      for (final entry in updates.entries) {
        await _store.write(entry.key, entry.value);
      }
    } catch (_) {
      for (final entry in original.entries) {
        if (entry.value == null) {
          await _prefs.remove(entry.key);
        } else {
          await _prefs.setString(entry.key, entry.value!);
        }
      }
      await staging.delete(recursive: true);
      rethrow;
    }
  }
}
