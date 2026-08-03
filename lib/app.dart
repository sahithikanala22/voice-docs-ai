import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voxi_translate/core/constants/app_constants.dart';
import 'package:voxi_translate/core/router/app_router.dart';
import 'package:voxi_translate/core/theme/app_theme.dart';
import 'package:voxi_translate/features/settings/presentation/providers/settings_providers.dart';

class VoxiTranslateApp extends ConsumerWidget {
  const VoxiTranslateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.system;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
