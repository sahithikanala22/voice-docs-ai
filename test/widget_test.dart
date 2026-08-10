import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/app.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/features/auth/domain/auth_repository.dart';
import 'package:ai_voice_docs/features/auth/presentation/providers/auth_providers.dart';

/// Stands in for [FirebaseAuthRepository] so widget tests never touch the
/// real Firebase SDK (which isn't initialized in the test environment and
/// has no project configured here). Reports an already-signed-in user so
/// the router lands past the login screen.
class _FakeSignedInAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> authStateChanges() =>
      Stream.value(const AppUser(uid: 'test-uid', phoneNumber: '+15555550100'));

  @override
  AppUser? get currentUser => const AppUser(uid: 'test-uid', phoneNumber: '+15555550100');

  @override
  Future<void> sendOtp(String phoneNumber) async {}

  @override
  Future<void> verifyOtp({required String phoneNumber, required String code}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('App launches on the voice-to-text home tab with bottom nav', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(_FakeSignedInAuthRepository()),
        ],
        child: const AiVoiceDocsApp(),
      ),
    );
    // AnimatedMicButton runs a continuously repeating AnimationController, so
    // pumpAndSettle would never terminate — pump a few discrete frames
    // instead to let the async settings load resolve.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Voice to Text'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Tap the mic to start speaking'), findsOneWidget);
  });
}
