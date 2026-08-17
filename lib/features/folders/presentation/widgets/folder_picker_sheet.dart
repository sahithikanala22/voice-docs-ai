import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _FolderPickerSheet extends ConsumerStatefulWidget {
  const _FolderPickerSheet({required this.selectedFolderId});

  final String? selectedFolderId;

  @override
  ConsumerState<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<_FolderPickerSheet> {
  final _newFolderController = TextEditingController();

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
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Rename',
                                onPressed: () => _renameFolder(folder),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFolderController,
                  decoration: const InputDecoration(hintText: 'New folder name, e.g. Diary'),
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
    final folder = await ref.read(folderControllerProvider.notifier).addFolder(name);
    if (mounted) Navigator.pop(context, folder.id);
  }

  Future<void> _renameFolder(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(folderControllerProvider.notifier).renameFolder(folder.id, newName);
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
