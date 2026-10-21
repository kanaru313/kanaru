import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/cover_pass.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/playing_track_art.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:logging/logging.dart';

import '../indexer/fake_tag_reader.dart';
import 'fake_audio_backend.dart';

/// A library track `/m/<name>` as the library screens queue it.
Track song(String name, {String? artUri}) =>
    Track(uri: '/m/$name', title: name, artUri: artUri);

void main() {
  late Directory tmp;
  late String covers;
  late LibraryDatabase db;
  late int rootId;
  late FakeAudioBackend backend;
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kanaru_playing_art_');
    covers = '${tmp.path}/covers';
    db = LibraryDatabase(NativeDatabase.memory());
    rootId = (await db.addRoots(['/m'], now: 1)).single;
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// A player with the library and covers on, unless [library] or [coverDir]
  /// say otherwise.
  ProviderContainer launch({
    bool library = true,
    bool coverDir = true,
    List<Override> overrides = const [],
  }) {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        if (library) libraryDatabaseProvider.overrideWithValue(db),
        if (coverDir) coverCacheDirectoryProvider.overrideWithValue(covers),
        ...overrides,
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    return container;
  }

  PlayerService service() => container.read(playerServiceProvider.notifier);

  /// Every art value the player bar would see, in order.
  List<String?> follow() {
    final seen = <String?>[];
    container.listen(
      playingTrackArtProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );
    return seen;
  }

  String? art() => container.read(playingTrackArtProvider);

  Future<void> settle() => pumpEventQueue();

  String coverOf(String name) => '$covers/${fakeCoverKey(name)}';

  /// Stores library tracks `/m/<name>`, with [key] as their cover key.
  Future<void> add(Iterable<String> names, {String? key}) => db.upsertTracks([
    for (final name in names)
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/$name',
        mtimeMs: 1,
        sizeBytes: 1,
        title: name,
        addedAt: 1,
        updatedAt: 1,
        coverKey: Value(key),
      ),
  ]);

  /// Writes a cover key without notifying, then notifies once, as a cover
  /// pass batch does.
  Future<void> setCover(String name, String? key) async {
    await db.customStatement('UPDATE tracks SET cover_key = ? WHERE path = ?', [
      key,
      '/m/$name',
    ]);
    db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
    await settle();
  }

  test('a cover made after the track was queued shows', () async {
    await add(['a.mp3']);
    launch();
    await service().openTracks([song('a.mp3')]);
    final seen = follow();
    await settle();
    expect(art(), isNull);

    await setCover('a.mp3', fakeCoverKey('a'));
    expect(art(), coverOf('a'));
    expect(seen.last, coverOf('a'));
  });

  test('the real cover pass shows the cover of the playing track', () async {
    await add(['a.mp3', 'b.mp3']);
    launch();
    await service().openTracks([song('a.mp3'), song('b.mp3')]);
    follow();
    await settle();
    expect(art(), isNull);

    final reader = FakeTagReader()
      ..coverDirectory = covers
      ..coverByName['a.mp3'] = 'a';
    await runCoverPass(
      db: db,
      reader: reader,
      rootIds: [rootId],
      progress: CoverPassProgress(),
      timeout: const Duration(seconds: 5),
      shouldYield: () => false,
      shouldStop: () => false,
      onStuck: (_) {},
    );
    await settle();
    expect(art(), coverOf('a'));
    expect(File(art()!).existsSync(), isTrue);
  });

  test('a replaced cover moves to the new key, never back', () async {
    await add(['a.mp3'], key: fakeCoverKey('old'));
    File(coverOf('old')).createSync(recursive: true);
    launch();
    await service().openTracks([song('a.mp3', artUri: coverOf('old'))]);
    final seen = follow();
    await settle();
    expect(art(), coverOf('old'));

    // A rescan keeps the old key until the cover pass replaces it.
    File(coverOf('new')).createSync(recursive: true);
    await setCover('a.mp3', fakeCoverKey('new'));
    expect(art(), coverOf('new'));

    // A later scan's cleanup deletes the old thumbnail.
    File(coverOf('old')).deleteSync();
    db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
    await settle();
    expect(art(), coverOf('new'));
    expect(
      seen.skipWhile((a) => a != coverOf('new')),
      everyElement(coverOf('new')),
    );
  });

  test(
    'a cover cleared in the library gives no art, not the snapshot',
    () async {
      await add(['a.mp3'], key: fakeCoverKey('a'));
      launch();
      await service().openTracks([song('a.mp3', artUri: coverOf('a'))]);
      follow();
      await settle();
      expect(art(), coverOf('a'));

      await setCover('a.mp3', null);
      expect(art(), isNull);
    },
  );

  test('the next track is looked up when it becomes current', () async {
    await add(['a.mp3']);
    await add(['b.mp3'], key: fakeCoverKey('b'));
    await add(['c.mp3'], key: fakeCoverKey('c'));
    launch();
    await service().openTracks([song('a.mp3'), song('b.mp3'), song('c.mp3')]);
    follow();
    await settle();
    expect(art(), isNull);

    await service().next();
    await settle();
    expect(art(), coverOf('b'));

    backend.advance();
    await settle();
    expect(container.read(playerServiceProvider).queue.current, song('c.mp3'));
    expect(art(), coverOf('c'));
  });

  group('before the first lookup returns', () {
    Future<String?> firstFrame(String? snapshot) async {
      await add(['a.mp3'], key: fakeCoverKey('a'));
      launch();
      await service().openTracks([song('a.mp3', artUri: snapshot)]);
      // The first read starts the lookup; its result comes later.
      final first = art();
      follow();
      await settle();
      expect(art(), coverOf('a'));
      return first;
    }

    test('a thumbnail in the covers folder is shown', () async {
      expect(await firstFrame(coverOf('stale')), coverOf('stale'));
    });

    test('art outside the covers folder is not', () async {
      expect(await firstFrame('/elsewhere/cover.jpg'), isNull);
    });

    test('a malformed key in the covers folder is not', () async {
      expect(await firstFrame('$covers/zz/../../x.jpg'), isNull);
    });
  });

  test('a track outside the library keeps its own art', () async {
    launch();
    await service().openTracks([
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artUri: '/x.jpg'),
    ]);
    follow();
    await settle();
    expect(art(), '/x.jpg');
  });

  test('a file uri of a library path is looked up', () async {
    await add(['a b.mp3'], key: fakeCoverKey('a'));
    launch();
    await service().openTracks([
      const Track(uri: 'file:///m/a%20b.mp3', title: 'a'),
    ]);
    follow();
    await settle();
    expect(art(), coverOf('a'));
  });

  test('uris without a local path fall back without an error', () async {
    expect(localPathOf('/m/a.mp3'), '/m/a.mp3');
    expect(localPathOf('file:///m/a.mp3'), '/m/a.mp3');
    for (final uri in [
      'file://host/a.mp3',
      'file:///a%2Fb.mp3',
      'http://127.0.0.1:1/t?token=x',
      '::not a uri::',
      'relative/a.mp3',
    ]) {
      expect(localPathOf(uri), isNull, reason: uri);
    }

    launch();
    final seen = follow();
    for (final uri in ['file://host/a.mp3', 'file:///a%2Fb.mp3', ':%:']) {
      await service().openTracks([
        Track(uri: uri, title: uri, artUri: '/x.jpg'),
      ]);
      await settle();
      expect(art(), '/x.jpg', reason: uri);
    }
    expect(seen, everyElement(anyOf(isNull, '/x.jpg')));
  });

  test('a restored session shows the library covers', () async {
    await add(['a.mp3'], key: fakeCoverKey('a'));
    await add(['b.mp3'], key: fakeCoverKey('b'));
    final file = PlaybackSessionFile('${tmp.path}/playback-session.json');
    final tracks = [song('a.mp3'), song('b.mp3', artUri: '/gone/old.jpg')];
    await file.save(
      PlaybackSession(tracks: tracks, order: const [0, 1], index: 1),
    );
    await file.flush();

    launch(
      overrides: [
        settingsFileProvider.overrideWithValue(
          SettingsFile('${tmp.path}/settings.json'),
        ),
      ],
    );
    follow();
    await settle();
    final queue = container.read(playerServiceProvider).queue;
    expect(queue.current, song('b.mp3'));
    expect(art(), coverOf('b'));
    expect(queue.original.map((t) => t.artUri), [null, '/gone/old.jpg']);
  });

  test('covers off: the queued art, no lookup', () async {
    await add(['a.mp3'], key: fakeCoverKey('a'));
    launch(coverDir: false);
    await service().openTracks([song('a.mp3', artUri: '/x.jpg')]);
    follow();
    await settle();
    expect(art(), '/x.jpg');
    expect(container.exists(libraryCoverKeyProvider('/m/a.mp3')), isFalse);
  });

  test('no library: the queued art, no lookup', () async {
    launch(library: false);
    await service().openTracks([song('a.mp3', artUri: '/x.jpg')]);
    follow();
    await settle();
    expect(art(), '/x.jpg');
    expect(container.exists(libraryCoverKeyProvider('/m/a.mp3')), isFalse);
  });

  test('covers on: the playing track is looked up', () async {
    await add(['a.mp3']);
    launch();
    await service().openTracks([song('a.mp3')]);
    follow();
    await settle();
    expect(container.exists(libraryCoverKeyProvider('/m/a.mp3')), isTrue);
  });

  test('a failing lookup keeps the last art, logs once, no loop', () async {
    final logs = <LogRecord>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord
        .where((r) => r.loggerName == 'playing_art')
        .listen(logs.add);
    addTearDown(() {
      Logger.root.level = previousLevel;
      return sub.cancel();
    });

    await add(['a.mp3'], key: fakeCoverKey('a'));
    launch();
    await service().openTracks([song('a.mp3')]);
    follow();
    await settle();
    expect(art(), coverOf('a'));

    await db.customStatement('DROP TABLE tracks');
    for (var i = 0; i < 3; i++) {
      db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
      await settle();
    }
    expect(art(), coverOf('a'));
    expect(logs, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(logs, hasLength(1), reason: 'no retry loop');
  });

  test('a track change during a lookup never shows the old art', () async {
    await add(['a.mp3'], key: fakeCoverKey('a'));
    await add(['b.mp3']);
    launch();
    await service().openTracks([song('a.mp3'), song('b.mp3')]);
    final pairs = <(Track?, String?)>[];
    container.listen(
      playingTrackArtProvider,
      (_, next) => pairs.add((
        container.read(playerServiceProvider).queue.current,
        next,
      )),
      fireImmediately: true,
    );
    // A's lookup has started, not returned.
    await service().next();
    await settle();
    expect(art(), isNull);
    expect(pairs, isNot(contains((song('b.mp3'), coverOf('a')))));
  });
}
