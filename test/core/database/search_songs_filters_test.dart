import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_search_queries.dart';
import 'package:kanaru/core/database/search_file_text_index.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_query.dart';
import 'package:kanaru/core/search/search_query_parser.dart';

import 'search_index_test_helpers.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var n = 0;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() async {
    await expectSearchIndexIntact(db);
    await db.close();
  });

  Future<void> add(
    String title, {
    String? artist,
    String? album,
    String? genre,
    String? language,
    int? year,
    String ext = 'flac',
    String? name,
    String? comment,
  }) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/${name ?? 'f${n++}'}.$ext',
      mtimeMs: 1,
      sizeBytes: 10,
      title: title,
      artist: Value(artist),
      album: Value(album),
      genre: Value(genre),
      language: Value(language),
      year: Value(year),
      comment: Value(comment),
      addedAt: 100,
      updatedAt: 100,
    ),
  ]);

  SearchRequest request(String raw, [Set<SearchField>? fields]) =>
      SearchRequest(
        query: parseSearchQuery(raw),
        fields: fields ?? defaultSearchFields,
      );

  Future<List<String>> titles(
    String raw, {
    Set<SearchField>? fields,
    List<int> extra = const [],
  }) async => [
    for (final s in (await db.searchSongsFor(
      request(raw, fields),
      extraIds: extra,
    )).songs)
      s.title,
  ];

  test('artist: matches only the artist column', () async {
    await add('Love Song', artist: 'Taylor');
    await add('Taylor Tribute', artist: 'Other');
    expect(await titles('artist:taylor'), ['Love Song']);
    expect(
      await titles('taylor'),
      unorderedEquals(['Love Song', 'Taylor Tribute']),
    );
  });

  test('album: and genre: use their own columns, quoted values work', () async {
    await add('One', album: 'Dark Side', genre: 'Rock');
    await add('Two', artist: 'Dark Side', genre: 'Jazz');
    expect(await titles('album:"dark side"'), ['One']);
    expect(await titles('genre:jazz'), ['Two']);
    expect(await titles('genre:rock album:dark'), ['One']);
  });

  test('a field term and free text both have to match', () async {
    await add('Love Me', artist: 'Tay Tay');
    await add('Love You', artist: 'Someone');
    expect(await titles('love artist:tay'), ['Love Me']);
  });

  test('year: forms, and a song without a year never matches', () async {
    await add('Y1999', year: 1999);
    await add('Y2010', year: 2010);
    await add('Y2012', year: 2012);
    await add('Y2020', year: 2020);
    await add('NoYear');
    expect(await titles('year:2010'), ['Y2010']);
    expect(await titles('year:>2010'), unorderedEquals(['Y2012', 'Y2020']));
    expect(await titles('year:<2010'), ['Y1999']);
    expect(await titles('year:2010-2012'), ['Y2010', 'Y2012']);
    expect(await titles('year:>=2012'), unorderedEquals(['Y2012', 'Y2020']));
    expect(await titles('year:>2000 year:<2015'), ['Y2010', 'Y2012']);
  });

  group('language:', () {
    test('matches by language key across spellings and lists', () async {
      await add('Code2', language: 'vi');
      await add('Code3', language: 'vie');
      await add('List', language: 'Vietnamese; English');
      await add('English', language: 'eng');
      await add('Untagged');
      expect(await titles('language:vi'), ['Code2', 'Code3', 'List']);
      expect(await titles('language:en'), ['English', 'List']);
    });

    test('combines with other filters and words', () async {
      await add('Old', language: 'vi', year: 2005);
      await add('New', language: 'vie', year: 2015);
      await add('Other', language: 'en', year: 2020);
      expect(await titles('language:vi year:>2010'), ['New']);
      await add('Hit New', language: 'vi', year: 2020);
      expect(await titles('hit language:vi'), ['Hit New']);
    });

    test('several values are OR', () async {
      await add('V', language: 'vi');
      await add('E', language: 'en');
      await add('J', language: 'ja');
      expect(await titles('language:vi language:eng'), ['E', 'V']);
    });

    test('untagged songs never match', () async {
      await add('Untagged');
      await add('Tagged', language: 'vi');
      expect(await titles('language:vi'), ['Tagged']);
      expect(await titles('language:und'), isEmpty);
    });

    test('no stored tag matching gives no songs', () async {
      await add('A', language: 'vi');
      final result = await db.searchSongsFor(request('language:ja'));
      expect(result.songs, isEmpty);
      expect(result.total, 0);
      expect(await titles('a language:ja'), isEmpty);
    });

    test(
      'a given distinct list is used instead of reading the library',
      () async {
        await add('A', language: 'vi');
        final result = await db.searchSongsFor(
          request('language:vi'),
          distinctLanguages: const ['vi'],
        );
        expect(result.total, 1);
        final none = await db.searchSongsFor(
          request('language:vi'),
          distinctLanguages: const [],
        );
        expect(none.total, 0);
      },
    );

    test('works with file name text and counts after the filter', () async {
      await add('Untitled', language: 'vi', name: 'rain-live');
      await add('Other', language: 'en', name: 'rain-demo');
      final index = await SearchFileTextIndex.load(db);
      final found = index.match(['rain'], fileName: true, comment: false);
      final result = await db.searchSongsFor(
        request('rain language:vi', {SearchField.fileName}),
        extraIds: found,
      );
      expect([for (final s in result.songs) s.title], ['Untitled']);
      expect(result.total, 1);
    });
  });

  test('format: ignores case of the extension and ORs formats', () async {
    await add('Upper', ext: 'FLAC');
    await add('Lower', ext: 'flac');
    await add('Mp3', ext: 'mp3');
    await add('Ogg', ext: 'ogg');
    expect(await titles('format:flac'), ['Lower', 'Upper']);
    expect(await titles('format:flac format:mp3'), hasLength(3));
  });

  test(
    'filters combine with words and total counts after the filter',
    () async {
      await add('Hit A', year: 2001, ext: 'mp3');
      await add('Hit B', year: 2001, ext: 'flac');
      await add('Hit C', year: 1990, ext: 'flac');
      final result = await db.searchSongsFor(
        request('hit year:2001 format:flac'),
      );
      expect([for (final s in result.songs) s.title], ['Hit B']);
      expect(result.total, 1);
      final onlyFilter = await db.searchSongsFor(request('year:<2000'));
      expect(onlyFilter.total, 1);
    },
  );

  test('filters only list songs by title', () async {
    await add('Beta', year: 2001);
    await add('Alpha', year: 2001);
    expect(await titles('year:2001'), ['Alpha', 'Beta']);
  });

  test('title only does not match album or artist', () async {
    await add('Moon', artist: 'Sun');
    await add('Sun Song', album: 'Other');
    expect(await titles('sun', fields: SearchFieldPreset.titleOnly.fields), [
      'Sun Song',
    ]);
    expect(await titles('sun'), hasLength(2));
  });

  test('a chosen subset of columns is searched together', () async {
    await add('Lac', artist: 'Son');
    await add('Son', artist: 'Lac');
    const subset = {SearchField.title, SearchField.artist};
    expect(await titles('lac son', fields: subset), hasLength(2));
    expect(
      await titles('lac son', fields: SearchFieldPreset.titleOnly.fields),
      isEmpty,
    );
  });

  test('nothing to search gives no songs', () async {
    await add('Anything');
    expect(await titles(''), isEmpty);
    expect(await titles('   '), isEmpty);
  });

  group('file name and comment', () {
    Future<List<int>> ids(
      String raw, {
      bool fileName = false,
      bool comment = false,
    }) async {
      final index = await SearchFileTextIndex.load(db);
      return index.match(
        parseSearchQuery(raw).freeTerms,
        fileName: fileName,
        comment: comment,
      );
    }

    test('file name only: matches through the extra ids', () async {
      await add('Untitled', name: 'Sơn Tùng - Lạc trôi');
      await add('Other', name: 'unrelated');
      const fields = {SearchField.fileName};
      final found = await ids('son lac', fileName: true);
      expect(found, hasLength(1));
      expect(await titles('son lac', fields: fields, extra: found), [
        'Untitled',
      ]);
      expect(await titles('son lac', fields: fields), isEmpty);
    });

    test('tag matches rank before file name matches', () async {
      await add('Rain', name: 'a1');
      await add('Zzz', name: 'rain-live');
      await add('Aaa', name: 'rain-demo');
      final fields = {...defaultSearchFields, SearchField.fileName};
      final found = await ids('rain', fileName: true);
      expect(found, hasLength(2));
      expect(await titles('rain', fields: fields, extra: found), [
        'Rain',
        'Aaa',
        'Zzz',
      ]);
    });

    test('a song matching both ways is listed once', () async {
      await add('Rain', name: 'rain');
      final fields = {...defaultSearchFields, SearchField.fileName};
      final found = await ids('rain', fileName: true);
      final result = await db.searchSongsFor(
        request('rain', fields),
        extraIds: found,
      );
      expect(result.songs, hasLength(1));
      expect(result.total, 1);
    });

    test(
      'comment matches and extra ids respect field terms and filters',
      () async {
        await add('A', artist: 'Tay', comment: 'live recording', year: 2001);
        await add('B', artist: 'Other', comment: 'live recording', year: 2001);
        await add('C', artist: 'Tay', comment: 'live recording', year: 1990);
        const fields = {SearchField.comment};
        final found = await ids('live', comment: true);
        expect(found, hasLength(3));
        expect(
          await titles(
            'live artist:tay year:2001',
            fields: fields,
            extra: found,
          ),
          ['A'],
        );
        final result = await db.searchSongsFor(
          request('live year:2001', fields),
          extraIds: found,
        );
        expect(result.total, 2);
      },
    );

    test('field terms only narrow extra ids, they never add songs', () async {
      await add('A', artist: 'Tay', comment: 'live');
      await add('D', artist: 'Tay', comment: 'studio');
      final found = await ids('live', comment: true);
      expect(found, hasLength(1));
      expect(
        await titles(
          'live artist:tay',
          fields: {SearchField.comment},
          extra: found,
        ),
        ['A'],
      );
    });

    test('duplicate extra ids are listed and counted once', () async {
      await add('A', comment: 'live');
      final found = await ids('live', comment: true);
      final result = await db.searchSongsFor(
        request('live', {SearchField.comment}),
        extraIds: [...found, ...found],
      );
      expect(result.songs, hasLength(1));
      expect(result.total, 1);
    });

    test('extra ids do not replace a filter-only scan', () async {
      await add('A', year: 2001, comment: 'live');
      await add('B', year: 2001);
      final found = await ids('live', comment: true);
      expect(
        await titles('year:2001', extra: found),
        unorderedEquals(['A', 'B']),
      );
    });
  });
}
