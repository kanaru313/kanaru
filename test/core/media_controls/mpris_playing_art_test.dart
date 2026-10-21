import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/playing_track_art.dart';
import 'package:kanaru/core/player/track.dart';

import '../indexer/fake_tag_reader.dart';
import 'mpris_test_harness.dart';

const _covers = '/covers';

String _cover(String name) => '$_covers/${fakeCoverKey(name)}';

String _url(String name) => Uri.file(_cover(name)).toString();

void main() {
  late MprisHarness h;
  late LibraryDatabase db;

  /// The harness with a library holding [songs] and covers on.
  Future<void> setUpWith([List<Override> overrides = const []]) async {
    db = LibraryDatabase(NativeDatabase.memory());
    final rootId = (await db.addRoots(['/music'], now: 1)).single;
    await db.upsertTracks([
      for (final song in songs)
        TracksCompanion.insert(
          rootId: rootId,
          path: song.uri,
          mtimeMs: 1,
          sizeBytes: 1,
          title: song.title,
          addedAt: 1,
          updatedAt: 1,
        ),
    ]);
    h = MprisHarness();
    await h.setUp(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        coverCacheDirectoryProvider.overrideWithValue(_covers),
        ...overrides,
      ],
    );
  }

  tearDown(() async {
    await h.tearDown();
    await db.close();
  });

  /// Stores [name]'s cover for [track] and notifies once, as a cover pass
  /// batch does.
  Future<void> setCover(Track track, String name) async {
    await db.customStatement('UPDATE tracks SET cover_key = ? WHERE path = ?', [
      fakeCoverKey(name),
      track.uri,
    ]);
    db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
  }

  Future<Map<String, DBusValue>> metadata() async =>
      (await h.remote.getProperty(
        mprisPlayerInterface,
        'Metadata',
      )).asStringVariantDict();

  test('a cover written for the playing track keeps its track id', () async {
    await setUpWith();
    await h.service.openTracks(songs);
    await h.start();
    await h.settle();
    final before = await metadata();
    expect(before.containsKey('mpris:artUrl'), isFalse);
    final changes = await h.watchChanges();

    await h.changeAfter(() => setCover(songs[0], 'a'));

    expect(changes, hasLength(1));
    final sent = changes.single['Metadata']!.asStringVariantDict();
    expect(sent['mpris:artUrl'], DBusString(_url('a')));
    expect(sent['mpris:trackid'], before['mpris:trackid']);
    final now = await metadata();
    expect(now['mpris:artUrl'], DBusString(_url('a')));
  });

  group('before the first lookup returns', () {
    // The lookup never returns.
    final pending = StreamController<({String? coverKey})?>.broadcast();
    tearDownAll(pending.close);

    Future<Map<String, DBusValue>> startWith(String? art) async {
      await setUpWith([
        libraryCoverKeyProvider.overrideWith((ref, path) => pending.stream),
      ]);
      await h.service.openTracks([
        Track(uri: songs[0].uri, title: 'a', artUri: art),
      ]);
      await h.start();
      return metadata();
    }

    test('one of our thumbnails is published', () async {
      final m = await startWith(_cover('stale'));
      expect(m['mpris:artUrl'], DBusString(_url('stale')));
    });

    test('other art is left out, without an error', () async {
      final m = await startWith('/elsewhere/cover.jpg');
      expect(m.containsKey('mpris:artUrl'), isFalse);
      expect(m['xesam:title'], const DBusString('a'));
    });
  });

  test('a signal never pairs the next track with the previous art', () async {
    await setUpWith();
    await setCover(songs[0], 'a');
    await setCover(songs[1], 'b');
    await h.service.openTracks(songs);
    await h.start();
    await h.settle();
    // The art provider has rebuilt once for the first track's cover.
    expect((await metadata())['mpris:artUrl'], DBusString(_url('a')));
    final changes = await h.watchChanges();

    await h.changeAfter(() => h.service.next());
    await h.settle();

    final now = await metadata();
    expect(now['xesam:title'], const DBusString('b'));
    expect(now['mpris:artUrl'], DBusString(_url('b')));
    final sent = [
      for (final change in changes)
        if (change['Metadata'] case final m?) m.asStringVariantDict(),
    ];
    expect(sent, isNotEmpty);
    for (final m in sent) {
      expect(m['mpris:trackid'], now['mpris:trackid']);
      expect(m['mpris:artUrl'], isNot(DBusString(_url('a'))));
    }
  });
}
