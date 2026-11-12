import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import '../../data/diary_entry.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_page.dart';

class DiaryEditorScreen extends ConsumerStatefulWidget {
  const DiaryEditorScreen({
    super.key,
    this.entryId,
    this.initialDate,
    this.startDictation = false,
  });
  final String? entryId;
  final DateTime? initialDate;
  final bool startDictation;
  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  static const _tag = 'diary-editor';
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _photos = <String>[];
  final _addedPhotos = <String>{};
  late final DiaryPhotoStore _photoStore;
  late final Future<void> Function() _stopDictation;
  late DateTime _date;
  DiaryEntry? _original;
  DiaryMood? _mood;
  DiaryPageStyle _style = DiaryPageStyle.system;
  String _initial = '';
  String _dictationPrefix = '';
  bool _loading = false;
  bool _saving = false;
  bool _picking = false;
  bool _allowPop = false;

  String get _snapshot => jsonEncode([
    _title.text,
    _body.text,
    _date.toIso8601String(),
    _mood?.name,
    _style.name,
    _photos,
  ]);
  bool get _dirty => _snapshot != _initial;
  bool get _blank =>
      _title.text.trim().isEmpty &&
      _body.text.trim().isEmpty &&
      _photos.isEmpty;

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    _photoStore = ref.read(diaryPhotoStoreProvider);
    final coordinator = ref.read(recordingCoordinatorProvider);
    _stopDictation = () => coordinator.stop(tag: _tag);
    _initial = _snapshot;
    _title.addListener(_changed);
    _body.addListener(_changed);
    _loading = widget.entryId != null;
    if (_loading) {
      _load();
    } else if (widget.startDictation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleDictation();
      });
    }
  }

  Future<void> _load() async {
    try {
      final entries = await ref.read(diaryControllerProvider.future);
      if (!mounted) return;
      final entry = entries.where((e) => e.id == widget.entryId).firstOrNull;
      if (entry == null) throw const FormatException('Entry not found');
      _original = entry;
      _date = entry.date;
      _mood = entry.mood;
      _style = entry.pageStyle;
      _title.text = entry.title;
      _body.text = entry.body;
      _photos.addAll(entry.photos);
      _initial = _snapshot;
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _allowPop = true;
        });
        AppSnackbar.show(
          context,
          'This diary entry could not be opened.',
          isError: true,
        );
        context.pop();
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_stopDictation());
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recognition = ref.watch(speechControllerProvider(_tag));
    ref.listen(speechControllerProvider(_tag), (previous, next) {
      if (next.transcript != previous?.transcript) {
        final text = _dictationPrefix + next.transcript;
        _body.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });
    final active = recognition.isListening || recognition.isProcessing;
    return Theme(
      data: diaryTheme(context, _style),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return PopScope(
            canPop: _allowPop || (!_dirty && !active),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _leave();
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Close editor',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _leave,
                ),
                title: Text(
                  _original == null ? 'New diary entry' : 'Edit diary entry',
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton(
                      onPressed: _saving || _loading || (_blank && !active)
                          ? null
                          : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(22),
                              children: [
                                InkWell(
                                  onTap: active ? null : _pickDate,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          DateFormat('d').format(_date),
                                          style: Theme.of(context)
                                              .textTheme
                                              .displaySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            DateFormat(
                                              'EEEE · MMMM yyyy',
                                            ).format(_date),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        const Icon(Icons.expand_more_rounded),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 28),
                                Text(
                                  'How are you feeling?',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final mood in DiaryMood.values)
                                      ChoiceChip(
                                        avatar: Icon(
                                          diaryMoodIcon(mood),
                                          size: 18,
                                        ),
                                        label: Text(mood.label),
                                        selected: _mood == mood,
                                        onSelected: (_) => setState(
                                          () => _mood = _mood == mood
                                              ? null
                                              : mood,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                TextField(
                                  controller: _title,
                                  maxLines: null,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontFamily: 'serif'),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    hintText: 'Give today a title',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _body,
                                  enabled: !active,
                                  minLines: 8,
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(height: 1.7),
                                  decoration: const InputDecoration(
                                    hintText: 'Dear diary…',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                  ),
                                ),
                                for (final photo in _photos)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Stack(
                                      children: [
                                        DiaryPhoto(path: photo, height: 200),
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: IconButton.filled(
                                            tooltip: 'Remove photo',
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                            onPressed: () => setState(
                                              () => _photos.remove(photo),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (active)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.graphic_eq_rounded,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          recognition.isProcessing
                                              ? 'Finishing dictation…'
                                              : 'Listening…',
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: recognition.isProcessing
                                            ? null
                                            : _stopDictation,
                                        icon: const Icon(Icons.stop_rounded),
                                        label: const Text('Stop dictation'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _tool(
                                    Icons.add_photo_alternate_outlined,
                                    'Photo',
                                    _picking ? null : _pickPhoto,
                                  ),
                                  _tool(
                                    Icons.article_outlined,
                                    'Template',
                                    active ? null : _template,
                                  ),
                                  _tool(
                                    Icons.palette_outlined,
                                    'Theme',
                                    _chooseTheme,
                                  ),
                                  _tool(
                                    active
                                        ? Icons.stop_circle_outlined
                                        : Icons.mic_none_rounded,
                                    recognition.isListening
                                        ? 'Stop'
                                        : 'Dictate',
                                    recognition.isProcessing
                                        ? null
                                        : _toggleDictation,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback? onPressed) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
  Future<void> _toggleDictation() async {
    final recognition = ref.read(speechControllerProvider(_tag));
    if (recognition.isProcessing) return;
    if (recognition.isListening) {
      await _stopDictation();
      return;
    }
    _dictationPrefix = _body.text.trimRight();
    if (_dictationPrefix.isNotEmpty) _dictationPrefix += ' ';
    final settings = await ref.read(settingsControllerProvider.future);
    if (!mounted) return;
    await ref
        .read(speechControllerProvider(_tag).notifier)
        .startListening(languageByCode(settings.sourceLanguageCode).localeHint);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 30),
      lastDate: DateUtils.dateOnly(now),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = source == ImageSource.gallery
          ? await picker.pickMultiImage(
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 85,
            )
          : [
              await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 2048,
                maxHeight: 2048,
                imageQuality: 85,
              ),
            ].whereType<XFile>().toList();
      for (final photo in picked) {
        final path = await _photoStore.import(photo.path);
        if (!mounted) {
          await _photoStore.remove([path]);
          continue;
        }
        _addedPhotos.add(path);
        _photos.add(path);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not add the photo. Check photo permissions and try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _template() async {
    const templates = {
      'Daily reflection':
          'Today I felt…\n\nA moment I want to remember…\n\nTomorrow I hope to…',
      'Gratitude': 'Three things I am grateful for:\n\n1. \n2. \n3. ',
      'A small win':
          'Something I am proud of today…\n\nWhat helped me get there…',
    };
    final text = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in templates.entries)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(entry.key),
                onTap: () => Navigator.pop(sheet, entry.value),
              ),
          ],
        ),
      ),
    );
    if (text == null || !mounted) return;
    final current = _body.text.trimRight();
    _body.text = current.isEmpty ? text : '$current\n\n$text';
  }

  Future<void> _chooseTheme() async {
    final style = await showModalBottomSheet<DiaryPageStyle>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in DiaryPageStyle.values)
              ListTile(
                leading: Icon(switch (value) {
                  DiaryPageStyle.system => Icons.brightness_auto_rounded,
                  DiaryPageStyle.warm => Icons.description_outlined,
                  DiaryPageStyle.midnight => Icons.dark_mode_outlined,
                }),
                title: Text(switch (value) {
                  DiaryPageStyle.system => 'App appearance',
                  DiaryPageStyle.warm => 'Warm paper',
                  DiaryPageStyle.midnight => 'Midnight',
                }),
                trailing: _style == value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheet, value),
              ),
          ],
        ),
      ),
    );
    if (style != null && mounted) setState(() => _style = style);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _stopDictation();
      if (!mounted) return;
      if (_blank) return;
      final now = DateTime.now();
      final entry = DiaryEntry(
        id: _original?.id ?? 'diary-${now.microsecondsSinceEpoch}',
        date: _date,
        createdAt: _original?.createdAt ?? now,
        updatedAt: now,
        title: _title.text.trim(),
        body: _body.text.trim(),
        mood: _mood,
        pageStyle: _style,
        photos: List.unmodifiable(_photos),
      );
      await ref.read(diaryControllerProvider.notifier).save(entry);
      final unused = {
        ...?_original?.photos,
        ..._addedPhotos,
      }.difference(_photos.toSet());
      _addedPhotos.clear();
      // A cleanup failure must not turn a successful diary save into a failed save.
      try {
        await _photoStore.remove(unused);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _initial = _snapshot;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        context.pop();
        AppSnackbar.show(context, 'Diary entry saved');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not save your entry. Your words are still here; please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    await _stopDictation();
    if (!mounted) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Discard your changes?'),
          content: const Text('This entry has not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep writing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    try {
      await _photoStore.remove(_addedPhotos);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }
}
