import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/media_controls/mpris/mpris_properties.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:logging/logging.dart';

import 'mpris_media_controls_test.dart' show dbusError;
import 'mpris_test_harness.dart';

/// A client whose `requestName` waits until the test opens [gate], to hold
/// the controls in the window between registering and owning the name.
class _GatedClient extends DBusClient {
  _GatedClient(super.address);

  final entered = Completer<void>();
  final gate = Completer<void>();

  /// Names given back explicitly. `close()` drops the rest on its own, so
  /// only this tells whether dispose released the name itself.
  final released = <String>[];

  @override
  Future<DBusReleaseNameReply> releaseName(String name) {
    released.add(name);
    return super.releaseName(name);
  }

  @override
  Future<DBusRequestNameReply> requestName(
    String name, {
    Set<DBusRequestNameFlag> flags = const {},
  }) async {
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    return super.requestName(name, flags: flags);
  }
}

/// Runs [body] with its own harness in a zone that records the coalescing
/// timers (`harnessCoalesceWindow`). Everything, the player provider included, is created in
/// that zone: stream callbacks run in the zone that subscribed.
Future<void> withTimerLog(
  Future<void> Function(MprisHarness h, List<Timer> timers) body,
) async {
  final timers = <Timer>[];
  await runZoned(
    () async {
      final local = MprisHarness();
      await local.setUp();
      try {
        await body(local, timers);
      } finally {
        await local.tearDown();
      }
    },
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, f) {
        final timer = parent.createTimer(zone, duration, f);
        if (duration == harnessCoalesceWindow) timers.add(timer);
        return timer;
      },
    ),
  );
}

