import 'package:ai_voice_docs/core/widgets/dictation_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/folder_selector_chip.dart';
import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';

import '../../data/history_item.dart';
import '../../domain/entry_template.dart';
import '../providers/history_providers.dart';

/// Bottom sheet that fills in one [EntryTemplate]'s prompts — each answered
/// separately (voice or text) — and saves the combined result as a single
/// history entry, same shape as a normal recording.
Future<void> showTemplatedEntrySheet(
  BuildContext context, {
  required EntryTemplate template,
  required DateTime date,
  String? folderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TemplatedEntrySheet(
      template: template,
      date: date,
      folderId: folderId,
    ),
  );
}

class _TemplatedEntrySheet extends ConsumerStatefulWidget {
  const _TemplatedEntrySheet({
    required this.template,
    required this.date,
    this.folderId,
  });

  final EntryTemplate template;
  final DateTime date;
  final String? folderId;

  @override
  ConsumerState<_TemplatedEntrySheet> createState() =>
      _TemplatedEntrySheetState();
}

class _TemplatedEntrySheetState extends ConsumerState<_TemplatedEntrySheet> {
  late final List<TextEditingController> _controllers;
  late Language _language;
  String? _folderId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.template.prompts.length,
      (_) => TextEditingController(),
    );
    _language = languageByCode(AppConstants.defaultSourceLanguageCode);
    _folderId = widget.folderId;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _sessionTag(int index) => 'template-prompt-$index';

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderControllerProvider);
    final folderName = folderNameFor(foldersAsync.value, _folderId);
    final templateIndex = builtInTemplates.indexOf(widget.template);
    final color = AppTheme.brandRays[templateIndex % AppTheme.brandRays.length];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.template.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.template.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Answer as many prompts as you like — the rest are skipped.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                LanguageSelectorChip(language: _language, onTap: _pickLanguage),
                FolderSelectorChip(folderName: folderName, onTap: _pickFolder),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.template.prompts.length; i++) ...[
              _PromptField(
                prompt: widget.template.prompts[i],
                controller: _controllers[i],
                sessionTag: _sessionTag(i),
                localeHint: _language.localeHint,
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(onPressed: _submit, child: const Text('Save entry')),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final picked = await context.push<Language>(
      '/language-picker',
      extra: {'title': 'Speech language', 'selectedCode': _language.code},
    );
    if (picked != null) {
      setState(() => _language = picked);
    }
  }

  Future<void> _pickFolder() async {
    final result = await showFolderPicker(context, selectedFolderId: _folderId);
    if (result == null) return;
    setState(() => _folderId = result.isEmpty ? null : result);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    try {
      await ref.read(recordingCoordinatorProvider).stop();
      if (!mounted) return;
      final buffer = StringBuffer();
      for (var i = 0; i < widget.template.prompts.length; i++) {
        final answer = _controllers[i].text.trim();
        if (answer.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write('${widget.template.prompts[i]}\n$answer');
      }
      final combined = buffer.toString();
      if (combined.isEmpty) {
        AppSnackbar.show(
          context,
          'Answer at least one prompt to save.',
          isError: true,
        );
        return;
      }

      final item = HistoryItem.voice(
        text: combined,
        languageCode: _language.code,
        folderId: _folderId,
        timestamp: widget.date,
      );
      await ref.read(historyControllerProvider.notifier).addEntry(item);
      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.show(context, '${widget.template.name} entry saved');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'The entry could not be saved. Your draft has been kept.',
          isError: true,
        );
      }
    } finally {
      _submitting = false;
    }
  }
}

/// One prompt's answer field — its own dictation session (via [sessionTag])
/// so starting/stopping the mic on one prompt never touches another's text.
class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.prompt,
    required this.controller,
    required this.sessionTag,
    required this.localeHint,
  });
  final String prompt;
  final TextEditingController controller;
  final String sessionTag;
  final String localeHint;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(prompt, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      DictationField(
        controller: controller,
        sessionTag: sessionTag,
        localeHint: localeHint,
        hint: 'Type or speak your answer',
        minLines: 2,
      ),
    ],
  );
}
