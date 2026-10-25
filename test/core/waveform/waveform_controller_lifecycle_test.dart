import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/waveform/waveform_controller.dart';

import 'waveform_harness.dart';

void main() {
  const a = '/m/a.mp3';
  const b = '/m/b.mp3';
  const c = '/m/c.mp3';
  const d = '/m/d.mp3';

  late WaveformHarness h;
  setUp(() => h = WaveformHarness());

  group('views', () {
    test('the last one leaving cancels after a microtask', () async {
      await h.open([a, b]);
      h.waveforms()
        ..attach()
        ..detach();
      await h.settle();
      expect(h.reader.cancels, [1]);
      expect(h.reader.isReading(a), isFalse);
      // Nothing else starts.
      expect(h.reader.reads, [a]);
      expect(h.reader.everyBegunJobWasRead, isTrue);
    });

    test('leaving and attaching in the same turn cancels nothing', () async {
      await h.open([a, b]);
      final controller = h.waveforms()..attach();
      await h.settle();

      controller
        ..detach()
        ..attach();
      await h.settle();
      expect(h.reader.cancels, isEmpty);
      expect(h.reader.isReading(a), isTrue);
    });

    test('one view of two leaving cancels nothing', () async {
      await h.open([a, b]);
      final controller = h.waveforms()
        ..attach()
        ..attach();
      await h.settle();
      controller.detach();
      await h.settle();
      expect(h.reader.cancels, isEmpty);
    });

    test('leaving creates no timer', () async {
      await h.open([a, b]);
      final controller = h.waveforms()..attach();
      await h.settle();
      var timers = 0;
      runZoned(
        controller.detach,
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, f) {
            timers++;
            return parent.createTimer(zone, duration, f);
          },
        ),
      );
      await h.settle();
      expect(timers, 0);
      expect(h.reader.cancels, [1]);
    });

    test('a job being started when cancelled is still read', () async {
      h.reader.holdBegin = Completer<void>();
      await h.open([a, b, c, d]);
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.begun, isEmpty);

      await h.service().jump(3);
      h.reader.holdBegin!.complete();
      h.reader.holdBegin = null;
      await h.settle();

      // Cancelled as soon as it was begun, still read so it is freed.
      expect(h.reader.cancels, [1]);
      expect(h.reader.readJobs.first, 1);
      expect(h.reader.reads.last, d);
      expect(h.reader.everyBegunJobWasRead, isTrue);
    });
  });

  group('following the player', () {
    test('a paused subscriber still gets loads and track changes', () async {
      final sub = h.container.listen(waveformControllerProvider, (_, _) {});
      sub.pause();
      await h.open([a, b]);
      h.waveforms().attach();
      await h.settle();
      h.reader.found(a);
      await h.settle();
      expect(h.shown()!.uri, a);

      h.reader.found(b);
      await h.settle();
      await h.service().next();
      expect(h.shown()!.uri, b);
    });

    test('with no listener the current track is still tracked', () async {
      await h.open([a, b]);
      h.waveforms();
      await h.service().next();
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.reads, [b]);

      h.reader.found(b);
      await h.settle();
      expect(h.shown()!.uri, b);
    });

    test('the notifier is the same instance across track changes', () async {
      final before = h.waveforms();
      await h.open([a, b, c]);
      await h.service().next();
      await h.service().next();
      await h.settle();
      expect(identical(h.waveforms(), before), isTrue);
    });

    test(
      'a queue edit that keeps the track keeps the shown waveform',
      () async {
        await h.open([a, b, c]);
        h.waveforms().attach();
        await h.settle();
        h.reader.found(a);
        await h.settle();
        final before = h.shown();

        await h.service().removeTrack(2);
        await h.settle();
        expect(h.shown(), same(before));
      },
    );
  });
}
