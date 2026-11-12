import 'dart:convert';
import 'package:ai_voice_docs/features/app_lock/data/pin_hasher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.aivoicedocs.app/pin_hash');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const salt = 'AAECAwQFBgcICQoLDA0ODw==';
  // Independently generated using .NET's PBKDF2-HMAC-SHA256 implementation.
  const key = 'k5IuOfF746yC7knkG2ibL4Jf/LmxjGRAY1DJK0+jxZw=';
  const stored = 'pbkdf2-sha256:600000:$salt:$key';

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'existing hashes use native derivation with their original parameters',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'derive');
        expect(call.arguments['pin'], '123456');
        expect(call.arguments['salt'], base64Decode(salt));
        expect(call.arguments['iterations'], 600000);
        return base64Decode(key);
      });
      expect(await const PinHasher().verify('123456', stored), isTrue);
      expect(
        await const PinHasher().verify(
          '123456',
          stored.replaceFirst(key, base64Encode(List.filled(32, 0))),
        ),
        isFalse,
      );
    },
  );

  test(
    'native errors fail closed instead of retrying a slow fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'derivation_failed');
      });
      await expectLater(
        const PinHasher().verify('123456', stored),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'unsupported platforms keep compatibility with independently generated hashes',
    () async {
      const fallbackStored =
          'pbkdf2-sha256:1000:$salt:bjhJERvo0wcGNCIGZuk8Vdv9dekj8001cWgFRkwKfq8=';
      expect(await const PinHasher().verify('123456', fallbackStored), isTrue);
      expect(await const PinHasher().verify('123457', fallbackStored), isFalse);
    },
  );
}
