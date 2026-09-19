import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/entry_template.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';

import '../../data/diary_entry.dart';
import '../../domain/diary_mood.dart';
import '../../domain/diary_theme.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_page_background.dart';
import '../widgets/diary_photo.dart';

/// Distinct session tag so this screen's dictation never shares a transcript
/// with the Voice tab's mic.
const _speechTag = 'diary-editor';

/// Photos are downscaled on the way in: phone cameras produce several
/// thousand pixels a side, far more than a diary page needs, and storing them
/// full size would eat storage fast.
const _maxPhotoDimension = 2048.0;
const _photoQuality = 85;

/// Writes a new diary entry, or edits the one with [entryId].
class DiaryEditorScreen extends ConsumerStatefulWidget {
  const DiaryEditorScreen({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();

  DiaryEntry? _existing;
  late DateTime _date;
  DiaryMood? _mood;
  DiaryTheme _theme = DiaryTheme.classic;
  final List<String> _photos = [];

  /// The photos the entry had when editing began. Removing one of these only
  /// deletes its file on save, so backing out restores it.
  List<String> _originalPhotos = const [];

  /// Photos imported during this edit. These were never saved, so if the edit
  /// is abandoned their files are deleted rather than orphaned.
  final Set<String> _addedThisSession = {};

  late final String _initialTitle;
  late final String _initialBody;
  late final DiaryMood? _initialMood;
  late final DiaryTheme _initialTheme;
  late final DateTime _initialDate;

  bool _saving = false;
  bool _busyPicking = false;

  /// Body text as it was when dictation started, so spoken words are appended
  /// to what's already written instead of replacing it.
  String _dictationPrefix = '';
  late final SpeechController _speech;

  /// Mirrors the mic state for [dispose], which must not touch `ref`.
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechControllerProvider(_speechTag).notifier);

    final id = widget.entryId;
    final existing = id == null ? null : ref.read(diaryEntryProvider(id));
    _existing = existing;
    _date = DateUtils.dateOnly(existing?.date ?? DateTime.now());
    _title.text = existing?.title ?? '';
    _body.text = existing?.body ?? '';
    _mood = existing?.mood;
    _theme = existing?.theme ?? DiaryTheme.classic;
    _photos.addAll(existing?.photos ?? const []);
    _originalPhotos = List.unmodifiable(existing?.photos ?? const []);

    _initialTitle = _title.text;
    _initialBody = _body.text;
    _initialMood = _mood;
    _initialTheme = _theme;
    _initialDate = _date;

    _title.addListener(_rebuild);
    _body.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    // The speech controller outlives this screen, so leaving without stopping
    // would keep the mic recording in the background.
    if (_listening) _speech.stopListening();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _title.text != _initialTitle ||
      _body.text != _initialBody ||
      _mood != _initialMood ||
      _theme != _initialTheme ||
      _date != _initialDate ||
      _photos.length != _originalPhotos.length ||
      !_photos.every(_originalPhotos.contains);

  bool get _isBlank => _title.text.trim().isEmpty && _body.text.trim().isEmpty && _photos.isEmpty;

  @override
  Widget build(BuildContext context) {
    final style = _theme.style(Theme.of(context).colorScheme);
    final recognition = ref.watch(speechControllerProvider(_speechTag));

    ref.listen(speechControllerProvider(_speechTag), (previous, next) {
      _listening = next.isListening;
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
      // Covers the live updates while listening *and* the last one that
      // arrives as the session ends.
      final wasListening = previous?.isListening ?? false;
      if ((next.isListening || wasListening) && next.transcript != previous?.transcript) {
        _applyDictation(next.transcript);
      }
    });

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          await _discardSessionPhotos();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: style.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: style.background.first,
          body: DiaryPageBackground(
            style: style,
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    style: style,
                    isNew: _existing == null,
                    canSave: !_isBlank && !_saving,
                    saving: _saving,
                    onClose: () => Navigator.of(context).maybePop(),
                    onSave: _save,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                      children: [
                        _DateHeader(date: _date, style: style, onTap: _pickDate),
                        const SizedBox(height: 14),
                        _MoodPicker(
                          selected: _mood,
                          style: style,
                          onChanged: (mood) => setState(() => _mood = mood),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: style.accent,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: style.ink,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _plainDecoration('Give it a title', style),
                        ),
                        if (_photos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _PhotoStrip(photos: _photos, style: style, onRemove: _removePhoto),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: _body,
                          maxLines: null,
                          minLines: 10,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: style.accent,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: style.ink,
                            height: 1.6,
                          ),
                          decoration: _plainDecoration(
                            recognition.isListening ? 'Listening…' : 'Dear diary…',
                            style,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Toolbar(
                    style: style,
                    isListening: recognition.isListening,
                    busyPicking: _busyPicking,
                    onPhoto: _choosePhotoSource,
                    onTemplate: _chooseTemplate,
                    onTheme: _chooseTheme,
                    onMic: () => _toggleDictation(recognition.isListening),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Unfilled, borderless — the themed page itself is the writing surface,
  /// so the app's default filled field style would look like a box on it.
  InputDecoration _plainDecoration(String hint, DiaryThemeStyle style) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: style.subtle.withValues(alpha: 0.7)),
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = DateUtils.dateOnly(picked));
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Pick one or more photos'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _addPhotos(source);
  }

  Future<void> _addPhotos(ImageSource source) async {
    setState(() => _busyPicking = true);
    try {
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await _picker.pickMultiImage(
          maxWidth: _maxPhotoDimension,
          maxHeight: _maxPhotoDimension,
          imageQuality: _photoQuality,
        );
      } else {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: _maxPhotoDimension,
          maxHeight: _maxPhotoDimension,
          imageQuality: _photoQuality,
        );
        picked = [?shot];
      }

      final store = ref.read(diaryPhotoStoreProvider);
      for (final file in picked) {
        final name = await store.import(file.path);
        _addedThisSession.add(name);
        _photos.add(name);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
              ? 'Permission needed to add photos. Allow it in your phone\'s settings.'
              : 'Could not add the photo: ${e.message ?? e.code}',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Could not add the photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyPicking = false);
    }
  }

  void _removePhoto(String name) {
    setState(() => _photos.remove(name));
    // Never saved, so nothing else can reference it — delete right away.
    // A photo from the saved entry is kept until save, in case of Cancel.
    if (_addedThisSession.remove(name)) {
      ref.read(diaryPhotoStoreProvider).delete([name]);
    }
  }

  Future<void> _chooseTemplate() async {
    final template = await showModalBottomSheet<EntryTemplate>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in entryTemplates)
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                onTap: () => Navigator.pop(sheetContext, t),
              ),
          ],
        ),
      ),
    );
    if (template == null || !mounted) return;

    if (_body.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace what you\'ve written?'),
          content: Text('This replaces the entry text with the "${template.label}" template.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Replace')),
          ],
        ),
      );
      if (replace != true) return;
    }
    _body.value = TextEditingValue(
      text: template.text,
      selection: TextSelection.collapsed(offset: template.text.length),
    );
  }

  Future<void> _chooseTheme() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Translucent, so the page behind visibly changes as themes are tapped.
      barrierColor: Colors.black26,
      builder: (sheetContext) => _ThemeSheet(
        selected: _theme,
        onSelected: (theme) => setState(() => _theme = theme),
      ),
    );
  }

  Future<void> _toggleDictation(bool isListening) async {
    if (isListening) {
      await _speech.stopListening();
      return;
    }
    _dictationPrefix = _body.text;
    final code = ref.read(settingsControllerProvider).value?.sourceLanguageCode;
    final locale = code == null ? 'en-US' : languageByCode(code).localeHint;
    await _speech.startListening(locale);
  }

  void _applyDictation(String transcript) {
    final prefix = _dictationPrefix;
    final needsSpace = prefix.isNotEmpty && !RegExp(r'\s$').hasMatch(prefix);
    final text = transcript.isEmpty ? prefix : '$prefix${needsSpace ? ' ' : ''}$transcript';
    _body.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_existing == null ? 'Discard this entry?' : 'Discard your changes?'),
        content: const Text('What you\'ve written here will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep writing')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _discardSessionPhotos() async {
    if (_addedThisSession.isEmpty) return;
    await ref.read(diaryPhotoStoreProvider).delete(_addedThisSession);
    _addedThisSession.clear();
  }

  Future<void> _save() async {
    if (_isBlank || _saving) return;
    setState(() => _saving = true);
    if (ref.read(speechControllerProvider(_speechTag)).isListening) {
      await _speech.stopListening();
    }

    final base = _existing ?? DiaryEntry.create(date: _date);
    final entry = base.copyWith(
      date: _date,
      title: _title.text.trim(),
      body: _body.text.trimRight(),
      photos: List.of(_photos),
      mood: _mood,
      theme: _theme,
    );
    final removed = _originalPhotos.where((p) => !_photos.contains(p)).toList();

    await ref.read(diaryControllerProvider.notifier).save(entry, removedPhotos: removed);
    // Now saved, so these belong to the entry and must survive leaving.
    _addedThisSession.clear();
    if (!mounted) return;
    context.pop();
    AppSnackbar.show(context, _existing == null ? 'Entry saved' : 'Changes saved');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.style,
    required this.isNew,
    required this.canSave,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final DiaryThemeStyle style;
  final bool isNew;
  final bool canSave;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: style.ink),
            tooltip: 'Close',
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              isNew ? 'New entry' : 'Edit entry',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: style.ink),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: style.accent,
              foregroundColor: style.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            onPressed: canSave ? onSave : null,
            child: saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.style, required this.onTap});

  final DateTime date;
  final DiaryThemeStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              DateFormat('d').format(date),
              style: textTheme.displaySmall?.copyWith(
                color: style.accent,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('EEEE').format(date), style: textTheme.titleMedium?.copyWith(color: style.ink)),
                Text(DateFormat('MMMM yyyy').format(date), style: textTheme.bodySmall?.copyWith(color: style.subtle)),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, color: style.subtle),
          ],
        ),
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({required this.selected, required this.style, required this.onChanged});

  final DiaryMood? selected;
  final DiaryThemeStyle style;
  final ValueChanged<DiaryMood?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DiaryMood.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final mood = DiaryMood.values[index];
          final isSelected = mood == selected;
          return Tooltip(
            message: mood.label,
            child: GestureDetector(
              // Tapping the chosen mood again clears it.
              onTap: () => onChanged(isSelected ? null : mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 54,
                decoration: BoxDecoration(
                  color: isSelected ? style.accent.withValues(alpha: 0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? style.accent : style.subtle.withValues(alpha: 0.25),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.18 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    Text(
                      mood.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: style.subtle, fontWeight: FontWeight.w600),
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
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.style, required this.onRemove});

  final List<String> photos;
  final DiaryThemeStyle style;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = photos[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(width: 120, height: 120, child: DiaryPhoto(name: name, decodeWidth: 360)),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(name),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.style,
    required this.isListening,
    required this.busyPicking,
    required this.onPhoto,
    required this.onTemplate,
    required this.onTheme,
    required this.onMic,
  });

  final DiaryThemeStyle style;
  final bool isListening;
  final bool busyPicking;
  final VoidCallback onPhoto;
  final VoidCallback onTemplate;
  final VoidCallback onTheme;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: (style.isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.subtle.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Photo',
            style: style,
            onTap: busyPicking ? null : onPhoto,
            busy: busyPicking,
          ),
          _ToolButton(icon: Icons.auto_awesome_outlined, label: 'Template', style: style, onTap: onTemplate),
          _ToolButton(icon: Icons.palette_outlined, label: 'Theme', style: style, onTap: onTheme),
          _ToolButton(
            icon: isListening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
            label: isListening ? 'Stop' : 'Dictate',
            style: style,
            onTap: onMic,
            highlighted: isListening,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.style,
    required this.onTap,
    this.highlighted = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final DiaryThemeStyle style;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? style.accent : style.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Theme swatches. Each tap applies immediately, so the page behind the sheet
/// previews it live.
class _ThemeSheet extends StatefulWidget {
  const _ThemeSheet({required this.selected, required this.onSelected});

  final DiaryTheme selected;
  final ValueChanged<DiaryTheme> onSelected;

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  late DiaryTheme _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Page theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final theme in DiaryTheme.values)
                  _ThemeSwatch(
                    theme: theme,
                    style: theme.style(scheme),
                    selected: theme == _selected,
                    onTap: () {
                      setState(() => _selected = theme);
                      widget.onSelected(theme);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.style, required this.selected, required this.onTap});

  final DiaryTheme theme;
  final DiaryThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: DiaryPageBackground(
          style: style,
          borderRadius: BorderRadius.circular(13),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aa', style: TextStyle(color: style.ink, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  theme.label,
                  style: TextStyle(color: style.accent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
