import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/exceptions.dart';

/// Encrypts feature JSON with an authenticated, random per-installation key.
/// Only ciphertext goes into preferences; the key stays in Keychain/Keystore.
/// Legacy plaintext is migrated on the first successful read.
class PrivateStore {
  PrivateStore(this.prefs);
  final SharedPreferences prefs;
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _keyName = 'voice_docs.data_key.v1';
  static final _keys = Expando<Future<SecretKey>>();
  static final _cipher = AesGcm.with256bits();

  Future<SecretKey> _key({bool create = true}) {
    final existing = _keys[prefs];
    if (existing != null) return existing;
    final pending =
        () async {
          final stored = await _storage.read(key: _keyName);
          if (stored != null) return SecretKey(base64Decode(stored));
          if (!create) {
            throw const StorageException(
              'The device encryption key is unavailable. Restore a backup to recover your data.',
            );
          }
          final key = await _cipher.newSecretKey();
          await _storage.write(
            key: _keyName,
            value: base64Encode(await key.extractBytes()),
          );
          return key;
        }().catchError((Object error, StackTrace stack) {
          _keys[prefs] = null;
          Error.throwWithStackTrace(error, stack);
        });
    _keys[prefs] = pending;
    return pending;
  }

  Future<void> destroyKey() async {
    await _storage.delete(key: _keyName);
    _keys[prefs] = null;
  }

  Future<String> seal(String value) async {
    final box = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: await _key(),
    );
    return jsonEncode({
      'encrypted': 1,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> open(String value) async {
    final data = jsonDecode(value);
    if (data is! Map || data['encrypted'] != 1) {
      throw const StorageException('Invalid encrypted data.');
    }
    final bytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(data['ciphertext'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['mac'] as String)),
      ),
      secretKey: await _key(create: false),
    );
    return utf8.decode(bytes);
  }

  Future<String?> read(String key) async {
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) return value;
    final decoded = jsonDecode(value);
    if (decoded is Map && decoded['encrypted'] == 1) return open(value);
    await write(key, value);
    return value;
  }

  Future<void> write(String key, String value) async {
    if (!await prefs.setString(key, await seal(value))) {
      throw const StorageException('Your changes could not be saved.');
    }
  }
}
