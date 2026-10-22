import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/album_run_lookup.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/player/replay_gain_sync.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/playback_prefs.dart';
import 'package:logging/logging.dart';

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

  /// The queue is edited while the same track plays.
  void editQueue(PlayQueue queue) => sync.setQueue(queue, turn: turn);

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
        startTurn(queueOf(['a1', 'a2', 's']));
        await settle();
        expect(fake.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
        fake.audioCalls.clear();

        // Both keys were read ahead: no wait, no new call.
        startTurn(queueOf(['a1', 'a2', 's'], at: 1));
        expect(fake.audioCalls, isEmpty);

        // `s` is next to an album track but has no album of its own.
        startTurn(queueOf(['a1', 'a2', 's'], at: 2));
        await settle();
        expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      },
    );

    test(
      'moving on inside a read ahead album decides without waiting',
      () async {
        startTurn(queueOf(['a1', 'a2', 'b1']));
        await settle();
        lookups.clear();
        fake.audioCalls.clear();

        startTurn(queueOf(['a1', 'a2', 'b1'], at: 1));
        startTurn(queueOf(['a1', 'a2', 'b1'], at: 2));

        // b1 is the odd one out between a2 and nothing: decided synchronously.
        expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      },
    );

    test(
      'editing the queue does not change the level of the playing track',
      () async {
        final queue = queueOf(['a1', 'a2', 's', 'b1'], at: 1);
        startTurn(queue);
        await settle();
        fake.audioCalls.clear();

        editQueue(queue.copyWith(shuffled: true)); // shuffle on
        editQueue(
          PlayQueue(original: queue.original, order: [1, 3, 2, 0], index: 0),
        );
        editQueue(PlayQueue(original: queue.original, order: [1, 2], index: 0));
        await settle();

        expect(fake.audioCalls, isEmpty);
      },
    );

    test('a one track queue on repeat all is not its own neighbour', () async {
      startTurn(queueOf(['a1'], repeat: RepeatMode.all));
      await settle();

      expect(fake.audioCalls, isEmpty); // track gain is what auto starts at
    });

    test('the same file twice in a row is not an album run', () async {
      startTurn(queueOf(['a1', 'a1']));
      await settle();

      expect(fake.audioCalls, isEmpty);
    });

    test('a track outside the library is track gain, with no lookup', () async {
      startTurn(
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

      startTurn(queueOf(['a1', 'a2', 's']));
      final first = gates.first;
      // The track changed before the answer: the next turn asks again.
      startTurn(queueOf(['a1', 'a2', 's'], at: 2));
      first.complete({'/m/a1.flac': albumOne, '/m/a2.flac': albumOne});
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

      startTurn(queueOf(['a1', 'a2']));
      await settle();
      startTurn(queueOf(['a1', 'a2'], at: 1));
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
        startTurn(queueOf(['a1', 'a2'], at: 1));
        fake.audioCalls.clear();

        sync.setPrefs(rg(ReplayGainMode.auto));
        await settle();

        expect(fake.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
      },
    );

    test('a preamp change keeps the decision of the turn', () async {
      startTurn(queueOf(['a1', 'a2']));
      await settle();
      fake.audioCalls.clear();

      sync.setPrefs(rg(ReplayGainMode.auto, preamp: 3));

      expect(fake.audioCalls, ['setReplayGain(album, 3.00, clip=no)']);
    });

    test('clearing the queue keeps the level of the playing track', () async {
      startTurn(queueOf(['a1', 'a2', 's'], at: 1));
      await settle();
      expect(fake.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
      fake.audioCalls.clear();

      // What `keepOnlyCurrent` leaves: the playing track alone, renumbered 0.
      editQueue(PlayQueue.open([t('a2')], 0));
      await settle();
      expect(fake.audioCalls, isEmpty);

      // The next track that starts is decided again.
      startTurn(queueOf(['s']));
      await settle();
      expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
    });

    test('a track with no album is cached too and decides at once', () async {
      startTurn(queueOf(['a1', 'a2', 's']));
      await settle();
      lookups.clear();
      fake.audioCalls.clear();

      // `s` was read ahead and found to have no album: no wait for it.
      startTurn(queueOf(['a1', 'a2', 's'], at: 2));

      expect(fake.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
      expect(lookups, isEmpty);
    });

    test('a path being read is not asked for again', () async {
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

      // One read for the decision (a1, a2), one for the read ahead (s).
      startTurn(queueOf(['a1', 'a2', 's']));
      expect(gates, hasLength(2));

      // The next turn needs a2 and s, both still being read.
      startTurn(queueOf(['a1', 'a2', 's'], at: 2));
      expect(gates, hasLength(2));

      gates[0].complete({'/m/a1.flac': albumOne, '/m/a2.flac': albumOne});
      gates[1].complete(const {});
      await settle();
      expect(fake.audioCalls, isEmpty); // s has no album: track, as before
    });
  });
}
