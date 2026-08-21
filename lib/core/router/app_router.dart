import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/screens/pin_entry_screen.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/screens/profile_screen.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/screens/signup_screen.dart';
import 'package:ai_voice_docs/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:ai_voice_docs/features/history/presentation/screens/history_screen.dart';
import 'package:ai_voice_docs/features/settings/presentation/screens/language_picker_screen.dart';
import 'package:ai_voice_docs/features/settings/presentation/screens/settings_screen.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/screens/voice_to_text_screen.dart';
import 'package:ai_voice_docs/navigation/root_scaffold.dart';

const _lockRoutes = {'/signup', '/pin'};

/// Notifies go_router's `redirect` to re-run whenever the app-lock state
/// changes (account created, unlocked, or reset), so signup/unlock/reset
/// immediately routes the user on/off the lock screens with no manual
/// navigation call.
class _AppLockRefreshNotifier extends ChangeNotifier {
  _AppLockRefreshNotifier(Ref ref) {
    ref.listen(appLockControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AppLockRefreshNotifier(ref),
    redirect: (context, state) {
      final lockState = ref.read(appLockControllerProvider).value;
      final onLockRoute = _lockRoutes.contains(state.matchedLocation);

      // Still loading the persisted account for the first time — app.dart's
      // own loading gate covers this, so just don't redirect yet.
      if (lockState == null) return null;

      final needsSignup = lockState.account == null;
      final needsPin = !needsSignup && !lockState.isUnlocked;

      if (needsSignup && state.matchedLocation != '/signup') return '/signup';
      if (needsPin && state.matchedLocation != '/pin') return '/pin';
      if (!needsSignup && !needsPin && onLockRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/pin', builder: (context, state) => const PinEntryScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RootScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const VoiceToTextScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
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
