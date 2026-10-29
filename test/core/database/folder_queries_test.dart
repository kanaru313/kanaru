import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/folder_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

void main() {
  late LibraryDatabase db;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });
  tearDown(() => db.close());

  Future<void> store(
    List<String> paths, {
    Map<String, String> covers = const {},
  }) => db.upsertTracks([
    for (final path in paths)
      TracksCompanion.insert(
        coverKey: Value(covers[path]),
        rootId: rootId,
        path: path,
        mtimeMs: 1,
        sizeBytes: 1,
        title: path.split('/').last,
        addedAt: 1,
        updatedAt: 1,
      ),
  ]);

  const tricky = [
    '/m/a/1.flac',
    '/m/a b/2.flac',
    '/m/a/sub/3.flac',
    '/m/a0/4.flac',
    '/m/a!/5.flac',
    '/m/a.b/6.flac',
    '/m/a-/7.flac',
    '/m/a /8.flac',
    '/m/Ünï 日本/9.flac',
    '/m/😀 dir/10.flac',
    '/m/😀 dir/deep/er/11.flac',
    '/m/root.song.flac',
  ];

  test(
    'counts the tracks directly in each folder, without a trailing /',
    () async {
      await store(tricky);

      final counts = await db.folderSongCounts();

      expect(
        {for (final c in counts) c.dir: c.count},
        {
          '/m/a': 1,
          '/m/a b': 1,
          '/m/a/sub': 1,
          '/m/a0': 1,
          '/m/a!': 1,
          '/m/a.b': 1,
          '/m/a-': 1,
          '/m/a ': 1,
          '/m/Ünï 日本': 1,
          '/m/😀 dir': 1,
          '/m/😀 dir/deep/er': 1,
          '/m': 1,
        },
      );
    },
  );

  test('counts the same across pages, one folder split over two', () async {
    await store([
      '/m/a/1.flac',
      '/m/a/2.flac',
      '/m/a/3.flac',
      '/m/b/1.flac',
      '/m/b/c/1.flac',
      '/m/b/c/2.flac',
      '/m/z.flac',
    ]);
    final expected = {'/m/a': 3, '/m/b': 1, '/m/b/c': 2, '/m': 1};

    for (final size in [1, 2, 3, 7, 8]) {
      final counts = await db.folderSongCounts(pageSize: size);
      expect(
        {for (final c in counts) c.dir: c.count},
        expected,
        reason: 'page size $size',
      );
    }
  });

  test('counts several tracks of one folder together', () async {
    await store(['/m/x/1.flac', '/m/x/2.flac', '/m/x/y.z.flac']);

    final counts = await db.folderSongCounts();

    expect(counts, [(dir: '/m/x', count: 3, cover: null)]);
  });

  Map<String, String?> coverOf(
    List<({String dir, int count, String? cover})> counts,
  ) => {for (final c in counts) c.dir: c.cover};

  test('the cover is the key most tracks of the folder share', () async {
    await store(
      ['/m/a/1.flac', '/m/a/2.flac', '/m/a/3.flac', '/m/a/4.flac'],
      covers: {
        '/m/a/1.flac': 'k2',
        '/m/a/2.flac': 'k1',
        '/m/a/3.flac': 'k1',
        '/m/a/4.flac': 'k2',
      },
    );
    await store(
      ['/m/b/1.flac', '/m/b/2.flac', '/m/b/3.flac'],
      covers: {'/m/b/1.flac': 'z', '/m/b/3.flac': 'z', '/m/b/2.flac': 'a'},
    );

    final cover = coverOf(await db.folderSongCounts());

    // /m/a ties 2 to 2 and takes the smaller key, /m/b has a clear winner.
    expect(cover, {'/m/a': 'k1', '/m/b': 'z'});
  });

  test('a folder whose tracks have no cover has none', () async {
    await store(
      ['/m/a/1.flac', '/m/a/2.flac', '/m/b/1.flac'],
      covers: {'/m/b/1.flac': 'kb'},
    );

    expect(coverOf(await db.folderSongCounts()), {'/m/a': null, '/m/b': 'kb'});
  });

  test('the cover is the same for every page size', () async {
    await store(
      [
        '/m/a/1.flac',
        '/m/a/2.flac',
        '/m/a/3.flac',
        '/m/b/1.flac',
        '/m/b/2.flac',
        '/m/b/3.flac',
        '/m/b/4.flac',
      ],
      covers: {
        '/m/a/1.flac': 'k2',
        '/m/a/2.flac': 'k1',
        '/m/a/3.flac': 'k2',
        '/m/b/1.flac': 'k3',
        '/m/b/2.flac': 'k4',
        '/m/b/3.flac': 'k4',
        '/m/b/4.flac': 'k3',
      },
    );

    for (final size in [1, 2, 3, 7, 8]) {
      expect(coverOf(await db.folderSongCounts(pageSize: size)), {
        '/m/a': 'k2',
        '/m/b': 'k3',
      }, reason: 'page size $size');
    }
  });

  test('a folder split by a subfolder and a last losing key', () async {
    await store(
      ['/m/a/1.flac', '/m/a/2.flac', '/m/a/sub/1.flac', '/m/a/z.flac'],
      covers: {
        '/m/a/1.flac': 'k1',
        '/m/a/2.flac': 'k1',
        '/m/a/sub/1.flac': 'ks',
        '/m/a/z.flac': 'k2',
      },
    );

    for (final size in [1, 2, 3, 4, 5]) {
      expect(coverOf(await db.folderSongCounts(pageSize: size)), {
        '/m/a': 'k1',
        '/m/a/sub': 'ks',
      }, reason: 'page size $size');
    }
  });

  test(
    'a recursive read takes the folder and all below, nothing beside',
    () async {
      await store(tricky);

      final tracks = await db.folderTracks('/m/a', recursive: true);

      expect(
        [for (final t in tracks) t.path],
        ['/m/a/1.flac', '/m/a/sub/3.flac'],
      );
    },
  );

  test('a direct read leaves the subfolders out', () async {
    await store(tricky);

    final tracks = await db.folderTracks('/m/a', recursive: false);

    expect([for (final t in tracks) t.path], ['/m/a/1.flac']);
  });

  test('the music folder itself reads all of its tracks', () async {
    await store(tricky);

    final all = await db.folderTracks('/m', recursive: true);
    final direct = await db.folderTracks('/m', recursive: false);

    expect(all, hasLength(tricky.length));
    expect([for (final t in direct) t.path], ['/m/root.song.flac']);
  });

  test('Unicode and emoji folders read their subtree', () async {
    await store(tricky);

    final emoji = await db.folderTracks('/m/😀 dir', recursive: true);
    final unicode = await db.folderTracks('/m/Ünï 日本', recursive: false);

    expect(
      [for (final t in emoji) t.path],
      ['/m/😀 dir/10.flac', '/m/😀 dir/deep/er/11.flac'],
    );
    expect([for (final t in unicode) t.path], ['/m/Ünï 日本/9.flac']);
  });

  test('tracks come in database order, by path', () async {
    await store(['/m/d/b.flac', '/m/d/CD 10/1.flac', '/m/d/CD 2/1.flac']);

    final tracks = await db.folderTracks('/m/d', recursive: true);

    expect(
      [for (final t in tracks) t.path],
      ['/m/d/CD 10/1.flac', '/m/d/CD 2/1.flac', '/m/d/b.flac'],
    );
  });

  test('an unknown folder reads nothing', () async {
    await store(tricky);

    expect(await db.folderTracks('/m/nope', recursive: true), isEmpty);
    expect(await db.folderTracks('/m/a/su', recursive: true), isEmpty);
  });
}
