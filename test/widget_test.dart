import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/app.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_state.dart';
import 'package:ai_voice_docs/features/library/presentation/providers/library_providers.dart';

/// Stands in for [AppLockController] so widget tests skip signup/PIN entry
/// entirely and land straight on the app's home tab.
class _FakeUnlockedAppLockController extends AppLockController {
  @override
  Future<AppLockState> build() async {
    return const AppLockState(
      account: AppLockAccount(name: 'Test', pinHash: 'unused-in-tests'),
      isUnlocked: true,
    );
  }
}

void main() {
  testWidgets('App launches on Today with the four primary destinations', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // The default test surface is 800x600 (landscape-shaped), which starves
    // this portrait phone layout of vertical space and reports overflow that
    // would never happen on an actual phone. Use a realistic portrait size.
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockControllerProvider.overrideWith(
            _FakeUnlockedAppLockController.new,
          ),
          savedRecordingsProvider.overrideWith((ref) async => []),
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

    // "Today" also appears on the new date-selector chip, so target the
    // app bar's title specifically rather than asserting there's only one.
    expect(find.widgetWithText(AppBar, 'Voice Docs AI'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(
      find.widgetWithText(NavigationDestination, 'Journal'),
      findsOneWidget,
    );
    expect(find.text('Record a note'), findsOneWidget);
  });
  testWidgets('unreadable protected account fails closed', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'voxi.app_lock_account.v1': '{"encrypted":1,"nonce":"invalid"}',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const AiVoiceDocsApp(),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('Protected data could not be opened. Your app remains locked.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppBar, 'Voice Docs AI'), findsNothing);
  });
}
