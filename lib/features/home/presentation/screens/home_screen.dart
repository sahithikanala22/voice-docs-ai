import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';

import '../widgets/greeting_header.dart';
import '../widgets/home_quick_actions_row.dart';
import '../widgets/quote_of_the_day_card.dart';
import '../widgets/todays_tasks_preview_card.dart';

/// The app's landing tab — a greeting, a daily quote, a big call-to-action
/// into voice capture, quick actions for the other entry points, and a
/// glance at today's tasks. Replaces Voice as tab 0; the voice recorder
/// itself lives at the pushed `/voice` route now, opened from here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = ref.watch(appLockControllerProvider).value?.account?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        bottom: const GradientAppBarUnderline(),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              GreetingHeader(name: name),
              const SizedBox(height: 16),
              const QuoteOfTheDayCard(),
              const SizedBox(height: 16),
              _TellMeAboutYourDayCard(scheme: scheme),
              const SizedBox(height: 20),
              const HomeQuickActionsRow(),
              const SizedBox(height: 20),
              const TodaysTasksPreviewCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TellMeAboutYourDayCard extends StatelessWidget {
  const _TellMeAboutYourDayCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/voice'),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient(scheme),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell me about your day',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to speak or start writing',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
