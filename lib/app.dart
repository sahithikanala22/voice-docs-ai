import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/router/app_router.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/features/auth/presentation/providers/auth_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

class AiVoiceDocsApp extends ConsumerWidget {
  const AiVoiceDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.system;

    // Wait for Firebase's first authStateChanges event (it reports whatever
    // session was already persisted on-device) before building the router,
    // so the redirect logic never has to guess and the user never sees a
    // flash of app content before being bounced to /login.
    final isCheckingAuth = ref.watch(authStateChangesProvider).isLoading;
    if (isCheckingAuth) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
