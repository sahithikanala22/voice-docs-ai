import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../../data/history_item.dart';
import '../../data/history_pdf_generator.dart';
import '../../data/history_word_generator.dart';

/// Generates a file via [generate] and hands it to the OS share sheet.
/// Shared by the History detail sheet's explicit Share PDF/Word buttons and
/// [showShareFormatSheet]'s chooser, so both paths handle failures the
/// same way.
Future<void> shareGeneratedFile(
  BuildContext context,
  Future<File> Function() generate,
  String failureMessage,
) async {
  try {
    final file = await generate();
    if (!context.mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'Shared from Voice Docs AI');
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.show(context, failureMessage, isError: true);
    }
  }
}

/// Bottom sheet letting the user pick PDF or Word before sharing [item] —
/// used anywhere a quick "share this" action needs to offer both formats
/// instead of assuming one (the History list's share icon, the
/// Voice-to-Text screen's share action, etc).
Future<void> showShareFormatSheet(BuildContext context, HistoryItem item) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareGeneratedFile(
                  context,
                  () => HistoryPdfGenerator().generate(item),
                  'Could not create the PDF.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Share as Word'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareGeneratedFile(
                  context,
                  () => HistoryWordGenerator().generate(item),
                  'Could not create the Word document.',
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Same PDF/Word chooser as [showShareFormatSheet], but for a whole batch of
/// entries bundled into one digest file (e.g. "export this month") instead
/// of a single entry — used by the Calendar tab's month export action.
Future<void> showDigestShareFormatSheet(
  BuildContext context,
  List<HistoryItem> items, {
  required String title,
  required String fileSlug,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareGeneratedFile(
                  context,
                  () => HistoryPdfGenerator().generateDigest(items, title: title, fileSlug: fileSlug),
                  'Could not create the PDF.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as Word'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareGeneratedFile(
                  context,
                  () => HistoryWordGenerator().generateDigest(items, title: title, fileSlug: fileSlug),
                  'Could not create the Word document.',
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
