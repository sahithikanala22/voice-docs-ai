import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

/// New entry / Add task / Quick note / Take photo — one tap to whichever
/// capture flow you want, without hunting through tabs first.
class HomeQuickActionsRow extends StatelessWidget {
  const HomeQuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.auto_stories_outlined,
            label: 'New entry',
            onTap: () => context.push('/diary-entry/new'),
          ),
        ),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_task_rounded,
            label: 'Add task',
            onTap: () => _quickAddTask(context),
          ),
        ),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.mic_none_rounded,
            label: 'Quick note',
            onTap: () => context.push('/voice'),
          ),
        ),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Take photo',
            onTap: () => context.push('/diary-entry/new'),
          ),
        ),
      ],
    );
  }

  Future<void> _quickAddTask(BuildContext context) async {
    final controller = TextEditingController();
    // Grabbed before the `await` below so using it afterward isn't a
    // BuildContext-across-an-async-gap use.
    final container = ProviderScope.containerOf(context);

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What do you need to do?'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await container.read(taskControllerProvider.notifier).addTask(trimmed);
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
