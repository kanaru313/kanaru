import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/shared/genre_modal/genre_modal_links.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/library_route_keys.dart';

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

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = _CountingDatabase(fail: false);
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    String title, {
    String? genre,
    String? artist = 'Ann',
    String? album,
    String? albumArtist,
    int? year,
    String? path,
    int? durationMs,
  }) async {
    final n = next++;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: path ?? '/m/$n.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: title,
        genre: Value(genre),
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(albumArtist),
        year: Value(year),
        durationMs: Value(durationMs),
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

  Future<GenreLinks?> read(ProviderContainer c, GenreSummary genre) =>
      (c..listen(genreModalLinksProvider(genre), (_, _) {})).read(
        genreModalLinksProvider(genre).future,
      );

  test('loads albums, tracks, folders, and durationMs for a standard genre', () async {
    await store(
      'Zulu',
      genre: 'Rock',
      album: 'Late',
      albumArtist: 'Ann',
      year: 2005,
      path: '/m/Rock/1.flac',
      durationMs: 120000,
    );
    await store(
      'Alpha',
      genre: 'Rock',
      album: 'Early',
      albumArtist: 'Ann',
      year: 2000,
      path: '/m/Rock/2.flac',
      durationMs: 80000,
    );
    await store(
      'Extra',
      genre: 'Rock',
      album: 'Early',
      albumArtist: 'Ann',
      year: 2000,
      path: '/m/Other/1.flac',
      durationMs: 40000,
    );
    await store(
      'OtherGenre',
      genre: 'Jazz',
      album: 'JazzAlbum',
      durationMs: 50000,
    );

    const genre = GenreSummary(
      key: 'rock',
      name: 'Rock',
      songCount: 3,
      raws: ['Rock'],
    );
    final links = (await read(containerOf(db), genre))!;

    // Albums sorted by genreAlbumsSort (title ascending: Early, Late).
    expect(links.albums.map((a) => a.title), ['Early', 'Late']);

    // Tracks sorted by title_sort, id.
    expect(links.tracks.map((t) => t.title), ['Alpha', 'Extra', 'Zulu']);

    // Folders sorted by song count descending, then path.
    expect(links.folders.map((f) => (f.path, f.songCount)), [
      ('/m/Rock', 2),
      ('/m/Other', 1),
    ]);

    // Total duration across tracks.
    expect(links.durationMs, 240000);
  });

  test('durationMs is null when all tracks have null duration', () async {
    await store('Song1', genre: 'Rock');
    await store('Song2', genre: 'Rock');

    const genre = GenreSummary(
      key: 'rock',
      name: 'Rock',
      songCount: 2,
      raws: ['Rock'],
    );
    final links = (await read(containerOf(db), genre))!;
    expect(links.durationMs, isNull);
  });

  test('supports unknownGenreKey with withoutGenre: true and tracks with no genre', () async {
    await store(
      'NoTag',
      genre: null,
      album: 'UnknownAlbum',
      path: '/m/NoGenre/1.flac',
      durationMs: 60000,
    );
    await store(
      'HasGenre',
      genre: 'Pop',
      album: 'PopAlbum',
      path: '/m/Pop/1.flac',
      durationMs: 90000,
    );

    const unknownGenre = GenreSummary(
      key: unknownGenreKey,
      name: '',
      songCount: 1,
      raws: [],
      withoutGenre: true,
    );
    final links = (await read(containerOf(db), unknownGenre))!;

    expect(links.albums.map((a) => a.title), ['UnknownAlbum']);
    expect(links.tracks.map((t) => t.title), ['NoTag']);
    expect(links.folders.map((f) => (f.path, f.songCount)), [
      ('/m/NoGenre', 1),
    ]);
    expect(links.durationMs, 60000);
  });

  test('returns null when genre has no tracks (gone / empty state)', () async {
    await store('Track', genre: 'Rock');

    const goneGenre = GenreSummary(
      key: 'jazz',
      name: 'Jazz',
      songCount: 0,
      raws: ['Jazz'],
    );
    expect(await read(containerOf(db), goneGenre), isNull);
  });

  test('no library reads null', () async {
    const genre = GenreSummary(
      key: 'rock',
      name: 'Rock',
      songCount: 1,
      raws: ['Rock'],
    );
    expect(await read(containerOf(null), genre), isNull);
  });

  test('stays pending while keys are not ready, loads once ready', () async {
    await store('Track', genre: 'Rock');
    final c = containerOf(db);
    db.reads = 0;
    c.read(_ready.notifier).set(false);

    const genre = GenreSummary(
      key: 'rock',
      name: 'Rock',
      songCount: 1,
      raws: ['Rock'],
    );
    final sub = c.listen(genreModalLinksProvider(genre), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sub.read().isLoading, isTrue);
    expect(sub.read().hasValue, isFalse);
    expect(db.reads, 0);

    c.read(_ready.notifier).set(true);
    final links = await c.read(genreModalLinksProvider(genre).future);
    expect(links!.tracks, hasLength(1));
    expect(db.reads, 1);
  });

  test('a failing read is an error and is not retried', () async {
    final failing = _CountingDatabase();
    addTearDown(failing.close);
    final c = containerOf(failing);

    const genre = GenreSummary(
      key: 'rock',
      name: 'Rock',
      songCount: 1,
      raws: ['Rock'],
    );
    final sub = c.listen(genreModalLinksProvider(genre), (_, _) {});
    await expectLater(
      c.read(genreModalLinksProvider(genre).future),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(failing.reads, 1);
    expect(sub.read().hasError, isTrue);
  });
}
