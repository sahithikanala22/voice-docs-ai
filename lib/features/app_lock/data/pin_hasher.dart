import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart' as legacy;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

class PinHasher {
  const PinHasher({this.iterations = 600000});
  final int iterations;
  static const _channel = MethodChannel('com.aivoicedocs.app/pin_hash');

  Future<String> hash(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final bytes = await _derive(pin, salt, iterations);
    return 'pbkdf2-sha256:$iterations:${base64Encode(salt)}:${base64Encode(bytes)}';
  }

  Future<bool> verify(String pin, String stored) async {
    if (!stored.startsWith('pbkdf2-sha256:')) {
      return _equal(
        utf8.encode(legacy.sha256.convert(utf8.encode(pin)).toString()),
        utf8.encode(stored),
      );
    }
    final parts = stored.split(':');
    if (parts.length != 4) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1 || rounds > 2000000) return false;
    return _equal(
      await _derive(pin, base64Decode(parts[2]), rounds),
      base64Decode(parts[3]),
    );
  }

  static Future<List<int>> _derive(
    String pin,
    List<int> salt,
    int rounds,
  ) async {
    // Call the platform on the root isolate. Android runs its native KDF on a
    // background task queue; pure Dart is particularly slow in debug builds.
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('derive', {
        'pin': pin,
        'salt': Uint8List.fromList(salt),
        'iterations': rounds,
      });
      if (bytes == null || bytes.length != 32) {
        throw StateError('PIN derivation returned an invalid key.');
      }
      return bytes;
    } on MissingPluginException {
      // Other platforms and Android API 24/25 retain the compatible fallback.
      return Isolate.run(
        () async =>
            (await Pbkdf2(
                  macAlgorithm: Hmac.sha256(),
                  iterations: rounds,
                  bits: 256,
                ).deriveKey(
                  secretKey: SecretKey(utf8.encode(pin)),
                  nonce: salt,
                ))
                .extractBytes(),
      );
    }
  }

  static bool _equal(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
