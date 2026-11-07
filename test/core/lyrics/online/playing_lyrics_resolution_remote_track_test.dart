import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';

import 'status_test_rig.dart';

const _ref = RemoteSourceRef(installId: 'plugin-abcdefghijkl', itemId: 'vid/1');

Track _remoteTrack() => Track(
  uri: remoteTrackUri(_ref),
  title: 'Remote song',
  artist: 'Artist',
  duration: const Duration(seconds: 200),
  remote: _ref,
);

void main() {
  late StatusRig rig;
  var pinReads = 0;
  var targetReads = 0;
  var cacheReads = 0;

  // A library is open, but any read of a pin, target or cache row is counted.
  Future<void> start() async {
    pinReads = targetReads = cacheReads = 0;
    rig = await createStatusRig(
      overrides: [
        lyricsPinProvider.overrideWith((ref, key) {
          pinReads++;
          return Stream.value(null);
        }),
        lyricsTargetProvider.overrideWith((ref) {
          targetReads++;
          return Stream<LyricsTarget?>.value(null);
        }),
        onlineLyricsCacheProvider.overrideWith((ref, key) {
          cacheReads++;
          return Stream.value(const []);
        }),
      ],
    );
  }

  test('a remote track shows no lyrics with no read and no lookup', () async {
    await start();
    rig.watch();
    await rig.play([_remoteTrack()]);
    await rig.until(() => rig.status is LyricsNone);
    await rig.settle();

    final none = rig.status as LyricsNone;
    expect(none.uri, remoteTrackUri(_ref));
    expect(none.reason, LyricsNoneReason.noLyrics);
    // Never a transient "reading" or "searching" state.
    expect(rig.statuses.whereType<LyricsReading>(), isEmpty);
    expect(rig.statuses.whereType<LyricsSearching>(), isEmpty);
    expect(pinReads, 0);
    expect(targetReads, 0);
    expect(cacheReads, 0);
    expect(rig.sidecar.reads, isEmpty);
    expect(rig.embedded.reads, isEmpty);
    expect(rig.requests, 0);
    final resolution = rig.container.read(playingLyricsResolutionProvider)!;
    expect(resolution.hasLocal, isFalse);
    expect(resolution.pin, isNull);
  });

  test('a local track after a remote one is resolved as before', () async {
    rig = await createStatusRig();
    rig.sidecar.byPath['/m/a.flac'] = '[00:00.00]local';
    rig.watch();
    await rig.play([_remoteTrack(), fakeSong('/m/a.flac')]);
    await rig.until(() => rig.status is LyricsNone);
    await rig.player.next();
    await rig.until(() => rig.status is LyricsFound);

    expect((rig.status as LyricsFound).uri, '/m/a.flac');
    expect(rig.requests, 0);
    expect(rig.sidecar.reads, ['/m/a.flac']);
  });
}
