import 'dart:async';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_state.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/screens/pin_entry_screen.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CheckingLock extends AppLockController {
  final result = Completer<bool>();
  var calls = 0;
  @override
  Future<AppLockState> build() async => const AppLockState(
    account: AppLockAccount(name: 'Test', pinHash: 'test'),
  );
  @override
  Future<bool> unlock(String pin) {
    calls++;
    return result.future;
  }
}

class _Settings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

void main() {
  testWidgets(
    'PIN submission shows progress, prevents repeats, and recovers on error',
    (tester) async {
      final lock = _CheckingLock();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockControllerProvider.overrideWith(() => lock),
            settingsControllerProvider.overrideWith(_Settings.new),
          ],
          child: const MaterialApp(home: PinEntryScreen()),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      expect(find.text('Unlocking…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(lock.calls, 1);
      lock.result.completeError(StateError('Storage unavailable'));
      await tester.pump();
      expect(
        find.text('Could not verify your PIN. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Unlocking…'), findsNothing);
    },
  );
}
