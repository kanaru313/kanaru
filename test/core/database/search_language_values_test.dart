import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/search_language_values.dart';

void main() {
  group('matchingLanguageValues', () {
    const distinct = ['vie', 'Vietnamese; English', 'vi', 'eng', 'ja', 'vi-VN'];

    test('keeps every raw tag that lists the language', () {
      expect(matchingLanguageValues(distinct, ['vi']), [
        'vie',
        'Vietnamese; English',
        'vi',
        'vi-VN',
      ]);
    });

    test('a tag in a list matches its second language', () {
      expect(matchingLanguageValues(distinct, ['en']), [
        'Vietnamese; English',
        'eng',
      ]);
    });

    test('several wanted values are OR', () {
      expect(matchingLanguageValues(distinct, ['ja', 'eng']), [
        'Vietnamese; English',
        'eng',
        'ja',
      ]);
    });

    test('no match or nothing wanted gives an empty list', () {
      expect(matchingLanguageValues(distinct, ['ko']), isEmpty);
      expect(matchingLanguageValues(distinct, const []), isEmpty);
      expect(matchingLanguageValues(const [], ['vi']), isEmpty);
    });

    test('an unknown value matches only itself, case-insensitively', () {
      expect(matchingLanguageValues(['X-Klingon', 'vi'], ['x-klingon']), [
        'X-Klingon',
      ]);
    });
  });

  test(
    'loadDistinctLanguages lists each raw tag once, skipping NULL',
    () async {
      final db = LibraryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final rootId = (await db.addRoots(['/m'], now: 1)).single;
      var n = 0;
      await db.upsertTracks([
        for (final language in ['vi', 'vi', 'Vietnamese; English', null])
          TracksCompanion.insert(
            rootId: rootId,
            path: '/m/${n++}.flac',
            mtimeMs: 1,
            sizeBytes: 1,
            title: 't$n',
            language: Value(language),
            addedAt: 1,
            updatedAt: 1,
          ),
      ]);
      expect(
        await loadDistinctLanguages(db),
        unorderedEquals(['vi', 'Vietnamese; English']),
      );
    },
  );
}