void main() {
  late MprisHarness h;
  late List<LogRecord> logs;
  late StreamSubscription<LogRecord> logSubscription;
  late Level previousLevel;

  setUp(() async {
    h = MprisHarness();
    await h.setUp();
    logs = [];
    previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    logSubscription = Logger.root.onRecord.listen(logs.add);
  });
  tearDown(() async {
    await logSubscription.cancel();
    Logger.root.level = previousLevel;
    await h.tearDown();
  });

  group('dispose', () {
    test('gives the name back', () async {
      final controls = await h.start();
      await controls.dispose();
      expect(await h.names(), isNot(contains(mprisName)));
    });

    test('before the connection is up leaves no name behind', () async {
      final controls = h.create();
      await controls.dispose();
      final names = await h.names();
      expect(names.where((n) => n.startsWith('org.mpris')), isEmpty);
    });

    test('while the name request is in flight releases the name', () async {
      final client = _GatedClient(h.address);
      h.clients.add(client);
      final controls = h.create(client: client);
      await client.entered.future;

      final disposing = controls.dispose();
      // Dispose must now wait for the request instead of closing under it.
      await h.settle(const Duration(milliseconds: 100));
      client.gate.complete();
      await disposing;

      expect(client.released, [mprisName]);
      expect(await h.names(), isNot(contains(mprisName)));
    });

    test(
      'cancels the pending change timer',
      () => withTimerLog((l, timers) async {
        await l.service.openTracks(songs);
        final controls = await l.start();
        await l.settle();
        timers.clear();

        unawaited(l.service.setVolume(40));
        expect(timers, hasLength(1));
        expect(timers.single.isActive, isTrue);
        await controls.dispose();
        expect(timers.single.isActive, isFalse);
      }),
    );

    test('with a pending change sends nothing afterwards', () async {
      await h.service.openTracks(songs);
      final controls = await h.start();
      final changes = await h.watchChanges();
      // The change is pending (timer armed) when dispose starts, however
      // short the window.
      unawaited(h.service.setVolume(40));
      await controls.dispose();
      await h.settle();
      expect(changes, isEmpty);
    });

    test('through the provider releases the name and refuses calls', () async {
      final app = h.appContainer();
      final service = app.container.read(playerServiceProvider.notifier);
      await service.openTracks(songs);
      await h.waitForName(mprisName);
      app.backend.calls.clear();

      app.container.dispose();
      // The call may reach the bus before or after the name is gone; either
      // way it must not drive the disposed player or log a problem.
      try {
        await h.call('PlayPause');
      } on DBusMethodResponseException {
        // Refused, as expected.
      }
      await h.waitForName(mprisName, gone: true);

      expect(app.backend.calls, isEmpty);
      expect(
        logs.where((r) => r.loggerName == 'mpris' && r.level >= Level.WARNING),
        isEmpty,
      );
      // The capture works: a record sent now is seen.
      Logger('mpris').severe('probe');
      expect(logs.last.message, 'probe');
    });
  });

  group('timer', () {
    test(
      'position ticks arm nothing',
      () => withTimerLog((l, timers) async {
        await l.service.openTracks(songs);
        await l.start();
        l.backend.emitDuration.add(const Duration(seconds: 90));
        await l.settle();
        timers.clear();

        for (var s = 1; s <= 3; s++) {
          l.backend.emitPosition.add(Duration(seconds: s));
        }
        expect(timers, isEmpty);
        // The timer would be armed by a change, so the zone does see them.
        unawaited(l.service.setVolume(40));
        expect(timers, hasLength(1));
      }),
    );

    test('a burst of position ticks does no property work', () async {
      var builds = 0;
      await h.service.openTracks(songs);
      h.create(
        buildProperties: (state, ids, {required artUri}) {
          builds++;
          return playerProperties(state, ids, artUri: artUri);
        },
      );
      await h.waitForName(mprisName);
      final changes = await h.watchChanges();
      await h.settle();
      final buildsAtStart = builds;

      for (var ms = 1; ms <= 1000; ms++) {
        h.backend.emitPosition.add(Duration(milliseconds: ms));
      }
      await h.settle();
      expect(builds, buildsAtStart);
      expect(changes, isEmpty);
      final position = await h.remote.getProperty(
        mprisPlayerInterface,
        'Position',
      );
      expect(position, const DBusInt64(1000000));

      // The check is not blind: a change of anything published is built.
      final next = h.nextChange();
      await h.service.setVolume(40);
      await next;
      expect(builds, buildsAtStart + 1);
    });

    test(
      'an idle controller arms nothing, whatever changes',
      () => withTimerLog((l, timers) async {
        // Nothing listens at this address: the bus never comes up.
        final dead = DBusClient(DBusAddress.unix(path: '/nonexistent/bus'));
        l.create(client: dead);
        await l.settle();
        await l.service.openTracks(songs);
        unawaited(l.service.setVolume(40));
        l.backend.emitPosition.add(const Duration(seconds: 1));
        await l.settle();
        expect(timers, isEmpty);
      }),
    );
  });

  group('seeked', () {
    test('survives a rebuild of the player provider', () async {
      await h.service.openTracks(songs);
      await h.start();
      final seeked = await h.watchSeeked();

      h.container.invalidate(playerServiceProvider);
      await h.settle();
      await h.service.openTracks(songs);
      final next = h.nextSeeked();
      await h.service.seek(const Duration(seconds: 3));
      await next;
      await h.settle();

      expect(seeked, [3000000]);
    });
  });

  group('Rate', () {
    test('0.0 pauses, 1.0 is accepted, others are refused', () async {
      await h.service.openTracks(songs);
      await h.start();
      h.backend.calls.clear();

      Future<void> setRate(double rate) =>
          h.remote.setProperty(mprisPlayerInterface, 'Rate', DBusDouble(rate));

      await setRate(1);
      expect(h.backend.calls, isEmpty);
      await expectLater(setRate(0.5), dbusError('InvalidArgs'));
      expect(h.backend.calls, isEmpty);
      await setRate(0);
      await h.settle();
      expect(h.backend.calls, ['pause']);
    });
  });

  group('app wiring', () {
    // Nothing in the UI reads mediaControlsProvider; main.dart's container
    // listener is what creates the controls at startup.
    test('without a listener the controls are never created', () async {
      final app = h.appContainer(keepAlive: false);
      addTearDown(app.container.dispose);
      await h.settle();
      expect(await h.names(), isNot(contains(mprisName)));
    });

    test('the keep-alive listener starts them and they stay', () async {
      final app = h.appContainer();
      addTearDown(app.container.dispose);
      await h.waitForName(mprisName);
      await h.settle();
      expect(await h.names(), contains(mprisName));
    });
  });
}
