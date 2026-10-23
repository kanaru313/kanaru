import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_track_links.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/separator_rules.dart';

const _pipe = SplitRules(separators: ['|'], keepWhole: []);

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
  });
  tearDown(() => db.close());

  Future<int> store(String artist, {SplitRules? rules}) async {
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: 1,
        path: '/m/a.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'T',
        artist: Value(artist),
        album: const Value('Al'),
        addedAt: 1,
        updatedAt: 1,
      ),
    ], artistRules: rules ?? defaultArtistRules);
    return (await db.select(db.tracks).getSingle()).id;
  }

  test('links follow the rules the track was keyed with', () async {
    final id = await store('Zed|Ann; Bob', rules: _pipe);
    final links = await db.trackLinks(id);
    expect(links!.artists, [
      (key: 'zed', name: 'Zed'),
      (key: 'ann; bob', name: 'Ann; Bob'),
    ]);
  });

  test('links change with a re-key and keep the tag order', () async {
    final id = await store('Zed|Ann; Bob', rules: _pipe);
    await backfillLibraryKeys(db);
    final links = await db.trackLinks(id);
    expect([for (final a in links!.artists) a.name], ['Zed|Ann', 'Bob']);

    await backfillLibraryKeys(db, rules: _pipe);
    final again = await db.trackLinks(id);
    expect([for (final a in again!.artists) a.name], ['Zed', 'Ann; Bob']);
  });

  test('the order is the tag order, not the key order', () async {
    final id = await store('Zoe; Ann; Mia');
    expect(
      [for (final a in (await db.trackLinks(id))!.artists) a.name],
      ['Zoe', 'Ann', 'Mia'],
    );
  });

  test('a removed track gives null', () async {
    final id = await store('Ann');
    await db.deleteTracksById([id]);
    expect(await db.trackLinks(id), isNull);
  });
}
