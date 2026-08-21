import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

import '../../data/folder.dart';
import '../providers/folder_providers.dart';

/// Bottom sheet for picking a folder. The return value distinguishes three
/// outcomes, since `null` alone can't tell "dismissed" apart from
/// "explicitly chose no folder":
/// - `null` — dismissed without a selection (caller should do nothing)
/// - `''` (empty string) — "No folder" was explicitly selected
/// - any other string — the id of the selected folder
Future<String?> showFolderPicker(BuildContext context, {required String? selectedFolderId}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _FolderPickerSheet(selectedFolderId: selectedFolderId),
  );
}

/// Row of tappable color swatches from [AppTheme.folderPalette], with a
/// check mark on whichever [selectedIndex] is current. Shared by the
/// "new folder" row and the rename dialog so both offer the same colors.
class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < AppTheme.folderPalette.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.folderPalette[i],
                border: i == selectedIndex
                    ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                    : null,
              ),
              child: i == selectedIndex
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _FolderPickerSheet extends ConsumerStatefulWidget {
  const _FolderPickerSheet({required this.selectedFolderId});

  final String? selectedFolderId;

  @override
  ConsumerState<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<_FolderPickerSheet> {
  final _newFolderController = TextEditingController();
  int _newFolderColorIndex = 0;

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Folders', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RadioGroup<String?>(
            groupValue: widget.selectedFolderId,
            onChanged: (value) => Navigator.pop(context, value ?? ''),
            child: Column(
              children: [
                const RadioListTile<String?>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('No folder'),
                  value: null,
                ),
                foldersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Could not load folders: $err'),
                  ),
                  data: (folders) => Column(
                    children: [
                      for (final folder in folders)
                        RadioListTile<String?>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(folder.name, overflow: TextOverflow.ellipsis),
                          value: folder.id,
                          secondary: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor:
                                    AppTheme.folderPalette[folder.colorIndex % AppTheme.folderPalette.length],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Rename',
                                onPressed: () => _editFolder(folder),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                tooltip: 'Delete',
                                onPressed: () => _deleteFolder(folder),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('New folder', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _ColorSwatchRow(
            selectedIndex: _newFolderColorIndex,
            onChanged: (index) => setState(() => _newFolderColorIndex = index),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFolderController,
                  decoration: const InputDecoration(hintText: 'Folder name, e.g. Diary'),
                  onSubmitted: (_) => _createFolder(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _createFolder, child: const Text('Create')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;
    final folder = await ref
        .read(folderControllerProvider.notifier)
        .addFolder(name, colorIndex: _newFolderColorIndex);
    if (mounted) Navigator.pop(context, folder.id);
  }

  Future<void> _editFolder(Folder folder) async {
    final nameController = TextEditingController(text: folder.name);
    var colorIndex = folder.colorIndex;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameController, autofocus: true),
              const SizedBox(height: 16),
              _ColorSwatchRow(
                selectedIndex: colorIndex,
                onChanged: (index) => setDialogState(() => colorIndex = index),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      await ref.read(folderControllerProvider.notifier).updateFolder(
            folder.id,
            name: nameController.text.trim(),
            colorIndex: colorIndex,
          );
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          '"${folder.name}" will be removed. Entries inside it become unfiled — nothing is deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(folderControllerProvider.notifier).removeFolder(folder.id);
    }
  }
}
