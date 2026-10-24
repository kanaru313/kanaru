import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/search_vocabulary.dart';

import 'search_index_test_helpers.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() async {
    await expectSearchIndexIntact(db);
    await db.close();
  });

  Future<void> add(String title, {String? artist}) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/${title.hashCode}.flac',
      mtimeMs: 1,
      sizeBytes: 10,
      title: title,
      artist: Value(artist),
      addedAt: 100,
      updatedAt: 100,
    ),
  ]);

  Map<String, int> asMap(List<({String term, int doc})> v) => {
    for (final e in v) e.term: e.doc,
  };

  test('lists each folded word with the songs holding it', () async {
    await add('Lạc Trôi', artist: 'Sơn Tùng M-TP');
    await add('Chạy Ngay Đi', artist: 'Sơn Tùng M-TP');

    final vocab = asMap(await db.searchVocabulary());

    expect(vocab['son'], 2);
    expect(vocab['tung'], 2);
    expect(vocab['lac'], 1);
    expect(vocab['di'], 1); // "Đi" folds to "di"
  });

  test('lists whole words only, not their prefixes', () async {
    await add('Beatles', artist: 'Beatles');

    final vocab = asMap(await db.searchVocabulary());

    expect(vocab.keys, {'beatles'});
  });

  test('can be read again and follows later changes', () async {
    await add('First');
    expect(asMap(await db.searchVocabulary()).keys, {'first'});
    expect(asMap(await db.searchVocabulary()).keys, {'first'});

    await add('Second');

    expect(asMap(await db.searchVocabulary()).keys, {'first', 'second'});
  });

  test('an empty library has no words', () async {
    expect(await db.searchVocabulary(), isEmpty);
  });
}
