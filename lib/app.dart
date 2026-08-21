import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/router/app_router.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

class AiVoiceDocsApp extends ConsumerWidget {
  const AiVoiceDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.system;

    // Wait for the persisted app-lock account to load once before building
    // the router, so the redirect logic never has to guess and the user
    // never sees a flash of app content before being bounced to signup/PIN.
    final isCheckingAccount = ref.watch(appLockControllerProvider).isLoading;
    if (isCheckingAccount) {
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
