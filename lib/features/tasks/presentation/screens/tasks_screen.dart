import 'package:ai_voice_docs/core/widgets/dictation_field.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/core/widgets/brand_widgets.dart';
import '../../data/task.dart';
import '../providers/task_providers.dart';

enum _TaskFilter { today, upcoming, completed }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _quickAdd = TextEditingController();
  _TaskFilter _filter = _TaskFilter.today;
  bool _addingQuick = false;
  @override
  void dispose() {
    _quickAdd.dispose();
    super.dispose();
  }

  Future<void> _submitQuickAdd() async {
    if (_addingQuick) return;
    setState(() => _addingQuick = true);
    try {
      await ref.read(recordingCoordinatorProvider).stop(tag: 'tasks-quick-add');
      if (!mounted) return;
      final text = _quickAdd.text.trim();
      if (text.isEmpty) return;
      await ref.read(taskControllerProvider.notifier).addTask(text);
      if (!mounted) return;
      _quickAdd.clear();
      ref
          .read(speechControllerProvider('tasks-quick-add').notifier)
          .clearTranscript();
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not add this task. Try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _addingQuick = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskControllerProvider);
    final tasks = taskAsync.value ?? const <Task>[];
    final today = DateUtils.dateOnly(DateTime.now());
    final visible = tasks
        .where(
          (task) => switch (_filter) {
            _TaskFilter.completed => task.isDoneNow,
            _TaskFilter.today =>
              !task.isDoneNow &&
                  (task.reminderAt == null ||
                      !DateUtils.dateOnly(task.reminderAt!).isAfter(today)),
            _TaskFilter.upcoming =>
              !task.isDoneNow &&
                  task.reminderAt != null &&
                  DateUtils.dateOnly(task.reminderAt!).isAfter(today),
          },
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: const [SettingsAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks-add',
        onPressed: () => _addTask(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageIntroduction(
                      title: 'Your daily checklist',
                      subtitle: DateFormat(
                        'EEEE, d MMMM',
                      ).format(DateTime.now()),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_TaskFilter>(
                        segments: const [
                          ButtonSegment(
                            value: _TaskFilter.today,
                            label: Text('Today'),
                          ),
                          ButtonSegment(
                            value: _TaskFilter.upcoming,
                            label: Text('Upcoming'),
                          ),
                          ButtonSegment(
                            value: _TaskFilter.completed,
                            label: Text('Completed'),
                          ),
                        ],
                        showSelectedIcon: false,
                        selected: {_filter},
                        onSelectionChanged: (v) =>
                            setState(() => _filter = v.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DictationField(
                            controller: _quickAdd,
                            sessionTag: 'tasks-quick-add',
                            localeHint: languageByCode(
                              ref
                                      .watch(settingsControllerProvider)
                                      .value
                                      ?.sourceLanguageCode ??
                                  'en',
                            ).localeHint,
                            hint: 'Add a task',
                            minLines: 1,
                            maxLines: 2,
                            showPrivacyDescription: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Add this task',
                          onPressed: _addingQuick ? null : _submitQuickAdd,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_filter == _TaskFilter.completed &&
                        visible.any((t) => t.recurrence == TaskRecurrence.none))
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => ref
                              .read(taskControllerProvider.notifier)
                              .clearCompleted(),
                          child: const Text('Clear completed'),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: taskAsync.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : taskAsync.hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Your tasks could not be opened.'),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(taskControllerProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.checklist_rounded,
                        title: tasks.isEmpty
                            ? 'Your first task starts here'
                            : switch (_filter) {
                                _TaskFilter.today => 'Nothing for today',
                                _TaskFilter.upcoming => 'No upcoming tasks',
                                _TaskFilter.completed => 'No completed tasks',
                              },
                        subtitle:
                            'Type or dictate a task above, or tap Add task.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                        children: [
                          for (final task in visible) _TaskRow(task: task),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var recurrence = TaskRecurrence.none;
    var adding = false;
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
                DictationField(
                  controller: controller,
                  sessionTag: 'tasks-add',
                  localeHint: languageByCode(
                    ref
                            .read(settingsControllerProvider)
                            .value
                            ?.sourceLanguageCode ??
                        'en',
                  ).localeHint,
                  hint: 'What do you need to do?',
                  autofocus: true,
                  disposeController: true,
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
              onPressed: () async {
                if (adding) return;
                adding = true;
                await ref
                    .read(recordingCoordinatorProvider)
                    .stop(tag: 'tasks-add');
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, controller.text);
                }
              },
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
