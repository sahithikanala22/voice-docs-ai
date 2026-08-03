import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voxi_translate/core/constants/app_constants.dart';
import 'package:voxi_translate/features/history/presentation/screens/history_screen.dart';
import 'package:voxi_translate/features/settings/presentation/screens/language_picker_screen.dart';
import 'package:voxi_translate/features/settings/presentation/screens/settings_screen.dart';
import 'package:voxi_translate/features/speech_to_text/presentation/screens/voice_to_text_screen.dart';
import 'package:voxi_translate/features/translation/presentation/screens/translator_screen.dart';
import 'package:voxi_translate/navigation/root_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RootScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const VoiceToTextScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/translator', builder: (context, state) => const TranslatorScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/language-picker',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return LanguagePickerScreen(
            title: extra['title'] as String? ?? 'Choose a language',
            selectedCode: extra['selectedCode'] as String? ?? AppConstants.defaultSourceLanguageCode,
          );
        },
      ),
    ],
  );
});
