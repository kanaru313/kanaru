import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics/track_local_lyrics_provider.dart';
import 'package:kanaru/core/lyrics/track_lyrics_preview_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'online/status_test_rig.dart';

const _path = '/m/a.flac';
const _lrc = '[00:01.00]side line';

void main() {
  late StatusRig rig;
  final song = fakeSong(_path);
  final target = LyricsTarget.fromTrack(song);

  Future<void> setUpRig({bool withDatabase = true}) async {
    rig = await createStatusRig(withDatabase: withDatabase);
    if (!withDatabase) return;
    final root = await rig.h.db
        .into(rig.h.db.libraryRoots)
        .insert(LibraryRootsCompanion.insert(path: '/m', addedAt: 1));
    await rig.h.db
        .into(rig.h.db.tracks)
        .insert(
          TracksCompanion.insert(
            rootId: root,
            path: _path,
            mtimeMs: 1,
            sizeBytes: 1,
            addedAt: 1,
            updatedAt: 1,
            title: 'Song',
            artist: const Value('Artist'),
            album: const Value('Alb'),
            durationMs: const Value(200000),
          ),
        );
  }

  Future<void> pin(String mode, {bool pick = true}) => rig.h.db.pinLyrics(
    LyricsPinsCompanion.insert(
      trackKey: _path,
      pinnedAt: 1,
      mode: Value(mode),
      providerId: pick ? const Value('fake') : const Value.absent(),
      remoteId: pick ? const Value('pick') : const Value.absent(),
      syncedText: pick
          ? const Value('[00:03.00] picked')
          : const Value.absent(),
    ),
  );

  Future<void> cache() => rig.h.db.saveOnlineLyrics(
    OnlineLyricsCompanion.insert(
      cacheKey: target.cacheKey,
      providerId: 'fake',
      status: 'found',
      remoteId: const Value('cached'),
      syncedText: const Value('[00:04.00] cached'),
      fetchedAt: 1,
    ),
  );

  /// Watches the preview until it has settled and returns it.
  Future<AsyncValue<TrackLyricsPreview?>> preview() async {
    rig.container.listen(trackLyricsPreviewProvider(_path), (_, _) {});
    await rig.until(
      () => !rig.container.read(trackLyricsPreviewProvider(_path)).isLoading,
    );
    return rig.container.read(trackLyricsPreviewProvider(_path));
  }

  String? firstText(AsyncValue<TrackLyricsPreview?> p) =>
      p.requireValue?.lyrics.lines.first.text;

  test('a pick that is usable wins over local lyrics and the cache', () async {
    await setUpRig();
    rig.sidecar.byPath[_path] = _lrc;
    await cache();
    await pin('online');
    final p = await preview();
    expect(firstText(p), 'picked');
    expect(p.requireValue!.kind, TrackLyricsKind.online);
    expect(p.requireValue!.onlineProviderId, 'fake');
  });

  test('.lrc or tags first by the setting', () async {
    await setUpRig();
    rig.sidecar.byPath[_path] = _lrc;
    rig.embedded.byPath[_path] = (text: 'tag line', synced: const []);
    expect(firstText(await preview()), 'side line');
    expect((await preview()).requireValue!.kind, TrackLyricsKind.sidecar);

    rig.container.invalidate(trackLyricsPreviewProvider(_path));
    rig.container
        .read(settingsProvider.notifier)
        .setPlayback(const PlaybackPrefs(preferEmbeddedLyrics: true));
    final p = await preview();
    expect(firstText(p), 'tag line');
    expect(p.requireValue!.kind, TrackLyricsKind.embedded);
  });

  test('a saved online answer is used when the song has none', () async {
    await setUpRig();
    await cache();
    final p = await preview();
    expect(firstText(p), 'cached');
    expect(p.requireValue!.kind, TrackLyricsKind.online);
  });

  test('a miss is no lyrics and no lookup is started', () async {
    await setUpRig();
    final p = await preview();
    expect(p.requireValue, isNull);
    await rig.settle();
    expect(rig.container.exists(autoLyricsLookupProvider(target)), isFalse);
    expect(rig.requests, 0);
    expect(rig.client.opened, 0);
  });

  test('the choice off shows nothing', () async {
    await setUpRig();
    rig.sidecar.byPath[_path] = _lrc;
    await pin('off', pick: false);
    expect((await preview()).requireValue, isNull);
  });

  test('without a library only the song own lyrics count', () async {
    await setUpRig(withDatabase: false);
    expect((await preview()).requireValue, isNull);
    rig.sidecar.byPath[_path] = _lrc;
    rig.container.invalidate(trackLocalLyricsProvider(_path));
    expect(firstText(await preview()), 'side line');
  });

  test('a song that is not in the library has local lyrics only', () async {
    rig = await createStatusRig();
    rig.embedded.byPath[_path] = (
      text: null,
      synced: const [LyricLine(Duration(seconds: 2), 'tag sync')],
    );
    final p = await preview();
    expect(firstText(p), 'tag sync');
    expect(p.requireValue!.lyrics.synced, isTrue);
  });

  group('the same inputs give the same source as Now Playing', () {
    final scenarios = <String, Future<void> Function()>{
      'pick': () async {
        rig.sidecar.byPath[_path] = _lrc;
        await pin('online');
      },
      'sidecar': () async => rig.sidecar.byPath[_path] = _lrc,
      'tags': () async =>
          rig.embedded.byPath[_path] = (text: 'tag line', synced: const []),
      'cache': cache,
      'off': () async {
        rig.sidecar.byPath[_path] = _lrc;
        await pin('off', pick: false);
      },
      'nothing cached or local': () async {},
    };
    for (final MapEntry(:key, :value) in scenarios.entries) {
      test(key, () async {
        await setUpRig();
        await value();
        final mine = await preview();
        rig.watch();
        await rig.play([song]);
        await rig.until(() => rig.status is! LyricsReading);
        // A lookup Now Playing starts for a miss is out of scope here.
        final status = rig.status;
        switch (status) {
          case LyricsFound(:final lyrics, :final origin):
            final found = mine.requireValue!;
            expect(found.lyrics.lines, lyrics.lines);
            expect(found.onlineProviderId, origin?.providerId);
          case _:
            expect(mine.requireValue, isNull);
        }
      });
    }
  });
}
