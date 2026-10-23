import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';

import 'manual_fade_clock.dart';

void main() {
  late ManualFadeClock time;
  late List<double> sent;
  late bool valid;
  late int interrupted;
  Completer<void>? gate;

  PlaybackFade fade() => PlaybackFade(
    clock: time.clock,
    apply: (gain) {
      sent.add(gain);
      return gate?.future ?? Future.value();
    },
    check: () => valid,
    onInterrupted: () => interrupted++,
  );

  setUp(() {
    time = ManualFadeClock();
    sent = [];
    valid = true;
    interrupted = 0;
    gate = null;
  });

  test('ramps linearly to the target, then reports done', () async {
    final f = fade()..gain = 0;
    var done = 0;
    f.run(
      to: 1,
      length: const Duration(milliseconds: 100),
      onDone: () => done++,
    );
    expect(f.active, isTrue);

    await time.advance(const Duration(milliseconds: 50));
    expect(f.gain, closeTo(0.5, 1e-9));
    expect(done, 0);

    await time.advance(const Duration(milliseconds: 50));
    expect(f.active, isFalse);
    expect(f.gain, 1);
    expect(sent.last, 1);
    expect(done, 1);
    expect(time.activeTimers, 0);
  });

  test('a zero length sets the target at once', () async {
    final f = fade();
    var done = 0;
    f.run(to: 0, length: Duration.zero, onDone: () => done++);
    await pumpMicrotasks();
    expect(sent, [0]);
    expect(f.gain, 0);
    expect(done, 1);
    expect(time.activeTimers, 0);
  });

  test(
    'a new run reverses from where the gain is, dropping the old done',
    () async {
      final f = fade();
      var outDone = 0;
      var inDone = 0;
      f.run(
        to: 0,
        length: const Duration(milliseconds: 100),
        onDone: () => outDone++,
      );
      expect(f.towardSilence, isTrue);
      await time.advance(const Duration(milliseconds: 25));
      expect(f.gain, closeTo(0.75, 1e-9));

      f.run(
        to: 1,
        length: const Duration(milliseconds: 50),
        onDone: () => inDone++,
      );
      expect(f.towardSilence, isFalse);
      await time.advance(const Duration(milliseconds: 25));
      expect(f.gain, closeTo(0.875, 1e-9));
      await time.advance(const Duration(milliseconds: 25));
      expect(f.gain, 1);
      expect(inDone, 1);
      expect(outDone, 0);
    },
  );

  test('cancel stops the ramp without done or more sends', () async {
    final f = fade();
    var done = 0;
    f.run(
      to: 0,
      length: const Duration(milliseconds: 100),
      onDone: () => done++,
    );
    await time.advance(const Duration(milliseconds: 25));
    final before = sent.length;

    f.cancel();
    await time.advance(const Duration(milliseconds: 200));

    expect(sent, hasLength(before));
    expect(done, 0);
    expect(f.active, isFalse);
  });

  test('a failed check interrupts instead of stepping', () async {
    final f = fade();
    var done = 0;
    f.run(
      to: 0,
      length: const Duration(milliseconds: 100),
      onDone: () => done++,
    );
    await time.advance(const Duration(milliseconds: 25));
    final before = sent.length;

    valid = false;
    await time.advance(const Duration(milliseconds: 25));

    expect(interrupted, 1);
    expect(sent, hasLength(before));
    expect(done, 0);
    expect(f.active, isFalse);
  });

  test('only one volume is in flight; the newest waits', () async {
    final f = fade();
    gate = Completer<void>();
    f.run(to: 0, length: const Duration(milliseconds: 100), onDone: () {});
    await time.advance(const Duration(milliseconds: 75));
    expect(sent, [closeTo(0.75, 1e-9)], reason: 'later ticks wait');

    final slow = gate!;
    gate = null;
    slow.complete();
    await pumpMicrotasks();
    expect(sent, [closeTo(0.75, 1e-9), closeTo(0.25, 1e-9)]);
  });

  test('done waits for the last volume to land', () async {
    final f = fade();
    gate = Completer<void>();
    var done = 0;
    f.run(
      to: 0,
      length: const Duration(milliseconds: 50),
      onDone: () => done++,
    );
    await time.advance(const Duration(milliseconds: 50));
    expect(done, 0);

    final slow = gate!;
    gate = null;
    slow.complete();
    await pumpMicrotasks();
    expect(sent.last, 0);
    expect(done, 1);
  });

  test('a failing volume is logged and the fade goes on', () async {
    final f = PlaybackFade(
      clock: time.clock,
      apply: (gain) async => throw Exception('engine'),
      check: () => true,
      onInterrupted: () {},
    );
    var done = 0;
    f.run(
      to: 0,
      length: const Duration(milliseconds: 50),
      onDone: () => done++,
    );
    await time.advance(const Duration(milliseconds: 50));
    await pumpMicrotasks();
    expect(done, 1);
  });
}
