import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/mpv_playlist_tracker.dart';
import 'package:kanaru/core/player/playback_error.dart';
import 'package:kanaru/core/player/track.dart';

/// A stand-in for mpv's playlist: entry ids by index and the playing index.
/// When [gate] is set, reads of the playing position wait for it, so a test
/// decides what mpv did while the read was in flight.
class _FakeMpv {
  List<int> ids = [];
  int position = -1;
  Completer<void>? gate;

  Future<String> read(String name) async {
    if (name == 'playlist-playing-pos') {
      final wait = gate;
      if (wait != null) await wait.future;
      return '$position';
    }
    final entry = RegExp(r'^playlist/(\d+)/id$').firstMatch(name);
    if (entry != null) {
      final index = int.parse(entry.group(1)!);
      return index < ids.length ? '${ids[index]}' : '';
    }
    throw ArgumentError('unexpected property $name');
  }
}

const _a = Track(uri: '/a.mp3', title: 'a');
const _b = Track(uri: '/b.mp3', title: 'b');

void main() {
  late _FakeMpv mpv;
  late MpvPlaylistTracker tracker;
  late List<Track> advanced;
  late List<bool> advancedLoaded;
  late List<PlaybackError> failed;

  setUp(() {
    mpv = _FakeMpv();
    advanced = [];
    advancedLoaded = [];
    failed = [];
    tracker = MpvPlaylistTracker(
      read: mpv.read,
      onAdvanced: (track, {required loaded}) {
        advanced.add(track);
        advancedLoaded.add(loaded);
      },
      onFailed: failed.add,
    );
  });

  /// `a` (entry 1) playing with `b` (entry 2) queued after it.
  void openAThenB() {
    mpv.ids = [1, 2];
    mpv.position = 0;
    tracker.resetForOpen();
    tracker.setCurrent(_a, 1);
    tracker.queueNext(_b);
    tracker.setNextId(2);
  }

  group('markLoaded', () {
    test('marks the entry mpv is playing', () async {
      openAThenB();
      await tracker.markLoaded();
      tracker.reportIfFailed();
      expect(failed, isEmpty);
    });

    test("the next entry's duration, handled as mpv moves on to it, marks it "
        'loaded', () async {
      openAThenB();
      // Gapless switch: the duration of `b` is delivered before the position
      // change, and mpv is at `b` by the time the read answers.
      mpv.gate = Completer<void>();
      final marking = tracker.markLoaded();
      mpv.position = 1;
      mpv.gate!.complete();
      await marking;

      expect(await tracker.promoteIfNext(1), isTrue);
      expect(advancedLoaded, [true]);
      // Only `a`, which never loaded, failed; `b` did not.
      expect(failed.map((e) => e.track), [_a]);
      tracker.reportIfFailed();
      expect(failed.map((e) => e.track), [_a]);
    });
  });

  group('promoteIfNext', () {
    test('makes the queued next entry current and announces it', () async {
      openAThenB();
      mpv.position = 1;
      expect(await tracker.promoteIfNext(1), isTrue);
      expect(tracker.current, _b);
      expect(tracker.currentId, 2);
      expect(tracker.nextId, isNull);
      expect(advanced, [_b]);
      expect(advancedLoaded, [false]);
    });

    test(
      'leaves everything alone when the entry is not the next one',
      () async {
        openAThenB();
        expect(await tracker.promoteIfNext(0), isFalse);
        expect(tracker.current, _a);
        expect(advanced, isEmpty);
      },
    );

    test('does nothing without a queued next track', () async {
      openAThenB();
      tracker.queueNext(null);
      expect(await tracker.promoteIfNext(1), isFalse);
      expect(advanced, isEmpty);
    });

    test('reports the track it leaves when that one never loaded', () async {
      openAThenB();
      expect(await tracker.promoteIfNext(1), isTrue);
      expect(failed.single.track, _a);
    });

    test('does not report the track it leaves when that one loaded', () async {
      openAThenB();
      await tracker.markLoaded();
      expect(await tracker.promoteIfNext(1), isTrue);
      expect(failed, isEmpty);
    });
  });

  group('failures', () {
    test('the error line is spent by the report that used it', () {
      openAThenB();
      tracker.recordError('first');
      tracker.recordError('Failed to open /a.mp3');
      tracker.reportIfFailed();
      tracker.reportIfFailed();
      expect(failed, hasLength(2));
      expect(failed.first.message, 'Failed to open /a.mp3');
      // The message is spent: a second report for the same track carries none.
      expect(failed.last.message, isEmpty);
    });

    test('leaving idle reports the current track and announces the stop', () {
      openAThenB();
      tracker.queueNext(null);
      expect(tracker.leaveIdle(), isTrue);
      expect(failed.single.track, _a);
    });

    test('leaving idle moves through the queued next track first', () {
      openAThenB();
      expect(tracker.leaveIdle(), isTrue);
      expect(advanced, [_b]);
      expect(failed.map((e) => e.track), [_a, _b]);
    });

    test('leaving idle with nothing playing announces nothing', () {
      expect(tracker.leaveIdle(), isFalse);
      expect(failed, isEmpty);
    });
  });

  group('forgetTracks', () {
    test('drops both tracks so nothing is reported failed', () {
      openAThenB();
      tracker.forgetTracks();
      tracker.reportIfFailed();
      expect(failed, isEmpty);
      expect(tracker.current, isNull);
      expect(tracker.currentId, isNull);
      expect(tracker.nextId, isNull);
      expect(tracker.leaveIdle(), isFalse);
    });
  });

  group('loaded entries', () {
    test('entries before the new current one are pruned', () async {
      mpv.ids = [1, 2, 3];
      mpv.position = 0;
      tracker.setCurrent(_a, 1);
      await tracker.markLoaded();
      tracker.queueNext(_b);
      tracker.setNextId(2);
      expect(await tracker.promoteIfNext(1), isTrue);

      // Entry 1 is forgotten: queueing it as current again counts as unloaded.
      tracker.setCurrent(_a, 1);
      tracker.reportIfFailed();
      expect(failed.single.track, _a);
    });

    test('resetForOpen forgets what loaded', () async {
      openAThenB();
      await tracker.markLoaded();
      tracker.resetForOpen();
      tracker.reportIfFailed();
      expect(failed.single.track, _a);
    });
  });

  group('promoteEntry', () {
    test('announces an entry that started while another next was queued', () {
      openAThenB();
      // `c` replaced `b` as the queued next track, but mpv had started `b`.
      tracker.queueNext(const Track(uri: '/c.mp3', title: 'c'));
      tracker.setNextId(3);

      tracker.promoteEntry(_b, 2);

      expect(advanced, [_b]);
      expect(tracker.current, _b);
      expect(tracker.currentId, 2);
      expect(tracker.next, isNull);
      // `a` never loaded, so it counts as failed, as for any skipped track.
      expect(failed.map((e) => e.track), [_a]);
    });
  });
}
