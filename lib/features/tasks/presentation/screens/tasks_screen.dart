import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';

import '../../data/task.dart';
import '../providers/task_providers.dart';

/// Session tag for the inline quick-add field's dictation — distinct from
/// every other screen's mic session so it never leaks state elsewhere.
const _quickAddSessionTag = 'tasks-quick-add';

enum _TaskFilter { today, upcoming, completed }

/// A simple checklist, its own tab rather than a card squeezed onto the
/// Voice screen — add a task, check it off, it stays until you clear it.
/// Deliberately date-less (see [Task]'s doc comment): a running list you
/// clear as you go, not tied to the Calendar. The Today/Upcoming split below
/// is purely a view over [Task.reminderAt] — a task with no reminder has no
/// "day" at all and always shows under Today, matching that same doc
/// comment's reasoning.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _quickAddController = TextEditingController();
  _TaskFilter _filter = _TaskFilter.today;

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskControllerProvider).value ?? const [];
    final pending = tasks.where((t) => !t.isDoneNow).toList();
    final completed = tasks.where((t) => t.isDoneNow).toList();
    final today = DateUtils.dateOnly(DateTime.now());
    final todayTasks = pending
        .where((t) => t.reminderAt == null || !DateUtils.dateOnly(t.reminderAt!).isAfter(today))
        .toList();
    final upcomingTasks = pending
        .where((t) => t.reminderAt != null && DateUtils.dateOnly(t.reminderAt!).isAfter(today))
        .toList();

    final quickAdd = ref.watch(speechControllerProvider(_quickAddSessionTag));
    if (quickAdd.isListening && _quickAddController.text != quickAdd.transcript) {
      _quickAddController.value = _quickAddController.value.copyWith(
        text: quickAdd.transcript,
        selection: TextSelection.collapsed(offset: quickAdd.transcript.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: const GradientAppBarUnderline(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTask(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'No tasks yet',
                  subtitle:
                      'Tap "Add task" to start a checklist you can clear as you go.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: SegmentedButton<_TaskFilter>(
                        segments: [
                          const ButtonSegment(value: _TaskFilter.today, label: Text('Today')),
                          const ButtonSegment(value: _TaskFilter.upcoming, label: Text('Upcoming')),
                          ButtonSegment(
                            value: _TaskFilter.completed,
                            label: Text('Completed (${completed.length})'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (value) => setState(() => _filter = value.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: TextField(
                        controller: _quickAddController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: quickAdd.isListening ? 'Listening…' : 'Add a task (or speak)',
                          prefixIcon: const Icon(Icons.add_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(quickAdd.isListening ? Icons.stop_circle_rounded : Icons.mic_none_rounded),
                            tooltip: quickAdd.isListening ? 'Stop' : 'Dictate',
                            onPressed: () => _toggleQuickAddListening(quickAdd.isListening),
                          ),
                        ),
                        onSubmitted: (_) => _submitQuickAdd(),
                      ),
                    ),
                    Expanded(
                      child: switch (_filter) {
                        _TaskFilter.today => _TaskList(tasks: todayTasks, emptyLabel: 'Nothing for today'),
                        _TaskFilter.upcoming =>
                          _TaskList(tasks: upcomingTasks, emptyLabel: 'No upcoming tasks'),
                        _TaskFilter.completed => Column(
                            children: [
                              if (completed.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          ref.read(taskControllerProvider.notifier).clearCompleted(),
                                      child: const Text('Clear completed'),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: _TaskList(tasks: completed, emptyLabel: 'Nothing completed yet'),
                              ),
                            ],
                          ),
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _toggleQuickAddListening(bool isListening) async {
    final controller = ref.read(speechControllerProvider(_quickAddSessionTag).notifier);
    if (isListening) {
      await controller.stopListening();
    } else {
      final language = ref.read(settingsControllerProvider).value?.sourceLanguageCode;
      await controller.startListening(languageByCode(language ?? AppConstants.defaultSourceLanguageCode).localeHint);
    }
  }

  Future<void> _submitQuickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) return;
    await ref.read(taskControllerProvider.notifier).addTask(text);
    _quickAddController.clear();
    ref.read(speechControllerProvider(_quickAddSessionTag).notifier).clearTranscript();
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var recurrence = TaskRecurrence.none;
    var reminderEnabled = false;
    DateTime? reminderAt;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What do you need to do?',
                  ),
                  onSubmitted: (value) => Navigator.pop(dialogContext, value),
                ),
                const SizedBox(height: 16),
                Text(
                  'Repeat',
                  style: Theme.of(dialogContext).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<TaskRecurrence>(
                  segments: const [
                    ButtonSegment(
                      value: TaskRecurrence.none,
                      label: Text('Once'),
                    ),
                    ButtonSegment(
                      value: TaskRecurrence.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: TaskRecurrence.weekly,
                      label: Text('Weekly'),
                    ),
                  ],
                  selected: {recurrence},
                  onSelectionChanged: (value) =>
                      setDialogState(() => recurrence = value.first),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remind me'),
                  subtitle: Text(
                    reminderEnabled && reminderAt != null
                        ? (recurrence == TaskRecurrence.none
                              ? DateFormat(
                                  'EEEE, MMM d, yyyy · h:mm a',
                                ).format(reminderAt!)
                              : recurrence == TaskRecurrence.daily
                              ? 'Every day at ${DateFormat('h:mm a').format(reminderAt!)}'
                              : 'Every ${DateFormat('EEEE').format(reminderAt!)} at ${DateFormat('h:mm a').format(reminderAt!)}')
                        : 'Get a notification for this task',
                  ),
                  value: reminderEnabled,
                  onChanged: (value) async {
                    if (!value) {
                      setDialogState(() {
                        reminderEnabled = false;
                        reminderAt = null;
                      });
                      return;
                    }
                    final granted = await ref
                        .read(notificationServiceProvider)
                        .requestPermission();
                    if (!dialogContext.mounted) return;
                    if (!granted) {
                      AppSnackbar.show(
                        dialogContext,
                        'Allow notifications to get reminders',
                        isError: true,
                      );
                      return;
                    }
                    setDialogState(() {
                      reminderEnabled = true;
                      reminderAt ??= DateTime.now().add(
                        const Duration(hours: 1),
                      );
                    });
                  },
                ),
                if (reminderEnabled)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickReminderTime(
                        dialogContext,
                        reminderAt,
                      );
                      if (picked != null) {
                        setDialogState(() => reminderAt = picked);
                      }
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Set reminder time'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final trimmed = result?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await ref
          .read(taskControllerProvider.notifier)
          .addTask(
            trimmed,
            recurrence: recurrence,
            reminderAt: reminderEnabled ? reminderAt : null,
          );
    }
  }
}

Future<DateTime?> _pickReminderTime(
  BuildContext context,
  DateTime? current,
) async {
  final now = DateTime.now();
  final initial = current ?? now.add(const Duration(hours: 1));
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: now,
    lastDate: DateTime(now.year + 10),
  );
  if (pickedDate == null || !context.mounted) return null;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (!context.mounted) return null;

  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime?.hour ?? initial.hour,
    pickedTime?.minute ?? initial.minute,
  );
}

/// One tab's list — a shared shape for Today/Upcoming/Completed so each tab
/// doesn't need to repeat the empty-state/list boilerplate.
class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.emptyLabel});

  final List<Task> tasks;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [for (final task in tasks) _TaskRow(task: task)],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.isDoneNow;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(taskControllerProvider.notifier).removeTask(task.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: () => _editReminder(context, ref, task),
          leading: Checkbox(
            value: done,
            onChanged: (value) => ref
                .read(taskControllerProvider.notifier)
                .setDone(task.id, value ?? false),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          subtitle: task.reminderAt != null
              ? Text(
                  task.recurrence == TaskRecurrence.daily
                      ? 'Every day at ${DateFormat('h:mm a').format(task.reminderAt!)}'
                      : task.recurrence == TaskRecurrence.weekly
                      ? 'Every ${DateFormat('EEEE, h:mm a').format(task.reminderAt!)}'
                      : DateFormat('MMM d, h:mm a').format(task.reminderAt!),
                  style: TextStyle(fontSize: 12, color: scheme.primary),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.reminderAt != null)
                Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
              if (task.recurrence != TaskRecurrence.none) ...[
                const SizedBox(width: 4),
                Icon(
                  task.recurrence == TaskRecurrence.daily
                      ? Icons.repeat_rounded
                      : Icons.event_repeat_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editReminder(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(
                task.reminderAt == null ? 'Set reminder' : 'Change reminder',
              ),
              onTap: () => Navigator.pop(sheetContext, 'set'),
            ),
            if (task.reminderAt != null)
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Remove reminder'),
                onTap: () => Navigator.pop(sheetContext, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'clear') {
      await ref
          .read(taskControllerProvider.notifier)
          .setReminder(task.id, null);
      return;
    }

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      AppSnackbar.show(
        context,
        'Allow notifications to get reminders',
        isError: true,
      );
      return;
    }
    final picked = await _pickReminderTime(context, task.reminderAt);
    if (picked == null) return;
    await ref
        .read(taskControllerProvider.notifier)
        .setReminder(task.id, picked);
  }
}
