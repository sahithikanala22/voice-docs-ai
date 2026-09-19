import 'package:flutter/material.dart';

/// A quick-start skeleton for an entry's text — tapping one fills the field
/// with a structure to write into rather than starting from a blank line.
/// Shared by the diary editor and the Calendar "Add entry" sheet.
class EntryTemplate {
  const EntryTemplate(this.label, this.icon, this.text);

  final String label;
  final IconData icon;
  final String text;
}

const entryTemplates = [
  EntryTemplate(
    'Reflection',
    Icons.self_improvement_rounded,
    'What went well today:\n\nWhat could be better:\n\nGrateful for:\n',
  ),
  EntryTemplate(
    'Gratitude',
    Icons.favorite_rounded,
    "Today I'm grateful for:\n1. \n2. \n3. ",
  ),
  EntryTemplate(
    'Meeting notes',
    Icons.groups_rounded,
    'Attendees:\n\nDiscussion:\n\nAction items:\n- ',
  ),
  EntryTemplate(
    'Plan',
    Icons.checklist_rounded,
    "Today's goals:\n- \n- \n- ",
  ),
  EntryTemplate(
    'Idea',
    Icons.lightbulb_rounded,
    'Idea:\n\nWhy it matters:\n\nNext step:\n',
  ),
];
