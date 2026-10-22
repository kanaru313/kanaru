import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/album_run_lookup.dart';
import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/audio_output_sync.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';
import 'package:logging/logging.dart';

import 'fake_audio_backend.dart';

const _one = (artist: 'Ann', title: 'One');
const _two = (artist: 'Bob', title: 'Two');

/// Album of each test file: `a1`, `a2` and `a3` share one, `b1` has another,
/// `s` and anything else has none.
const _albums = <String, AlbumRunKey>{
  '/m/a1.flac': _one,
  '/m/a2.flac': _one,
  '/m/a3.flac': _one,
  '/m/b1.flac': _two,
};

Track t(String name) => Track.fromPath('/m/$name.flac');

PlayQueue queueOf(
  List<String> names, {
  int at = 0,
  RepeatMode repeat = RepeatMode.off,
}) => PlayQueue.open([for (final n in names) t(n)], at, repeat: repeat);

AudioOutputDevice device(String name) =>
    AudioOutputDevice(name: name, description: name);

PlaybackPrefs rg(
  ReplayGainMode mode, {
  double preamp = 0,
  bool preventClipping = true,
}) => PlaybackPrefs(
  replayGainMode: mode,
  replayGainPreampDb: preamp,
  replayGainPreventClipping: preventClipping,
);

