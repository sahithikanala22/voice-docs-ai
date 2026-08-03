import 'package:flutter/material.dart';

/// Groups related settings under a header label, matching the settings
/// screen's "Appearance / Language / Data / About" section layout.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.primary,
            ),
          ),
        ),
        Card(child: Column(children: children)),
        const SizedBox(height: 24),
      ],
    );
  }
}
