import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/database/text_keys.dart';

const _pipe = SplitRules(separators: ['|'], keepWhole: []);
const _pipeKeep = SplitRules(separators: ['|'], keepWhole: ['A|B']);

Future<Map<int, List<String>>> _credits(LibraryDatabase db) async {
  final out = <int, List<String>>{};
  final rows = await db
      .customSelect(
        'SELECT track_id, artist_name FROM track_artists ORDER BY rowid',
      )
      .get();
  for (final r in rows) {
    (out[r.read<int>('track_id')] ??= []).add(r.read<String>('artist_name'));
  }
  return out;
}

Future<List<int>> _versions(LibraryDatabase db) async => [
  for (final r
      in await db
          .customSelect('SELECT keys_version AS v FROM tracks ORDER BY id')
          .get())
    r.read<int>('v'),
];

TracksCompanion _track(int n, String artist, {String? albumArtist}) =>
    TracksCompanion.insert(
      rootId: 1,
      path: '/m/$n.flac',
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T$n',
      artist: Value(artist),
      album: const Value('Album'),
      albumArtist: Value(albumArtist),
      addedAt: 1,
      updatedAt: 1,
    );

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
  });
  tearDown(() => db.close());

  test('a scan with custom rules stores their keys and version', () async {
    await db.upsertTracks([_track(1, 'A|B; C feat. D')], artistRules: _pipe);

    expect(await _credits(db), {
      1: ['A', 'B; C feat. D'],
    });
    expect(await _versions(db), [keysVersionFor(_pipe)]);
    expect(keysVersionFor(_pipe), isNot(textKeysVersion));
  });

  test('a scan with the default rules keeps the plain version', () async {
    await db.upsertTracks([_track(1, 'A; B')]);
    expect(await _versions(db), [textKeysVersion]);
    expect(await _credits(db), {
      1: ['A', 'B'],
    });
  });

  test('changing the rules makes every row stale, and back again', () async {
    await db.upsertTracks([
      _track(1, 'A|B; C'),
      _track(2, 'X feat. Y', albumArtist: 'P|Q'),
    ]);
    expect(await countStaleKeys(db, textKeysVersion), 0);
    expect(await countStaleKeys(db, keysVersionFor(_pipe)), 2);

    final progress = <(int, int)>[];
    final n = await backfillLibraryKeys(
      db,
      rules: _pipe,
      chunkSize: 1,
      onProgress: (d, t) => progress.add((d, t)),
    );

    expect(n, 2);
    expect(progress.first, (0, 2));
    expect(progress.last, (2, 2));
    expect(await _credits(db), {
      1: ['A', 'B; C'],
      2: ['X feat. Y'],
    });
    expect(await _versions(db), everyElement(keysVersionFor(_pipe)));
    expect(await countStaleKeys(db, keysVersionFor(_pipe)), 0);
    final key =
        (await db
                .customSelect(
                  'SELECT album_artist_key AS k FROM tracks WHERE id = 2',
                )
                .getSingle())
            .read<String>('k');
    expect(key, contains('p'));
    expect(key, contains('q'));

    // Back to the defaults: the rows differ in version again, though the new
    // version is smaller than the one they carry.
    expect(await countStaleKeys(db, textKeysVersion), 2);
    await backfillLibraryKeys(db);
    expect(await _versions(db), everyElement(textKeysVersion));
    expect(await _credits(db), {
      1: ['A|B', 'C'],
      2: ['X', 'Y'],
    });
  });

  test('rules that only differ in order or case need no re-key', () async {
    await db.upsertTracks([_track(1, 'A|B')], artistRules: _pipeKeep);
    const same = SplitRules(separators: [' | '], keepWhole: ['a|b']);
    expect(await countStaleKeys(db, keysVersionFor(same)), 0);
  });

  test('keep-whole names change the credits', () async {
    await db.upsertTracks([_track(1, 'A|B|C')], artistRules: _pipeKeep);
    expect(await _credits(db), {
      1: ['A|B', 'C'],
    });
  });

  test('a row another version wrote is overwritten, once', () async {
    await db.upsertTracks([_track(1, 'A|B')], artistRules: _pipe);
    await db.customStatement('UPDATE tracks SET keys_version = 999999999');
    expect(await backfillLibraryKeys(db, rules: _pipe), 1);
    expect(await backfillLibraryKeys(db, rules: _pipe), 0);
  });

  test(
    'a row changed while the chunk was read keeps its old version',
    () async {
      await db.upsertTracks([_track(1, 'A|B')]);
      final n = await backfillLibraryKeys(
        db,
        rules: _pipe,
        afterRead: () => db.customStatement("UPDATE tracks SET artist = 'Z|Q'"),
      );
      expect(n, 1);
      expect(await _versions(db), [textKeysVersion]);
    },
  );
}
