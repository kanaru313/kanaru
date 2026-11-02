import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/track_links_provider.dart';

/// Test stand-in for the keys status: [set] flips it.
class _Ready extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}

final _ready = NotifierProvider<_Ready, bool>(_Ready.new);

/// A database that counts its transactions (the album links read in one).
class _CountingDatabase extends LibraryDatabase {
  _CountingDatabase() : super(NativeDatabase.memory());
  var reads = 0;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) {
    reads++;
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  late _CountingDatabase db;
  late int trackId;
  late AlbumKey albumKey;

  setUp(() async {
    db = _CountingDatabase();
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/1.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'T',
        artist: const Value('Ann'),
        album: const Value('Al'),
        addedAt: 1,
        updatedAt: 1,
      ),
    ]);
    trackId = (await db.select(db.tracks).getSingle()).id;
    albumKey = (await db.albums()).single.key;
  });
  tearDown(() => db.close());

  ProviderContainer containerOf() {
    final c = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        keysReadyProvider.overrideWith((ref) => ref.watch(_ready)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('song modal links', () {
    test('stay pending while keys are not ready, load once ready', () async {
      final c = containerOf()..read(_ready.notifier).set(false);
      final sub = c.listen(trackModalLinksProvider(trackId), (_, _) {});
      await idle();
      expect(sub.read().isLoading, isTrue);
      expect(sub.read().hasValue, isFalse);

      c.read(_ready.notifier).set(true);
      final links = await c.read(trackModalLinksProvider(trackId).future);
      expect(links, isNotNull);
      sub.close();
    });

    test('read afresh when keys turn ready again', () async {
      final c = containerOf();
      final sub = c.listen(trackModalLinksProvider(trackId), (_, _) {});
      expect(await c.read(trackModalLinksProvider(trackId).future), isNotNull);

      c.read(_ready.notifier).set(false);
      await idle();
      await db.deleteTracksById([trackId]);
      c.read(_ready.notifier).set(true);
      expect(await c.read(trackModalLinksProvider(trackId).future), isNull);
      sub.close();
    });
  });

  group('album modal links', () {
    test('stay pending while keys are not ready, load once ready', () async {
      final c = containerOf()..read(_ready.notifier).set(false);
      db.reads = 0;
      final sub = c.listen(albumModalLinksProvider(albumKey), (_, _) {});
      await idle();
      expect(sub.read().isLoading, isTrue);
      expect(sub.read().hasValue, isFalse);
      expect(db.reads, 0);

      c.read(_ready.notifier).set(true);
      final links = await c.read(albumModalLinksProvider(albumKey).future);
      expect(links!.artists.map((a) => a.name), ['Ann']);
      expect(db.reads, 1);
      sub.close();
    });

    test('read afresh when keys turn ready again', () async {
      final c = containerOf();
      final sub = c.listen(albumModalLinksProvider(albumKey), (_, _) {});
      expect(await c.read(albumModalLinksProvider(albumKey).future), isNotNull);

      c.read(_ready.notifier).set(false);
      await idle();
      await db.deleteTracksById([trackId]);
      c.read(_ready.notifier).set(true);
      expect(await c.read(albumModalLinksProvider(albumKey).future), isNull);
      sub.close();
    });
  });
}
