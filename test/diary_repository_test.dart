import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/diary/data/diary_local_datasource.dart';
import 'package:ai_voice_docs/features/diary/data/diary_repository_impl.dart';
import 'package:ai_voice_docs/features/diary/domain/diary_mood.dart';

DiaryEntry _entry({required DateTime date, String title = ''}) =>
    DiaryEntry.create(date: date).copyWith(title: title);

void main() {
  late DiaryRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = DiaryRepositoryImpl(DiaryLocalDataSource(prefs));
  });

  test('starts empty', () async {
    expect(await repository.getAll(), isEmpty);
  });

  test('save inserts a new entry', () async {
    final entry = _entry(date: DateTime(2026, 1, 1), title: 'First');
    await repository.save(entry);

    final all = await repository.getAll();
    expect(all, hasLength(1));
    expect(all.single.title, 'First');
  });

  test('save with an existing id replaces rather than duplicates', () async {
    final entry = _entry(date: DateTime(2026, 1, 1), title: 'Draft');
    await repository.save(entry);
    await repository.save(entry.copyWith(title: 'Final', mood: DiaryMood.happy));

    final all = await repository.getAll();
    expect(all, hasLength(1));
    expect(all.single.title, 'Final');
    expect(all.single.mood, DiaryMood.happy);
  });

  test('newest date sorts first', () async {
    await repository.save(_entry(date: DateTime(2026, 1, 1), title: 'Old'));
    await repository.save(_entry(date: DateTime(2026, 3, 1), title: 'New'));
    await repository.save(_entry(date: DateTime(2026, 2, 1), title: 'Middle'));

    final titles = (await repository.getAll()).map((e) => e.title).toList();
    expect(titles, ['New', 'Middle', 'Old']);
  });

  test('remove deletes only the matching id', () async {
    final a = _entry(date: DateTime(2026, 1, 1), title: 'A');
    final b = _entry(date: DateTime(2026, 1, 2), title: 'B');
    await repository.save(a);
    await repository.save(b);

    await repository.remove(a.id);

    final all = await repository.getAll();
    expect(all, hasLength(1));
    expect(all.single.title, 'B');
  });

  test('round-trips photos, mood and theme through storage', () async {
    final entry = _entry(date: DateTime(2026, 1, 1)).copyWith(
      photos: ['a.jpg', 'b.jpg'],
      mood: DiaryMood.calm,
    );
    await repository.save(entry);

    final reloaded = (await repository.getAll()).single;
    expect(reloaded.photos, ['a.jpg', 'b.jpg']);
    expect(reloaded.mood, DiaryMood.calm);
  });
}
