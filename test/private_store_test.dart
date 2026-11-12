import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/app_lock/data/pin_hasher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test('legacy preference data migrates to authenticated ciphertext', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'private',
      jsonEncode({'text': 'my private diary', 'key': 'api-secret'}),
    );
    final store = PrivateStore(prefs);
    expect(await store.read('private'), contains('my private diary'));
    expect(prefs.getString('private'), isNot(contains('my private diary')));
    expect(prefs.getString('private'), isNot(contains('api-secret')));
    expect(await store.read('private'), contains('my private diary'));
    final envelope =
        jsonDecode(prefs.getString('private')!) as Map<String, dynamic>;
    envelope['mac'] = base64Encode(List.filled(16, 0));
    await prefs.setString('private', jsonEncode(envelope));
    await expectLater(store.read('private'), throwsA(anything));
  });
  test('PIN hashes use distinct salts and reject the wrong PIN', () async {
    const hasher = PinHasher(iterations: 1000);
    final a = await hasher.hash('123456');
    final b = await hasher.hash('123456');
    expect(a, isNot(b));
    expect(await hasher.verify('123456', a), isTrue);
    expect(await hasher.verify('123457', a), isFalse);
    expect(const PinHasher().iterations, 600000);
  });
}
