// Run on Android with: flutter run -d <device> -t scripts/benchmark_pin.dart
// Uses only a public test PIN/vector and never reads account data.
import 'dart:convert';
import 'package:ai_voice_docs/features/app_lock/data/pin_hasher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Measuring PIN verification…'))),
    ),
  );
  const salt = 'AAECAwQFBgcICQoLDA0ODw==';
  const key = 'k5IuOfF746yC7knkG2ibL4Jf/LmxjGRAY1DJK0+jxZw=';
  const stored = 'pbkdf2-sha256:600000:$salt:$key';
  final timer = Stopwatch()..start();
  final native = await const MethodChannel('com.aivoicedocs.app/pin_hash')
      .invokeMethod<Uint8List>('derive', {
        'pin': '123456',
        'salt': base64Decode(salt),
        'iterations': 600000,
      });
  final nativeMs = timer.elapsedMilliseconds;
  if (native == null ||
      base64Encode(native) != key ||
      !await const PinHasher().verify('123456', stored) ||
      await const PinHasher().verify('123457', stored)) {
    throw StateError('Native PIN verification failed its known-answer check.');
  }
  debugPrint(
    'PIN_BENCHMARK native_ms=$nativeMs known_answer=PASS correct_and_wrong_pin=PASS',
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'PIN verification checked\nNative: $nativeMs ms\nExisting hash compatibility: PASS',
          ),
        ),
      ),
    ),
  );
}
