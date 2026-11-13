import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/recording_playback_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

/// Four destinations, with recording and the calendar one tap from Today.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  StreamSubscription<Uri?>? _widgetClicks;
  @override
  void initState() {
    super.initState();
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleWidget)
        .catchError((Object _) {});
    _widgetClicks = HomeWidget.widgetClicked.listen(
      _handleWidget,
      onError: (Object _) {},
    );
  }

  void _handleWidget(Uri? uri) {
    if (!mounted ||
        uri?.host != 'record' ||
        ref.read(appLockControllerProvider).value?.isUnlocked != true) {
      return;
    }
    if (GoRouter.of(context).routeInformationProvider.value.uri.path ==
        '/record') {
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null) {
        ref
            .read(speechControllerProvider('home').notifier)
            .startListening(
              languageByCode(settings.sourceLanguageCode).localeHint,
              languageCode: settings.sourceLanguageCode,
              folderId: settings.currentFolderId,
              timestamp: DateTime.now(),
            );
      }
      return;
    }
    context.push('/record', extra: true);
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: widget.navigationShell,
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
        selectedIndex: widget.navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) async {
          await ref
              .read(recordingCoordinatorProvider)
              .stop(cancelTranscription: true);
          if (ref.exists(recordingPlaybackProvider)) {
            await ref.read(recordingPlaybackProvider).stop();
          }
          if (!context.mounted) return;
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks_rounded),
            label: 'Library',
          ),
        ],
      ),
    ),
  );
}
