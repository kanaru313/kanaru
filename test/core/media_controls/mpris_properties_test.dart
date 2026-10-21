import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

final tracks = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

PlayerState stateOf(
  PlayQueue queue, {
  bool playing = false,
  bool stopped = false,
  Duration duration = Duration.zero,
  Duration position = Duration.zero,
  double volume = 100,
}) => PlayerState(
  queue: queue,
  playing: playing,
  stopped: stopped,
  duration: duration,
  position: position,
  volume: volume,
);

Map<String, DBusValue> props(PlayerState state, [MprisTrackIds? ids]) {
  ids ??= MprisTrackIds()..observe(state.queue);
  return playerProperties(state, ids);
}

Map<String, DBusValue> metadata(PlayerState state, [MprisTrackIds? ids]) {
  ids ??= MprisTrackIds()..observe(state.queue);
  return mprisMetadata(state, ids).asStringVariantDict();
}

void main() {
  group('playback status', () {
    test('empty queue is Stopped', () {
      expect(
        props(PlayerState())['PlaybackStatus'],
        const DBusString('Stopped'),
      );
    });

    test('playing, paused', () {
      final queue = PlayQueue(original: tracks);
      expect(
        props(stateOf(queue, playing: true))['PlaybackStatus'],
        const DBusString('Playing'),
      );
      expect(
        props(stateOf(queue))['PlaybackStatus'],
        const DBusString('Paused'),
      );
    });

    test('stopped wins over playing', () {
      final state = stateOf(
        PlayQueue(original: tracks),
        playing: true,
        stopped: true,
      );
      expect(props(state)['PlaybackStatus'], const DBusString('Stopped'));
    });
  });

  group('capabilities', () {
    test('empty queue offers nothing', () {
      final p = props(PlayerState());
      for (final key in ['CanPlay', 'CanPause', 'CanGoNext', 'CanGoPrevious']) {
        expect(p[key], const DBusBoolean(false), reason: key);
      }
      expect(p['CanControl'], const DBusBoolean(true));
    });

    test('next and previous follow the queue position', () {
      final middle = props(stateOf(PlayQueue(original: tracks, index: 1)));
      expect(middle['CanGoNext'], const DBusBoolean(true));
      expect(middle['CanGoPrevious'], const DBusBoolean(true));
      final first = props(stateOf(PlayQueue(original: tracks)));
      expect(first['CanGoPrevious'], const DBusBoolean(false));
      final last = props(stateOf(PlayQueue(original: tracks, index: 2)));
      expect(last['CanGoNext'], const DBusBoolean(false));
      final wrap = props(
        stateOf(PlayQueue(original: tracks, index: 2, repeat: RepeatMode.all)),
      );
      expect(wrap['CanGoNext'], const DBusBoolean(true));
    });

    test('CanSeek needs a known duration', () {
      final queue = PlayQueue(original: tracks);
      expect(props(stateOf(queue))['CanSeek'], const DBusBoolean(false));
      expect(
        props(stateOf(queue, duration: const Duration(seconds: 1)))['CanSeek'],
        const DBusBoolean(true),
      );
    });
  });

  group('settings', () {
    test('loop status maps both ways', () {
      for (final (mode, status) in [
        (RepeatMode.off, 'None'),
        (RepeatMode.one, 'Track'),
        (RepeatMode.all, 'Playlist'),
      ]) {
        final queue = PlayQueue(original: tracks, repeat: mode);
        expect(props(stateOf(queue))['LoopStatus'], DBusString(status));
        expect(repeatModeFromLoopStatus(status), mode);
      }
      expect(repeatModeFromLoopStatus('Bogus'), isNull);
    });

    test('shuffle and volume', () {
      final queue = PlayQueue(original: tracks).shuffle();
      final p = props(stateOf(queue, volume: 50));
      expect(p['Shuffle'], const DBusBoolean(true));
      expect(p['Volume'], const DBusDouble(0.5));
      expect(props(stateOf(queue, volume: 250))['Volume'], const DBusDouble(1));
    });
  });

  group('track ids', () {
    test('empty queue is NoTrack', () {
      expect(
        metadata(PlayerState())['mpris:trackid'],
        DBusObjectPath(mprisNoTrackPath),
      );
    });

    test('shuffle keeps ids, a newly opened queue changes them', () {
      final ids = MprisTrackIds();
      final queue = PlayQueue(original: tracks, index: 1);
      ids.observe(queue);
      final before = ids.of(queue);

      final shuffled = queue.shuffle();
      ids.observe(shuffled);
      // Same track, same id, wherever shuffle moved it.
      expect(ids.of(shuffled), before);

      final reopened = PlayQueue(original: [...tracks], index: 1);
      ids.observe(reopened);
      expect(ids.of(reopened), isNot(before));
    });

    test('adding tracks keeps the ids', () {
      final ids = MprisTrackIds();
      final queue = PlayQueue(original: tracks, index: 1);
      ids.observe(queue);
      final before = ids.of(queue);

      final grown = queue.insert(2, [Track.fromPath('/music/d.mp3')]);
      ids.observe(grown);
      expect(ids.of(grown), before);
    });

    test('clearing the queue compacts it and changes the ids', () {
      final ids = MprisTrackIds();
      final queue = PlayQueue(original: tracks, index: 1);
      ids.observe(queue);
      final before = ids.of(queue);

      final cleared = queue.keepOnlyCurrent();
      ids.observe(cleared);
      expect(ids.of(cleared), isNot(before));
    });

    test('ids are valid object paths', () {
      final ids = MprisTrackIds();
      final queue = PlayQueue(original: tracks);
      ids.observe(queue);
      expect(ids.of(queue).value, startsWith('/io/github/kanaru313/kanaru/'));
    });
  });

  group('queue edits', () {
    test('removing another track keeps the playing track id', () {
      final queue = PlayQueue(original: tracks, index: 1);
      final ids = MprisTrackIds()..observe(queue);
      final before = metadata(stateOf(queue), ids)['mpris:trackid'];

      final edited = queue.removeAt(0);
      ids.observe(edited);
      expect(edited.current, tracks[1]);
      expect(metadata(stateOf(edited), ids)['mpris:trackid'], before);

      final moved = queue.move(0, 2);
      ids.observe(moved);
      expect(metadata(stateOf(moved), ids)['mpris:trackid'], before);
    });

    test('a removed track id is not reused by the one after it', () {
      final queue = PlayQueue(original: tracks);
      final ids = MprisTrackIds()..observe(queue);
      final first = metadata(stateOf(queue), ids)['mpris:trackid'];
      final edited = queue.removeAt(0);
      ids.observe(edited);
      expect(metadata(stateOf(edited), ids)['mpris:trackid'], isNot(first));
    });

    test('CanGoNext follows the queue after the last track is removed', () {
      final queue = PlayQueue(original: tracks, index: 1);
      expect(props(stateOf(queue))['CanGoNext'], const DBusBoolean(true));
      final edited = queue.removeAt(2);
      expect(props(stateOf(edited))['CanGoNext'], const DBusBoolean(false));
      expect(props(stateOf(edited))['CanGoPrevious'], const DBusBoolean(true));
    });
  });

  group('metadata', () {
    final queue = PlayQueue(
      original: [
        const Track(
          uri: '/music/some song.mp3',
          title: 'Song',
          artist: 'Band',
          artUri: '/music/cover.jpg',
          duration: Duration(seconds: 30),
        ),
      ],
    );

    test('uses the types clients expect', () {
      final m = metadata(stateOf(queue));
      expect(m['mpris:trackid'], isA<DBusObjectPath>());
      expect(m['xesam:title'], const DBusString('Song'));
      expect(m['xesam:artist'], DBusArray.string(['Band']));
      expect(m['xesam:artist']!.signature, DBusSignature('as'));
      expect(m['mpris:length'], const DBusInt64(30000000));
      expect(m['xesam:url'], const DBusString('file:///music/some%20song.mp3'));
      expect(m['mpris:artUrl'], const DBusString('file:///music/cover.jpg'));
    });

    test('engine duration beats the track duration', () {
      final m = metadata(stateOf(queue, duration: const Duration(seconds: 5)));
      expect(m['mpris:length'], const DBusInt64(5000000));
    });

    test('optional keys are left out when unknown', () {
      final m = metadata(stateOf(PlayQueue(original: tracks)));
      expect(
        m.keys,
        unorderedEquals(['mpris:trackid', 'xesam:title', 'xesam:url']),
      );
    });

    test('only file URLs are published', () {
      expect(mprisFileUrl('/a/b.mp3'), 'file:///a/b.mp3');
      expect(mprisFileUrl('file:///a/b.mp3'), 'file:///a/b.mp3');
      expect(mprisFileUrl('http://127.0.0.1:1234/t?token=x'), isNull);
      expect(mprisFileUrl('relative/b.mp3'), isNull);
      expect(mprisFileUrl(null), isNull);
      final remote = PlayQueue(
        original: [
          const Track(
            uri: 'http://127.0.0.1:1234/t?token=x',
            title: 'Remote',
            artUri: 'https://example.com/c.jpg',
          ),
        ],
      );
      final m = metadata(stateOf(remote));
      expect(m.containsKey('xesam:url'), isFalse);
      expect(m.containsKey('mpris:artUrl'), isFalse);
    });
  });

  group('diff', () {
    test('position alone changes nothing', () {
      final queue = PlayQueue(original: tracks);
      final ids = MprisTrackIds()..observe(queue);
      final a = playerProperties(stateOf(queue), ids);
      final b = playerProperties(
        stateOf(queue, position: const Duration(seconds: 3)),
        ids,
      );
      expect(a['Position'], isNot(b['Position']));
      expect(changedProperties(a, b), isEmpty);
    });

    test('reports only what changed', () {
      final queue = PlayQueue(original: tracks);
      final ids = MprisTrackIds()..observe(queue);
      final a = playerProperties(stateOf(queue), ids);
      final b = playerProperties(
        stateOf(queue, playing: true, position: const Duration(seconds: 3)),
        ids,
      );
      expect(changedProperties(a, b).keys, ['PlaybackStatus']);
    });
  });
}
