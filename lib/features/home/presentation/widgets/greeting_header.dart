import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Good Morning/Afternoon/Evening, {name}" plus today's date — the first
/// thing shown on Home, so opening the app always feels addressed to you
/// rather than dropping you straight into a form or a list.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final timeOfDay = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final greeting = name.isEmpty ? timeOfDay : '$timeOfDay, $name';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, MMMM d').format(now),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
