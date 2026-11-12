import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/app.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';

void main() {
  testWidgets(
    'public privacy policy is accessible before local profile setup',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const AiVoiceDocsApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Privacy policy'));
      await tester.pumpAndSettle();
      expect(find.text('What the app does'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Enter your PIN to continue'), findsNothing);
    },
  );
}
