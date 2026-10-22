import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/album_run_lookup.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/player/replay_gain_sync.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';

import 'audio_sync_test_support.dart';
import 'fake_audio_backend.dart';

void main() {
  late FakeAudioBackend fake;
  late List<List<String>> lookups;
  late AlbumRunKeyLookup lookup;
  late ReplayGainSync sync;
  var turn = 0;

  ReplayGainSync build({AlbumRunKeyLookup? withLookup}) =>
      ReplayGainSync(backend: fake, lookup: withLookup ?? lookup);

  /// A track starts: the player numbers a new turn.
  void startTurn(PlayQueue queue) => sync.setQueue(queue, turn: ++turn);

  setUp(() {
    fake = FakeAudioBackend();
    lookups = [];
    turn = 0;
    lookup = (paths) async {
      lookups.add(paths);
      return {for (final p in paths) p: ?albumsByPath[p]};
    };
    sync = build();
  });

  tearDown(() => sync.dispose());

  /// Lets the lookups the sync started finish.
  Future<void> settle() => pumpEventQueue();

  group('ReplayGain', () {
    test('default settings make no call', () async {
      sync.setPrefs(const PlaybackPrefs());
      startTurn(queueOf(['a1', 'a2']));
      await settle();

      expect(fake.audioCalls, isEmpty);
      expect(lookups, isEmpty);
    });

    test('a mode sends once, the same settings again do not', () {
      sync.setPrefs(rg(ReplayGainMode.track));
      sync.setPrefs(rg(ReplayGainMode.track));

      expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
    });

    test('each changed field sends one call', () {
      sync.setPrefs(rg(ReplayGainMode.track));
      sync.setPrefs(rg(ReplayGainMode.track, preamp: 3));
      sync.setPrefs(
        rg(ReplayGainMode.track, preamp: 3, preventClipping: false),
      );

      expect(fake.audioCalls, [
        'setReplayGain(track, 0.00, clip=no)',
        'setReplayGain(track, 3.00, clip=no)',
        'setReplayGain(track, 3.00, clip=yes)',
      ]);
    });

    test('turning it off again goes back to the engine default', () {
      sync.setPrefs(rg(ReplayGainMode.album));
      sync.setPrefs(rg(ReplayGainMode.off));

      expect(fake.audioCalls.last, 'setReplayGain(no, 0.00, clip=no)');
    });

    test('a failing engine call is swallowed', () async {
      fake.audioError = Exception('boom');
      sync.setPrefs(rg(ReplayGainMode.track));
      await settle();

      expect(fake.audioCalls, hasLength(1));
    });
  });

  test('nothing reaches the engine after dispose', () async {
    final gate = Completer<Map<String, AlbumRunKey>>();
    sync.dispose();
    sync = build(withLookup: (_) => gate.future);
    sync.setPrefs(rg(ReplayGainMode.auto));
    startTurn(queueOf(['a1', 'a2']));
    fake.audioCalls.clear();

    sync.dispose();
    gate.complete({'/m/a1.flac': albumOne, '/m/a2.flac': albumOne});
    await settle();
    sync.setPrefs(rg(ReplayGainMode.track));
    startTurn(queueOf(['a1']));

    expect(fake.audioCalls, isEmpty);
  });
}
