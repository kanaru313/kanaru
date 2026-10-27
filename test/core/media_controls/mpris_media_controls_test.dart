import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:logging/logging.dart';

import 'mpris_test_harness.dart';

Matcher dbusError(String name) => throwsA(
  isA<DBusMethodResponseException>().having(
    (e) => e.response.errorName,
    'errorName',
    'org.freedesktop.DBus.Error.$name',
  ),
);

/// Wide enough that a slow test machine cannot split one burst in two.
const _wideWindow = Duration(milliseconds: 40);

void main() {
  late MprisHarness h;

  setUp(() async {
    h = MprisHarness();
    await h.setUp();
  });
  tearDown(() => h.tearDown());

  group('published state', () {
    test('GetAll right after start has the real data', () async {
      await h.service.openTracks(songs, start: 1);
      await h.start();

      final root = await h.remote.getAllProperties(mprisRootInterface);
      expect(root['Identity'], const DBusString('Kanaru'));
      expect(root['CanRaise'], const DBusBoolean(true));
      expect(root['HasTrackList'], const DBusBoolean(false));

      final player = await h.remote.getAllProperties(mprisPlayerInterface);
      expect(player['PlaybackStatus'], const DBusString('Playing'));
      expect(player['CanGoNext'], const DBusBoolean(true));
      final metadata = player['Metadata']!.asStringVariantDict();
      expect(metadata['xesam:title'], const DBusString('b'));
      expect(metadata['xesam:url'], const DBusString('file:///music/b.mp3'));
    });

    test('introspection lists each interface exactly once', () async {
      await h.start();
      final node = await h.remote.introspect();
      expect(
        node.interfaces.map((i) => i.name),
        unorderedEquals([
          'org.freedesktop.DBus.Introspectable',
          'org.freedesktop.DBus.Peer',
          'org.freedesktop.DBus.Properties',
          mprisRootInterface,
          mprisPlayerInterface,
        ]),
      );
    });

    test('introspection marks Position and CanControl as silent', () async {
      await h.start();
      final node = await h.remote.introspect();
      final player = node.interfaces.firstWhere(
        (i) => i.name == mprisPlayerInterface,
      );
      const annotation = 'org.freedesktop.DBus.Property.EmitsChangedSignal';
      final silent = {
        for (final p in player.properties)
          if (p.annotations.any(
            (a) => a.name == annotation && a.value == 'false',
          ))
            p.name,
      };
      expect(silent, {'Position', 'CanControl'});
    });

    test('Position is read live', () async {
      await h.service.openTracks(songs);
      await h.start();
      h.backend.emitPosition.add(const Duration(seconds: 7));
      final position = await h.remote.getProperty(
        mprisPlayerInterface,
        'Position',
      );
      expect(position, const DBusInt64(7000000));
    });
  });

  group('commands and signals', () {
    test('each command changes the player and sends one signal', () async {
      await h.service.openTracks(songs);
      await h.start(coalesceWindow: _wideWindow);
      final changes = await h.watchChanges();

      Future<Map<String, DBusValue>> after(Future<void> Function() act) async {
        changes.clear();
        await h.changeAfter(act);
        expect(changes, hasLength(1));
        return changes.single;
      }

      var sent = await after(() => h.call('PlayPause'));
      expect(sent['PlaybackStatus'], const DBusString('Paused'));
      expect(h.container.read(playerServiceProvider).playing, isFalse);

      sent = await after(() => h.call('Next'));
      expect(sent.keys, contains('Metadata'));
      expect(h.container.read(playerServiceProvider).queue.index, 1);

      sent = await after(() => h.call('Stop'));
      expect(sent['PlaybackStatus'], const DBusString('Stopped'));

      sent = await after(
        () => h.remote.setProperty(
          mprisPlayerInterface,
          'Volume',
          const DBusDouble(0.5),
        ),
      );
      expect(sent['Volume'], const DBusDouble(0.5));
      expect(h.backend.calls, contains('setVolume(50.0)'));

      sent = await after(
        () => h.remote.setProperty(
          mprisPlayerInterface,
          'LoopStatus',
          const DBusString('Track'),
        ),
      );
      expect(sent['LoopStatus'], const DBusString('Track'));
      expect(
        h.container.read(playerServiceProvider).queue.repeat,
        RepeatMode.one,
      );

      sent = await after(
        () => h.remote.setProperty(
          mprisPlayerInterface,
          'Shuffle',
          const DBusBoolean(true),
        ),
      );
      expect(sent['Shuffle'], const DBusBoolean(true));
      expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
    });

    test(
      'setting the status already shown keeps repeat all shuffled',
      () async {
        await h.service.openTracks(songs);
        await h.service.setRepeat(RepeatMode.allShuffled);
        await h.start();

        await h.remote.setProperty(
          mprisPlayerInterface,
          'LoopStatus',
          const DBusString('Playlist'),
        );
        await pumpEventQueue();
        expect(
          h.container.read(playerServiceProvider).queue.repeat,
          RepeatMode.allShuffled,
        );

        await h.remote.setProperty(
          mprisPlayerInterface,
          'LoopStatus',
          const DBusString('None'),
        );
        await pumpEventQueue();
        expect(
          h.container.read(playerServiceProvider).queue.repeat,
          RepeatMode.off,
        );
      },
    );

    test('a new track and its length arrive as one signal', () async {
      await h.start(coalesceWindow: _wideWindow);
      final changes = await h.watchChanges();

      await h.changeAfter(() async {
        await h.service.openTracks(songs, start: 2);
        h.backend.emitDuration.add(const Duration(seconds: 90));
      });

      expect(changes, hasLength(1));
      final metadata = changes.single['Metadata']!.asStringVariantDict();
      expect(metadata['xesam:title'], const DBusString('c'));
      expect(metadata['mpris:length'], const DBusInt64(90000000));
      expect(changes.single['CanSeek'], const DBusBoolean(true));
    });

    test('the endless queue setting changes CanGoNext', () async {
      await h.service.openTracks(songs, start: 2);
      await h.start();
      await h.settle();
      final changes = await h.watchChanges();

      await h.changeAfter(() async {
        final settings = h.container.read(settingsProvider.notifier);
        settings.setPlayback(
          h.container
              .read(settingsProvider)
              .playback
              .copyWith(infiniteQueue: true),
        );
      });

      expect(changes, hasLength(1));
      expect(changes.single['CanGoNext'], const DBusBoolean(true));
      final player = await h.remote.getAllProperties(mprisPlayerInterface);
      expect(player['CanGoNext'], const DBusBoolean(true));
    });

    test('position ticks send nothing', () async {
      await h.service.openTracks(songs);
      await h.start();
      h.backend.emitDuration.add(const Duration(seconds: 90));
      await h.settle();
      final changes = await h.watchChanges();

      for (var s = 1; s <= 5; s++) {
        h.backend.emitPosition.add(Duration(seconds: s));
      }
      await h.settle();
      expect(changes, isEmpty);
    });

    test('seek sends exactly one Seeked', () async {
      await h.service.openTracks(songs);
      await h.start();
      final seeked = await h.watchSeeked();

      final next = h.nextSeeked();
      await h.service.seek(const Duration(seconds: 3));
      await next;
      await h.settle();
      expect(seeked, [3000000]);
    });

    test('Raise runs the callback, Quit and OpenUri are refused', () async {
      await h.start();
      await h.call('Raise', const [], mprisRootInterface);
      expect(h.raised, hasLength(1));
      await expectLater(
        h.call('Quit', const [], mprisRootInterface),
        dbusError('NotSupported'),
      );
      await expectLater(
        h.call('OpenUri', [const DBusString('file:///a.mp3')]),
        dbusError('NotSupported'),
      );
    });
  });

  group('seeking', () {
    setUp(() async {
      await h.service.openTracks(songs);
      await h.start();
      h.backend.emitDuration.add(const Duration(seconds: 100));
      h.backend.emitPosition.add(const Duration(seconds: 10));
      h.backend.calls.clear();
    });

    test('Seek is relative and clamped', () async {
      await h.call('Seek', [const DBusInt64(5000000)]);
      await h.call('Seek', [const DBusInt64(-9000000000000)]);
      expect(h.backend.calls, ['seek(0:00:15.000000)', 'seek(0:00:00.000000)']);
    });

    test('Seek past the end goes to the next track', () async {
      await h.call('Seek', [const DBusInt64(0x7fffffffffffffff)]);
      expect(h.backend.calls, ['open(b, next: c)']);
    });

    test('SetPosition needs the current track id and a valid time', () async {
      final id = (await h.remote.getProperty(
        mprisPlayerInterface,
        'Metadata',
      )).asStringVariantDict()['mpris:trackid']!;
      final wrong = DBusObjectPath('/io/github/kanaru313/kanaru/track/9_9');

      await h.call('SetPosition', [wrong, const DBusInt64(1000000)]);
      await h.call('SetPosition', [id, const DBusInt64(-1)]);
      await h.call('SetPosition', [id, const DBusInt64(101000000)]);
      expect(h.backend.calls, isEmpty);

      await h.call('SetPosition', [id, const DBusInt64(20000000)]);
      expect(h.backend.calls, ['seek(0:00:20.000000)']);
    });

    test('nothing seeks without a known duration', () async {
      h.backend.emitDuration.add(Duration.zero);
      await h.call('Seek', [const DBusInt64(5000000)]);
      expect(h.backend.calls, isEmpty);
    });
  });

  group('volume', () {
    Future<void> setVolume(double value) =>
        h.remote.setProperty(mprisPlayerInterface, 'Volume', DBusDouble(value));

    Future<DBusValue> readVolume() =>
        h.remote.getProperty(mprisPlayerInterface, 'Volume');

    test('mute publishes 0.0 and unmute the volume from before', () async {
      await h.service.openTracks(songs);
      await h.service.setVolume(60);
      await h.start();
      final changes = await h.watchChanges();

      await h.changeAfter(h.service.toggleMute);
      expect(changes.single['Volume'], const DBusDouble(0));
      expect(await readVolume(), const DBusDouble(0));

      changes.clear();
      await h.changeAfter(h.service.toggleMute);
      expect(changes.single['Volume'], const DBusDouble(0.6));
      expect(await readVolume(), const DBusDouble(0.6));
    });

    test('a client setting the volume while muted unmutes', () async {
      await h.service.openTracks(songs);
      await h.service.setVolume(60);
      await h.service.toggleMute();
      await h.start();
      final changes = await h.watchChanges();

      await h.changeAfter(() => setVolume(0.3));

      final state = h.container.read(playerServiceProvider);
      expect(state.muted, isFalse);
      expect(state.volume, closeTo(30, 1e-9));
      expect(h.backend.calls.last, startsWith('setVolume(30.'));
      final sent = changes.single['Volume']!.asDouble();
      expect(sent, closeTo(0.3, 1e-9));
      expect((await readVolume()).asDouble(), closeTo(0.3, 1e-9));
    });

    test('out of range values are clamped', () async {
      await h.service.openTracks(songs);
      await h.start();

      await setVolume(1.5);
      await h.settle();
      expect(h.container.read(playerServiceProvider).volume, 100);
      expect(await readVolume(), const DBusDouble(1));

      await setVolume(-1);
      await h.settle();
      expect(h.container.read(playerServiceProvider).volume, 0);
      expect(await readVolume(), const DBusDouble(0));
    });

    test('non-finite values are refused and change nothing', () async {
      await h.service.openTracks(songs);
      await h.service.setVolume(60);
      await h.start();

      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await expectLater(setVolume(value), dbusError('InvalidArgs'));
      }
      await h.settle();
      expect(h.container.read(playerServiceProvider).volume, 60);
    });
  });

  group('bad input', () {
    test('wrong signatures are refused at once', () async {
      await h.service.openTracks(songs);
      await h.start();
      h.backend.calls.clear();

      await expectLater(
        h.call('Seek', [const DBusString('soon')]),
        dbusError('InvalidArgs'),
      );
      await expectLater(h.call('Seek'), dbusError('InvalidArgs'));
      await expectLater(
        h.call('Play', [const DBusInt32(1)]),
        dbusError('InvalidArgs'),
      );
      await expectLater(
        h.call('SetPosition', [const DBusInt64(1)]),
        dbusError('InvalidArgs'),
      );
      await expectLater(
        h.remote.setProperty(
          mprisPlayerInterface,
          'Volume',
          const DBusString('loud'),
        ),
        dbusError('InvalidArgs'),
      );
      await expectLater(
        h.remote.setProperty(
          mprisPlayerInterface,
          'Volume',
          const DBusDouble(double.nan),
        ),
        dbusError('InvalidArgs'),
      );
      await expectLater(
        h.remote.setProperty(
          mprisPlayerInterface,
          'LoopStatus',
          const DBusString('Sometimes'),
        ),
        dbusError('InvalidArgs'),
      );
      await expectLater(
        h.remote.setProperty(
          mprisPlayerInterface,
          'PlaybackStatus',
          const DBusString('Playing'),
        ),
        dbusError('PropertyReadOnly'),
      );
      await expectLater(
        h.remote.getProperty(mprisPlayerInterface, 'Nope'),
        dbusError('UnknownProperty'),
      );

      expect(h.backend.calls, isEmpty);
      // Still serving.
      expect(
        await h.remote.getProperty(mprisPlayerInterface, 'CanControl'),
        const DBusBoolean(true),
      );
    });
  });

  group('bus names', () {
    test('a taken name falls back to .instance<pid>', () async {
      final other = h.newClient();
      await other.requestName(mprisName);
      await h.start(name: '$mprisName.instance$pid');
      expect(await h.names(), contains('$mprisName.instance$pid'));
    });

    test('both taken falls back to .instance<pid>_1', () async {
      final other = h.newClient();
      await other.requestName(mprisName);
      await other.requestName('$mprisName.instance$pid');
      await h.start(name: '$mprisName.instance${pid}_1');
      expect(await h.names(), contains('$mprisName.instance${pid}_1'));
    });

    test('every name taken stays idle without errors', () async {
      final other = h.newClient();
      await other.requestName(mprisName);
      await other.requestName('$mprisName.instance$pid');
      for (var n = 1; n <= 5; n++) {
        await other.requestName('$mprisName.instance${pid}_$n');
      }
      final taken = [
        mprisName,
        '$mprisName.instance$pid',
        for (var n = 1; n <= 5; n++) '$mprisName.instance${pid}_$n',
      ];
      final logs = <LogRecord>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord
          .where((r) => r.loggerName == 'mpris')
          .listen(logs.add);
      addTearDown(() async {
        await subscription.cancel();
        Logger.root.level = previousLevel;
      });
      final logged = Logger.root.onRecord
          .where((r) => r.loggerName == 'mpris')
          .first
          .timeout(const Duration(seconds: 1));
      h.create();
      // The 7 requests and replies are done once the line is logged.
      await logged;
      await h.settle();
      expect(h.app.ownedNames, isEmpty);
      // Exactly the one line: no "unavailable", no error or stack trace.
      expect(logs, hasLength(1));
      final record = logs.single;
      expect(record.loggerName, 'mpris');
      expect(record.level, Level.WARNING);
      expect(record.message, 'No free bus name, media controls are off');
      expect(record.error, isNull);
      expect(record.stackTrace, isNull);
      for (final name in taken) {
        expect(await h.remoteClient.getNameOwner(name), other.uniqueName);
      }
    });
  });
}
