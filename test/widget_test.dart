import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/app.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_state.dart';

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
  testWidgets('App launches on the Home dashboard tab with bottom nav', (tester) async {
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
          appLockControllerProvider.overrideWith(_FakeUnlockedAppLockController.new),
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

    // 'Home' appears twice: the AppBar title and the bottom-nav label.
    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Tell me about your day'), findsOneWidget);
  });
}
