import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:logging/logging.dart';

import '../player/fake_audio_backend.dart';
import 'mpris_test_harness.dart';

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

  test(
    'a bad bus address logs one line and leaves the controls idle',
    () async {
      final controls = h.create(
        factory: () => throw const FormatException('bad address'),
      );
      await h.settle(const Duration(milliseconds: 100));

      expect(logs, hasLength(1));
      final record = logs.single;
      expect(record.loggerName, 'mpris');
      expect(record.level, Level.WARNING);
      expect(record.message, 'MPRIS unavailable');
      expect('${record.error}', 'FormatException: bad address');
      expect(record.stackTrace, isNull);
      expect(await h.names(), isNot(contains(mprisName)));
      await controls.dispose();
      expect(logs, hasLength(1));
    },
  );

  test(
    'a flush while the player cannot be read logs and sends nothing',
    () async {
      var failing = false;
      final backend = FakeAudioBackend();
      final c = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWith((ref) {
            if (failing) throw StateError('engine gone');
            return backend;
          }),
        ],
      );
      addTearDown(c.dispose);
      c.listen(playerServiceProvider, (_, _) {}, onError: (_, _) {});
      h.create(from: c, coalesceWindow: const Duration(milliseconds: 50));
      await h.waitForName(mprisName);
      final changes = await h.watchChanges();

      // A change arms the flush timer; the player breaks before it fires.
      await c.read(playerServiceProvider.notifier).openTracks(songs);
      failing = true;
      c.invalidate(audioBackendProvider);
      await h.settle(const Duration(milliseconds: 150));

      expect(changes, isEmpty);
      final warnings = logs.where(
        (r) =>
            r.loggerName == 'mpris' && r.message == 'Not publishing a change',
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.level, Level.WARNING);
    },
  );

  group('seeked after a failed rebuild', () {
    test(
      'does not spin on the closed stream, resumes after a good rebuild',
      () async {
        // Timer.run (zero duration) is what a resubscribe loop would spawn.
        var zeroTimers = 0;
        await runZoned(
          () async {
            var failing = false;
            final backend = FakeAudioBackend();
            final c = ProviderContainer(
              overrides: [
                audioBackendProvider.overrideWith((ref) {
                  if (failing) throw StateError('engine gone');
                  return backend;
                }),
              ],
            );
            addTearDown(c.dispose);
            // The failed rebuild reports to this listener, not to the zone.
            c.listen(playerServiceProvider, (_, _) {}, onError: (_, _) {});
            await c.read(playerServiceProvider.notifier).openTracks(songs);
            h.create(from: c);
            await h.waitForName(mprisName);
            final seeked = await h.watchSeeked();

            failing = true;
            c.invalidate(audioBackendProvider);
            await h.settle();
            expect(zeroTimers, lessThan(10));

            failing = false;
            c.invalidate(audioBackendProvider);
            await h.settle();
            final service = c.read(playerServiceProvider.notifier);
            await service.openTracks(songs);
            final next = h.nextSeeked();
            await service.seek(const Duration(seconds: 3));
            await next;
            await h.settle();
            expect(seeked, [3000000]);
            expect(zeroTimers, lessThan(20));
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              if (duration == Duration.zero) zeroTimers++;
              return parent.createTimer(zone, duration, f);
            },
          ),
        );
      },
    );
  });
}
