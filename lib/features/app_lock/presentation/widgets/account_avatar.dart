import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

import '../providers/app_lock_providers.dart';

/// A circular profile picture, keyed by its stored file name — same
/// resolve-directory-once pattern as `DiaryPhoto`. Falls back to a
/// gradient initial (or a bare person icon for an empty name) when there's
/// no picture, or its file is missing (e.g. a backup restored on a new
/// phone, which carries the account but not the image).
class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({super.key, required this.avatarPath, required this.name, required this.radius});

  final String? avatarPath;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = avatarPath;
    final dir = path == null ? null : ref.watch(avatarDirProvider).value;

    if (path != null && dir != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File('$dir/$path')),
        onBackgroundImageError: (_, _) {},
      );
    }

    final initial = name.trim().isEmpty ? null : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.rainbowGradient()),
        child: Center(
          child: initial == null
              ? Icon(Icons.person_rounded, size: radius, color: Colors.white)
              : Text(
                  initial,
                  style: TextStyle(
                    fontSize: radius,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
