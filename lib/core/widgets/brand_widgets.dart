import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .25),
    child: Image.asset(
      'assets/icon/icon.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}

class BrandAppTitle extends StatelessWidget {
  const BrandAppTitle({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppBrandMark(size: 32),
      SizedBox(width: 10),
      Flexible(child: Text('Voice Docs AI', overflow: TextOverflow.ellipsis)),
    ],
  );
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: IconButton.filledTonal(
      tooltip: 'Settings',
      icon: const Icon(Icons.person_outline_rounded),
      onPressed: () => context.push('/settings'),
    ),
  );
}

class PageIntroduction extends StatelessWidget {
  const PageIntroduction({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}
