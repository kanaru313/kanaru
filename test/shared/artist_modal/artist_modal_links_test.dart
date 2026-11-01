import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_links.dart';

/// A database whose reads are counted and can be made to fail.
class _CountingDatabase extends LibraryDatabase {
  _CountingDatabase({this.fail = true}) : super(NativeDatabase.memory());
  var reads = 0;

  /// Fails every read when true; otherwise counts and passes through.
  final bool fail;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) {
    reads++;
    if (!fail) return super.transaction(action, requireNew: requireNew);
    return Future.error(StateError('read failed'));
  }
}

/// Test stand-in for the keys status: [ready] flips it.
class _Ready extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}

final _ready = NotifierProvider<_Ready, bool>(_Ready.new);

void main() {
  late _CountingDatabase db;
  late int rootId;
  var next = 0;

  setUp(() async {
    db = _CountingDatabase(fail: false);
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    String title, {
    String artist = 'Ann',
    String? album,
    String? albumArtist,
    int? year,
    String? path,
  }) async {
    final n = next++;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: path ?? '/m/$n.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: title,
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(albumArtist),
        year: Value(year),
        addedAt: 1,
        updatedAt: 1,
      ),
    ]);
  }

  ProviderContainer containerOf(LibraryDatabase? database) {
    final c = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(database),
        keysReadyProvider.overrideWith((ref) => ref.watch(_ready)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ArtistLinks?> read(ProviderContainer c, [String key = 'ann']) =>
      (c..listen(artistModalLinksProvider(key), (_, _) {})).read(
        artistModalLinksProvider(key).future,
      );

  test(
    'splits own albums and appears-on like the page, songs in page order',
    () async {
      // Page order (by year, appears-on last) differs from title order and
      // from the database order (album artist key, album title key: Mid,
      // Zulu, Alpha).
      await store('Zulu', album: 'Early', albumArtist: 'Ann', year: 2005);
      await store('Alpha', album: 'Late', albumArtist: 'Ann', year: 2000);
      await store(
        'Mid',
        artist: 'X; Ann',
        album: 'Theirs',
        albumArtist: 'Aaron',
      );
      final links = (await read(containerOf(db)))!;

      expect(links.sections.name, 'Ann');
      expect(links.sections.albums.map((a) => a.title).toSet(), {
        'Early',
        'Late',
      });
      expect(links.sections.appearsOn.map((a) => a.title), ['Theirs']);
      final titles = links.sections.songs.map((t) => t.title).toList();
      expect(titles, ['Alpha', 'Zulu', 'Mid']);
    },
  );

  test('one folder', () async {
    await store('a', path: '/m/Rock/1.flac');
    await store('b', path: '/m/Rock/2.flac');
    final folders = (await read(containerOf(db)))!.folders;
    expect(folders.map((f) => (f.path, f.songCount)), [('/m/Rock', 2)]);
  });

  test(
    'folders sorted by song count then path; remote paths skipped',
    () async {
      await store('a', path: '/m/B/1.flac');
      await store('b', path: '/m/A/1.flac');
      await store('c', path: '/m/C/1.flac');
      await store('d', path: '/m/C/2.flac');
      await store('e', path: 'http://x/y/1.mp3');
      final folders = (await read(containerOf(db)))!.folders;
      expect(folders.map((f) => (f.path, f.songCount)), [
        ('/m/C', 2),
        ('/m/A', 1),
        ('/m/B', 1),
      ]);
    },
  );

  test('unknown artist key reads null', () async {
    await store('a');
    expect(await read(containerOf(db), 'nobody'), isNull);
  });

  test('no library reads null', () async {
    expect(await read(containerOf(null)), isNull);
  });

  test('stays pending while keys are not ready, loads once ready', () async {
    await store('a');
    final c = containerOf(db);
    db.reads = 0;
    c.read(_ready.notifier).set(false);
    final sub = c.listen(artistModalLinksProvider('ann'), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sub.read().isLoading, isTrue);
    expect(sub.read().hasValue, isFalse);
    expect(db.reads, 0);

    c.read(_ready.notifier).set(true);
    final links = await c.read(artistModalLinksProvider('ann').future);
    expect(links!.sections.songs, hasLength(1));
    expect(db.reads, 1);
  });

  test('a failing read is an error and is not retried', () async {
    final failing = _CountingDatabase();
    addTearDown(failing.close);
    final c = containerOf(failing);
    final sub = c.listen(artistModalLinksProvider('ann'), (_, _) {});
    await expectLater(
      c.read(artistModalLinksProvider('ann').future),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(failing.reads, 1);
    expect(sub.read().hasError, isTrue);
  });
}
