import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/features/auth/presentation/providers/auth_providers.dart';
import 'package:ai_voice_docs/features/auth/presentation/screens/login_screen.dart';
import 'package:ai_voice_docs/features/history/presentation/screens/history_screen.dart';
import 'package:ai_voice_docs/features/settings/presentation/screens/language_picker_screen.dart';
import 'package:ai_voice_docs/features/settings/presentation/screens/settings_screen.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/screens/voice_to_text_screen.dart';
import 'package:ai_voice_docs/features/translation/presentation/screens/translator_screen.dart';
import 'package:ai_voice_docs/navigation/root_scaffold.dart';

const _authRoutes = {'/login'};

/// Notifies go_router's `redirect` to re-run whenever Firebase's sign-in
/// state changes, so a fresh sign-in/sign-out immediately routes the user
/// on/off the auth screens without any manual navigation call.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateChangesProvider).value != null;
      final onAuthRoute = _authRoutes.contains(state.matchedLocation);

      if (!isLoggedIn && !onAuthRoute) return '/login';
      if (isLoggedIn && onAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
