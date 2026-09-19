import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/providers/app_badge_providers.dart';
import 'package:ai_voice_docs/core/router/app_router.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

class AiVoiceDocsApp extends ConsumerWidget {
  const AiVoiceDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).value;
    final themeMode = settings?.themeMode ?? ThemeMode.system;
    final useDynamicColor = settings?.useDynamicColor ?? false;
    final seed = (settings?.palette ?? AppPalette.indigo).seed;

    // Side-effect only — keeps the launcher badge in sync for the app's
    // whole lifetime, not tied to whatever screen happens to be showing.
    ref.watch(appBadgeWatcherProvider);

    // Wait for the persisted app-lock account to load once before building
    // the router, so the redirect logic never has to guess and the user
    // never sees a flash of app content before being bounced to signup/PIN.
    final isCheckingAccount = ref.watch(appLockControllerProvider).isLoading;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = useDynamicColor ? lightDynamic : null;
        final darkScheme = useDynamicColor ? darkDynamic : null;

        if (isCheckingAccount) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(dynamicScheme: lightScheme, seed: seed),
            darkTheme: AppTheme.dark(dynamicScheme: darkScheme, seed: seed),
            themeMode: themeMode,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dynamicScheme: lightScheme, seed: seed),
          darkTheme: AppTheme.dark(dynamicScheme: darkScheme, seed: seed),
          themeMode: themeMode,
          // Required by the diary editor's rich-text toolbar (flutter_quill).
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          routerConfig: ref.watch(appRouterProvider),
        );
      },
    );
  }
}
