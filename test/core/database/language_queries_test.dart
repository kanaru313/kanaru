import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/language_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/shared/language_summaries.dart';

import '../stats/gated_query_interceptor.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;
  var next = 0;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    String title, {
    String? language,
    String? album,
    String? albumArtist,
  }) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: '/m/${next++}.flac',
      mtimeMs: 1,
      sizeBytes: 1,
      title: title,
      language: Value(language),
      album: Value(album),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    ),
  ]);

  test('counts every stored string and skips untagged tracks', () async {
    await store('a', language: 'eng');
    await store('b', language: 'eng');
    await store('c', language: 'en');
    await store('d');

    final counts = await db.languageCounts();

    expect({for (final c in counts) c.raw: c.count}, {'eng': 2, 'en': 1});
  });

  test('tracks of the given strings come by title', () async {
    await store('b', language: 'eng');
    await store('a', language: 'en');
    await store('c', language: 'vie');
    await store('d');

    final tracks = await db.languageTracks(['eng', 'en']);

    expect([for (final t in tracks) t.title], ['a', 'b']);
  });

  test('albums are summed over all their tracks', () async {
    await store('e', language: 'eng', album: 'Mixed', albumArtist: 'X');
    await store('v', language: 'vie', album: 'Mixed', albumArtist: 'X');
    await store('o', language: 'vie', album: 'Other', albumArtist: 'X');
    await store('n', language: 'eng');

    final albums = await db.languageAlbums(['eng']);

    expect([for (final a in albums) a.title], ['Mixed']);
    expect(albums.single.trackCount, 2);
  });

  test('no strings give nothing and run no SQL', () async {
    await db.close();
    final gate = GatedQueryInterceptor();
    db = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    await store('a', language: 'eng');
    final before = gate.statements.length;

    expect(await db.languageTracks(const []), isEmpty);
    expect(await db.languageAlbums(const []), isEmpty);

    expect(gate.statements.length, before, reason: 'no statement was run');
  });

  test('strings with SQL or JSON characters are only values', () async {
    await store('a', language: 'x"\'; --');

    expect(await db.languageTracks(['x"\'; --']), hasLength(1));
    expect(await db.languageTracks(["x\"'"]), isEmpty);
  });

  test('more strings than SQLite has variables still work', () async {
    await store('a', language: 'l0');
    final raws = [for (var i = 0; i < 5000; i++) 'l$i'];

    expect(await db.languageTracks(raws), hasLength(1));
    expect(await db.languageAlbums(raws), isEmpty);
  });

  test('a summary count matches the tracks its strings reach', () async {
    await store('a', language: 'eng');
    await store('b', language: 'en-US');
    await store('c', language: 'eng; vie');
    await store('d', language: 'vie');
    await store('e', language: 'und');
    await store('f');

    final rows = buildLanguageSummaries(await db.languageCounts());

    expect({for (final r in rows) r.key: r.songCount}, {'eng': 3, 'vie': 2});
    for (final row in rows) {
      expect(
        await db.languageTracks(row.raws),
        hasLength(row.songCount),
        reason: row.key,
      );
    }
  });
}
