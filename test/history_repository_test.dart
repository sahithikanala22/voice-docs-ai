import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:voxi_translate/features/history/data/history_item.dart';
import 'package:voxi_translate/features/history/data/history_local_datasource.dart';
import 'package:voxi_translate/features/history/data/history_repository_impl.dart';

void main() {
  late HistoryRepositoryImpl repository;

  setUp(() async {
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

  test('translation entries round-trip through JSON with target language', () async {
    await repository.add(HistoryItem.translation(
      sourceText: 'hello',
      translatedText: 'hola',
      sourceLanguageCode: 'en',
      targetLanguageCode: 'es',
    ));

    final items = await repository.getAll();
    expect(items.single.type, HistoryItemType.translation);
    expect(items.single.translatedText, 'hola');
    expect(items.single.targetLanguageCode, 'es');
  });
}
