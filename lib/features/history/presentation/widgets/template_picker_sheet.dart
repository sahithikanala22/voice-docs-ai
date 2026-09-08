import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

import '../../domain/entry_template.dart';

/// Bottom sheet listing the built-in diary templates as a grid of tinted
/// cards — pick one to move on to [showTemplatedEntrySheet] and fill in its
/// prompts.
Future<EntryTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<EntryTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a template',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'A few guided prompts instead of a blank page.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: builtInTemplates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final template = builtInTemplates[index];
                final color =
                    AppTheme.brandRays[index % AppTheme.brandRays.length];
                return _TemplateCard(
                  template: template,
                  color: color,
                  onTap: () => Navigator.pop(context, template),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.color,
    required this.onTap,
  });

  final EntryTemplate template;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(template.icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${template.prompts.length} prompts',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
