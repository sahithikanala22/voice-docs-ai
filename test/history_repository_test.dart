import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/data/history_local_datasource.dart';
import 'package:ai_voice_docs/features/history/data/history_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HistoryRepositoryImpl repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = HistoryRepositoryImpl(HistoryLocalDataSource(prefs));
  });

  test('starts empty', () async {
    expect(await repository.getAll(), isEmpty);
  });

  test('add persists newest-first', () async {
    await repository.add(HistoryItem.voice(text: 'first', languageCode: 'en'));
    await repository.add(HistoryItem.voice(text: 'second', languageCode: 'en'));

    final items = await repository.getAll();
    expect(items, hasLength(2));
    expect(items.first.sourceText, 'second');
  });

  test('remove deletes only the matching id', () async {
    await repository.add(HistoryItem.voice(text: 'keep', languageCode: 'en'));
    final toRemove = HistoryItem.voice(text: 'remove me', languageCode: 'en');
    await repository.add(toRemove);

    await repository.remove(toRemove.id);

    final items = await repository.getAll();
    expect(items, hasLength(1));
    expect(items.single.sourceText, 'keep');
  });

  test('clear empties the list', () async {
    await repository.add(HistoryItem.voice(text: 'a', languageCode: 'en'));
    await repository.clear();

    expect(await repository.getAll(), isEmpty);
  });
  test('preserves more than 200 records and concurrent additions', () async {
    final entries = List.generate(
      250,
      (i) => HistoryItem.voice(text: 'entry $i', languageCode: 'en'),
    );
    await Future.wait(entries.map(repository.add));
    final restored = await repository.getAll();
    expect(restored, hasLength(250));
    expect(restored.any((e) => e.id == entries.first.id), isTrue);
    expect(restored.any((e) => e.id == entries.last.id), isTrue);
  });
  test('deleting a folder makes its entries genuinely unfiled', () async {
    await repository.add(
      HistoryItem.voice(text: 'keep', languageCode: 'en', folderId: 'deleted'),
    );
    await repository.unfileFolder('deleted');
    expect((await repository.getAll()).single.folderId, isNull);
  });
}
