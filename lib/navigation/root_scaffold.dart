import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';

/// Five first-class destinations; settings is reached from the profile action.
class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .65),
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) async {
          await ref
              .read(recordingCoordinatorProvider)
              .stop(cancelTranscription: true);
          if (!context.mounted) return;
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Voice',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    ),
  );
}
