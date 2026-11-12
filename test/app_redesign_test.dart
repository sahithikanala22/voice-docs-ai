import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/app.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_state.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

class _Unlocked extends AppLockController {
  @override
  Future<AppLockState> build() async => const AppLockState(
    account: AppLockAccount(name: 'Test', pinHash: 'test-only'),
    isUnlocked: true,
  );
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['VOICE_DOCS_PREVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/icon/icon.png'),
      tester.element(find.byKey(const ValueKey('preview'))),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget/updates'),
          (_) async => null,
        );
    if (Platform.environment['VOICE_DOCS_PREVIEW_DIR'] != null) {
      await tester.runAsync(() async {
        final fonts =
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
        for (final font in {
          'Roboto': '$fonts/roboto-regular.ttf',
          'Ahem': '$fonts/roboto-regular.ttf',
          'serif': 'C:/Windows/Fonts/georgia.ttf',
          'MaterialIcons': '$fonts/materialicons-regular.otf',
        }.entries) {
          final loader = FontLoader(font.key);
          loader.addFont(
            File(
              font.value,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
          await loader.load();
        }
      });
    }
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockControllerProvider.overrideWith(_Unlocked.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('preview'),
          child: AiVoiceDocsApp(),
        ),
      ),
    );
    await frames(tester);
    return container;
  }

  testWidgets(
    'five sections, diary save, task capture, calendar and appearance remain usable',
    (tester) async {
      final container = await launch(tester);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
      for (final label in ['Voice', 'Diary', 'Calendar', 'Tasks', 'History']) {
        expect(
          find.widgetWithText(NavigationDestination, label),
          findsOneWidget,
        );
      }
      expect(find.text('Tap to record'), findsOneWidget);
      await capture(tester, 'app-voice-dark');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Diary'));
      await frames(tester);
      expect(find.text('Write entry'), findsOneWidget);
      await tester.tap(find.text('Write entry'));
      await frames(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Monday reflections',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'A quiet walk and a finished project.',
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Calm'));
      await frames(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Calm'));
      await frames(tester);
      await capture(tester, 'app-diary-editor-dark');
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(find.text('Write entry'), findsOneWidget);
      expect(
        container.read(diaryControllerProvider).requireValue.single.title,
        'Monday reflections',
      );
      expect(
        container.read(diaryControllerProvider).requireValue.single.mood?.name,
        'calm',
      );
      expect(find.text('Monday reflections'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await capture(tester, 'app-diary-dark');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
      await frames(tester);
      expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);
      await capture(tester, 'app-calendar-dark');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Tasks'));
      await frames(tester);
      expect(find.text('Your first task starts here'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Call home');
      await tester.tap(find.byTooltip('Add this task'));
      await frames(tester);
      expect(
        container.read(taskControllerProvider).requireValue.single.title,
        'Call home',
      );
      await capture(tester, 'app-tasks-dark');

      await container
          .read(historyControllerProvider.notifier)
          .addEntry(
            HistoryItem.voice(
              text: 'A productive morning. I finished my project.',
              languageCode: 'en',
            ),
          );
      await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
      await frames(tester);
      expect(find.text('A productive morning.'), findsOneWidget);
      await capture(tester, 'app-history-dark');

      await tester.tap(find.byTooltip('Settings'));
      await frames(tester);
      await tester.scrollUntilVisible(
        find.text('Choose your appearance'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Light'));
      await frames(tester);
      await tester.tap(find.text('Light'));
      await frames(tester);
      expect(
        container.read(settingsControllerProvider).requireValue.themeMode,
        ThemeMode.light,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
        Brightness.light,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Choose your appearance')),
        alignment: .1,
      );
      await frames(tester);
      await capture(tester, 'app-appearance-light');
      await tester.pageBack();
      await frames(tester);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Voice'));
      await frames(tester);
      await capture(tester, 'app-voice-light');
      await tester.tap(find.widgetWithText(NavigationDestination, 'Diary'));
      await frames(tester);
      await capture(tester, 'app-diary-light');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'diary and recording work on a narrow display with enlarged text',
    (tester) async {
      await launch(tester, size: const Size(320, 700));
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Diary'));
      await frames(tester);
      expect(find.text('Dictate'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Write entry'));
      await frames(tester);
      expect(find.text('Photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
