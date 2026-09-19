import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/diary/presentation/screens/diary_screen.dart';

DiaryEntry _entryOn(DateTime date) => DiaryEntry.create(date: date);

void main() {
  final today = DateTime(2026, 6, 15);

  test('no entries is a zero streak', () {
    expect(diaryStreak([], today), 0);
  });

  test('an entry today counts as a streak of one', () {
    expect(diaryStreak([_entryOn(today)], today), 1);
  });

  test('consecutive days ending today count each day', () {
    final entries = [
      _entryOn(today),
      _entryOn(today.subtract(const Duration(days: 1))),
      _entryOn(today.subtract(const Duration(days: 2))),
    ];
    expect(diaryStreak(entries, today), 3);
  });

  test('a gap stops the streak from reaching further back', () {
    final entries = [
      _entryOn(today),
      _entryOn(today.subtract(const Duration(days: 1))),
      // day 2 missing
      _entryOn(today.subtract(const Duration(days: 3))),
    ];
    expect(diaryStreak(entries, today), 2);
  });

  test('nothing written today yet still counts yesterday\'s streak', () {
    final entries = [
      _entryOn(today.subtract(const Duration(days: 1))),
      _entryOn(today.subtract(const Duration(days: 2))),
    ];
    expect(diaryStreak(entries, today), 2);
  });

  test('nothing today or yesterday is a broken streak', () {
    final entries = [_entryOn(today.subtract(const Duration(days: 2)))];
    expect(diaryStreak(entries, today), 0);
  });

  test('an entry\'s time of day does not affect which day it counts as', () {
    final lateNight = DateTime(today.year, today.month, today.day, 23, 59);
    expect(diaryStreak([_entryOn(lateNight)], today), 1);
  });

  test('multiple entries on the same day only count once', () {
    final entries = [_entryOn(today), _entryOn(today), _entryOn(today)];
    expect(diaryStreak(entries, today), 1);
  });
}