void main() {
  late FakeAudioBackend fake;
  late List<List<String>> lookups;
  late AlbumRunKeyLookup lookup;
  late List<String?> failedReports;
  late AudioOutputSync sync;

  AudioOutputSync build({AlbumRunKeyLookup? withLookup}) => AudioOutputSync(
    backend: fake,
    lookup: withLookup ?? lookup,
    onFailedDeviceChanged: failedReports.add,
  );

  setUp(() {
    fake = FakeAudioBackend();
    lookups = [];
    failedReports = [];
    lookup = (paths) async {
      lookups.add(paths);
      return {for (final p in paths) p: ?_albums[p]};
    };
    sync = build();
  });

  tearDown(() => sync.dispose());

  /// Lets the lookups the sync started finish.
  Future<void> settle() => pumpEventQueue();

  group('ReplayGain', () {
    test('default settings make no call', () async {
      sync.setPrefs(const PlaybackPrefs());
      sync.setQueue(queueOf(['a1', 'a2']));
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

  group('ReplayGain auto', () {
    // With no album known yet, auto is track gain.
    setUp(() {
      sync.setPrefs(rg(ReplayGainMode.auto));
      expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      fake.audioCalls.clear();
    });

    test(
      'an album run uses album gain, the next odd track track gain',
      () async {
        sync.setQueue(queueOf(['a1', 'a2', 's']));
        await settle();
        expect(fake.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
        fake.audioCalls.clear();

        // Both keys were read ahead: no wait, no new call.
        sync.setQueue(queueOf(['a1', 'a2', 's'], at: 1));
        expect(fake.audioCalls, isEmpty);

        // `s` is next to an album track but has no album of its own.
        sync.setQueue(queueOf(['a1', 'a2', 's'], at: 2));
        await settle();
        expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      },
    );

    test(
      'moving on inside a read ahead album decides without waiting',
      () async {
        sync.setQueue(queueOf(['a1', 'a2', 'b1']));
        await settle();
        lookups.clear();
        fake.audioCalls.clear();

        sync.setQueue(queueOf(['a1', 'a2', 'b1'], at: 1));
        sync.setQueue(queueOf(['a1', 'a2', 'b1'], at: 2));

        // b1 is the odd one out between a2 and nothing: decided synchronously.
        expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      },
    );

    test(
      'editing the queue does not change the level of the playing track',
      () async {
        final queue = queueOf(['a1', 'a2', 's', 'b1'], at: 1);
        sync.setQueue(queue);
        await settle();
        fake.audioCalls.clear();

        sync.setQueue(queue.copyWith(shuffled: true)); // shuffle on
        sync.setQueue(
          PlayQueue(original: queue.original, order: [1, 3, 2, 0], index: 0),
        );
        sync.setQueue(
          PlayQueue(original: queue.original, order: [1, 2], index: 0),
        );
        await settle();

        expect(fake.audioCalls, isEmpty);
      },
    );

    test('a one track queue on repeat all is not its own neighbour', () async {
      sync.setQueue(queueOf(['a1'], repeat: RepeatMode.all));
      await settle();

      expect(fake.audioCalls, isEmpty); // track gain is what auto starts at
    });

    test('the same file twice in a row is not an album run', () async {
      sync.setQueue(queueOf(['a1', 'a1']));
      await settle();

      expect(fake.audioCalls, isEmpty);
    });

    test('a track outside the library is track gain, with no lookup', () async {
      sync.setQueue(
        PlayQueue.open(const [
          Track(uri: 'http://example.test/a.mp3', title: 'x'),
          Track(uri: 'http://example.test/b.mp3', title: 'y'),
        ], 0),
      );
      await settle();

      expect(fake.audioCalls, isEmpty);
      expect(lookups, isEmpty);
    });

    test('a slow lookup of a turn that is over is dropped', () async {
      final gates = <Completer<Map<String, AlbumRunKey>>>[];
      sync.dispose();
      sync = build(
        withLookup: (paths) {
          final gate = Completer<Map<String, AlbumRunKey>>();
          gates.add(gate);
          return gate.future;
        },
      );
      sync.setPrefs(rg(ReplayGainMode.auto));
      fake.audioCalls.clear();

      sync.setQueue(queueOf(['a1', 'a2', 's']));
      final first = gates.first;
      // The track changed before the answer: the next turn asks again.
      sync.setQueue(queueOf(['a1', 'a2', 's'], at: 2));
      first.complete({'/m/a1.flac': _one, '/m/a2.flac': _one});
      await settle();
      expect(fake.audioCalls, isEmpty, reason: 'old turn must not apply');

      for (final gate in gates.skip(1)) {
        if (!gate.isCompleted) gate.complete(const {});
      }
      await settle();
      expect(fake.audioCalls, isEmpty); // s has no album: track, as before
    });

    test('a failing lookup is track gain and one warning', () async {
      final records = <LogRecord>[];
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() {
        subscription.cancel();
        Logger.root.level = previous;
      });
      sync.dispose();
      sync = build(withLookup: (_) async => throw StateError('db closed'));
      sync.setPrefs(rg(ReplayGainMode.auto));
      fake.audioCalls.clear();

      sync.setQueue(queueOf(['a1', 'a2']));
      await settle();
      sync.setQueue(queueOf(['a1', 'a2'], at: 1));
      await settle();

      expect(fake.audioCalls, isEmpty);
      expect(records.where((r) => r.level == Level.WARNING), hasLength(1));
    });

    test(
      'switching to auto in the middle of a track decides at once',
      () async {
        sync.dispose();
        sync = build();
        sync.setPrefs(rg(ReplayGainMode.track));
        sync.setQueue(queueOf(['a1', 'a2'], at: 1));
        fake.audioCalls.clear();

        sync.setPrefs(rg(ReplayGainMode.auto));
        await settle();

        expect(fake.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
      },
    );

    test('a preamp change keeps the decision of the turn', () async {
      sync.setQueue(queueOf(['a1', 'a2']));
      await settle();
      fake.audioCalls.clear();

      sync.setPrefs(rg(ReplayGainMode.auto, preamp: 3));

      expect(fake.audioCalls, ['setReplayGain(album, 3.00, clip=no)']);
    });

    test('keeps at most 256 keys, oldest first', () async {
      final many = [for (var i = 0; i < 300; i++) 'x$i'];
      sync.dispose();
      sync = build(
        withLookup: (paths) async {
          lookups.add(paths);
          return {for (final p in paths) p: _one};
        },
      );
      sync.setPrefs(rg(ReplayGainMode.auto));
      for (var i = 0; i < 300; i += 2) {
        sync.setQueue(queueOf(many, at: i));
        await settle();
      }
      lookups.clear();

      // The first tracks are gone from the cache and are read again.
      sync.setQueue(queueOf(many));
      await settle();
      expect(lookups, isNotEmpty);
    });
  });

  group('output device', () {
    const x = 'pipewire/x';

    PlaybackPrefs saved([String? name = x]) =>
        const PlaybackPrefs().withAudioDevice(name: name, description: 'X');

    testWidgets('waits for the list, then uses the saved device', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto')]);
      expect(fake.audioCalls, isEmpty);

      sync.setDevices([device('auto'), device(x)]);
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    testWidgets('a device that leaves goes to auto at once, back after 2 s', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      fake.audioCalls.clear();

      sync.setDevices([device('auto')]);
      expect(fake.audioCalls, ['setAudioDevice(auto)']);
      fake.audioCalls.clear();

      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(fake.audioCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    testWidgets('a device that flickers is not moved to while it does', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.setDevices([device('auto')]);
      fake.audioCalls.clear();

      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(seconds: 1));
      sync.setDevices([device('auto')]);
      await tester.pump(const Duration(seconds: 1));
      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(fake.audioCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 600));
      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    test('names mpv would take as something else are never sent', () {
      final list = [device('auto'), device('pipewire'), device('jack')];
      for (final name in ['pcm/out.wav', 'pipewire', 'jack', 'help']) {
        sync.setPrefs(saved(name));
        sync.setDevices(list);
      }

      expect(fake.audioCalls, isEmpty);
    });

    test('a failed device stays on auto while it is listed', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      fake.audioCalls.clear();

      sync.markDeviceFailed(x);
      sync.setDevices([device('auto'), device(x), device('pulse/y')]);

      expect(fake.audioCalls, isEmpty); // the backend already went to auto
      expect(sync.failedDevice, x);
      expect(failedReports, [x]);
    });

    test('choosing it again tries it again', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.setPrefs(saved('pulse/y'));
      sync.setPrefs(saved());

      expect(fake.audioCalls, ['setAudioDevice($x)']);
      expect(sync.failedDevice, isNull);
      expect(failedReports, [x, null]);
    });

    test('retrying clears the failure and uses the saved device again', () {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.retryDevice();
      sync.retryDevice(); // nothing left to retry

      expect(fake.audioCalls, ['setAudioDevice($x)']);
      expect(sync.failedDevice, isNull);
      expect(failedReports, [x, null]);
    });

    testWidgets('a failed device that leaves and returns is tried again', (
      tester,
    ) async {
      sync.setPrefs(saved());
      sync.setDevices([device('auto'), device(x)]);
      sync.markDeviceFailed(x);
      fake.audioCalls.clear();

      sync.setDevices([device('auto')]);
      expect(sync.failedDevice, isNull);
      sync.setDevices([device('auto'), device(x)]);
      await tester.pump(const Duration(seconds: 3));

      expect(fake.audioCalls, ['setAudioDevice($x)']);
    });

    test('a failure of a device that is not the saved one is ignored', () {
      sync.setPrefs(saved('pulse/y'));
      sync.markDeviceFailed(x);

      expect(sync.failedDevice, isNull);
    });
  });

  group('after dispose', () {
    testWidgets('nothing reaches the engine', (tester) async {
      final gate = Completer<Map<String, AlbumRunKey>>();
      sync.dispose();
      sync = build(withLookup: (_) => gate.future);
      sync.setPrefs(rg(ReplayGainMode.auto));
      sync.setQueue(queueOf(['a1', 'a2']));
      sync.setPrefs(const PlaybackPrefs().withAudioDevice(name: 'pipewire/x'));
      sync.setDevices([device('auto'), device('pipewire/x')]);
      fake.audioCalls.clear();
      // A device that returns after leaving waits on a timer.
      sync.setDevices([device('auto')]);
      sync.setDevices([device('auto'), device('pipewire/x')]);
      fake.audioCalls.clear();

      sync.dispose();
      gate.complete({'/m/a1.flac': _one, '/m/a2.flac': _one});
      await tester.pump(const Duration(seconds: 5));
      sync.setPrefs(rg(ReplayGainMode.track));
      sync.setDevices([device('auto')]);
      sync.markDeviceFailed('pipewire/x');
      sync.setQueue(queueOf(['a1']));

      expect(fake.audioCalls, isEmpty);
    });
  });
}
