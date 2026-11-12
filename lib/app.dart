import 'package:ai_voice_docs/core/widgets/app_session_guard.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
    final settings = ref.watch(settingsControllerProvider).value;
    final themeMode = settings?.themeMode ?? ThemeMode.dark;
    final useDynamicColor = settings?.useDynamicColor ?? false;
    final accentColor = settings?.accentColorValue == null
        ? null
        : Color(settings!.accentColorValue!);
    final fontFamily = settings?.fontFamily;

    // Wait for the persisted app-lock account to load once before building
    // the router, so the redirect logic never has to guess and the user
    // never sees a flash of app content before being bounced to signup/PIN.
    final lockAsync = ref.watch(appLockControllerProvider);
    final isCheckingAccount = lockAsync.isLoading;

    return AppSessionGuard(
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final lightScheme = useDynamicColor ? lightDynamic : null;
          final darkScheme = useDynamicColor ? darkDynamic : null;

          if (lockAsync.hasError) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Protected data could not be opened. Your app remains locked.',
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(appLockControllerProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (isCheckingAccount) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(
                dynamicScheme: lightScheme,
                seedColor: accentColor,
                fontFamily: fontFamily,
              ),
              darkTheme: AppTheme.dark(
                dynamicScheme: darkScheme,
                seedColor: accentColor,
                fontFamily: fontFamily,
              ),
              themeMode: themeMode,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              dynamicScheme: lightScheme,
              seedColor: accentColor,
              fontFamily: fontFamily,
            ),
            darkTheme: AppTheme.dark(
              dynamicScheme: darkScheme,
              seedColor: accentColor,
              fontFamily: fontFamily,
            ),
            themeMode: themeMode,
            routerConfig: ref.watch(appRouterProvider),
          );
        },
      ),
    );
  }
}
