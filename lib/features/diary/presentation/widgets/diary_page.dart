import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import '../../data/diary_entry.dart';

ThemeData diaryTheme(BuildContext context, DiaryPageStyle style) =>
    switch (style) {
      DiaryPageStyle.system => Theme.of(context),
      DiaryPageStyle.warm => AppTheme.light(seedColor: const Color(0xFF785A39)),
      DiaryPageStyle.midnight => AppTheme.dark(),
    };

class DiaryPhoto extends StatelessWidget {
  const DiaryPhoto({super.key, required this.path, this.height = 150});
  final String path;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 900,
      errorBuilder: (_, _, _) => SizedBox(
        height: height,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    ),
  );
}

class MoodLabel extends StatelessWidget {
  const MoodLabel({super.key, required this.mood});
  final DiaryMood mood;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diaryMoodIcon(mood),
            size: 14,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            mood.label,
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

IconData diaryMoodIcon(DiaryMood mood) => switch (mood) {
  DiaryMood.happy => Icons.sentiment_satisfied_alt_rounded,
  DiaryMood.calm => Icons.spa_outlined,
  DiaryMood.neutral => Icons.sentiment_neutral_rounded,
  DiaryMood.sad => Icons.sentiment_dissatisfied_rounded,
  DiaryMood.tired => Icons.bedtime_outlined,
};
