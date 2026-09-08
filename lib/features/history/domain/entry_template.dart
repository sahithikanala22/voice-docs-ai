import 'package:flutter/material.dart';

/// A named set of guiding prompts for a structured diary entry — picked
/// instead of the blank mic screen when you want something more shaped than
/// a free-form recording (a daily reflection, a gratitude list, ...).
/// Built-in only for now; each prompt is answered separately (voice or
/// text) and the answers are combined into one saved entry.
class EntryTemplate {
  const EntryTemplate({
    required this.name,
    required this.icon,
    required this.prompts,
  });

  final String name;
  final IconData icon;
  final List<String> prompts;
}

const builtInTemplates = [
  EntryTemplate(
    name: 'Daily Reflection',
    icon: Icons.wb_twilight_rounded,
    prompts: [
      'What went well today?',
      'What was challenging?',
      'What am I looking forward to tomorrow?',
    ],
  ),
  EntryTemplate(
    name: 'Gratitude',
    icon: Icons.favorite_rounded,
    prompts: [
      'What am I grateful for today?',
      'Who made a positive difference today?',
    ],
  ),
  EntryTemplate(
    name: 'Dream Journal',
    icon: Icons.nights_stay_rounded,
    prompts: ['What did I dream about?', 'How did it make me feel?'],
  ),
  EntryTemplate(
    name: 'Work Log',
    icon: Icons.work_outline_rounded,
    prompts: [
      'What did I work on today?',
      'What\'s blocking me?',
      'What\'s next?',
    ],
  ),
  EntryTemplate(
    name: 'Morning Pages',
    icon: Icons.wb_sunny_rounded,
    prompts: [
      'What\'s on my mind this morning?',
      'What\'s my intention for today?',
    ],
  ),
  EntryTemplate(
    name: 'Evening Wind-down',
    icon: Icons.bedtime_rounded,
    prompts: [
      'How am I feeling right now?',
      'What can I let go of before sleep?',
    ],
  ),
  EntryTemplate(
    name: 'Travel Log',
    icon: Icons.flight_takeoff_rounded,
    prompts: [
      'Where am I today?',
      'What did I see or experience?',
      'A moment I want to remember',
    ],
  ),
  EntryTemplate(
    name: 'Letter to Future Me',
    icon: Icons.mail_outline_rounded,
    prompts: [
      'What do I want to remember about right now?',
      'What advice would I give my future self?',
    ],
  ),
];
