import 'package:flutter/material.dart';

/// Thin wrapper so every feature raises snackbars the same way instead of
/// re-typing `ScaffoldMessenger.of(context)...` everywhere.
class AppSnackbar {
  const AppSnackbar._();

  static void show(BuildContext context, String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.errorContainer : scheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
