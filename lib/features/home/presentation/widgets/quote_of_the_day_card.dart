import 'package:flutter/material.dart';

/// A short, encouraging line that rotates once a day — picked deterministically
/// from the day of the year, so it's stable across rebuilds within a day and
/// changes tomorrow, with no persistence or network call needed.
class QuoteOfTheDayCard extends StatelessWidget {
  const QuoteOfTheDayCard({super.key});

  static const _quotes = [
    'Small steps every day add up to big change.',
    'Your voice is worth writing down.',
    'A page a day keeps the memories close.',
    'Speak your mind — the app will catch the rest.',
    'Today is a good day to note something down.',
    'Every entry is a little time capsule.',
    'Say it, and it\'s saved.',
    'The best time to write is right now.',
    'Look back later, but write it down today.',
    'Your thoughts deserve a home.',
    'One sentence today is still progress.',
    'Capture it before it fades.',
    'A quiet moment, put into words.',
    'What happened today that\'s worth remembering?',
    'Turn today\'s thoughts into tomorrow\'s memories.',
    'Even a short note is a note kept.',
    'Your story is written one day at a time.',
    'Take a breath, then tell today\'s story.',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final quote = _quotes[dayOfYear % _quotes.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
