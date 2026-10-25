import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/waveform/waveform.dart';

import 'waveform_harness.dart';

/// A reader with no waveforms that counts its reads.
class _CountingNoReader extends NoWaveformReader {
  int reads = 0;

  @override
  Future<WaveformReadResult> read(String path, int job) {
    reads++;
    return super.read(path, job);
  }
}

void main() {
  const a = '/m/a.mp3';
  const b = '/m/b.mp3';
  const c = '/m/c.mp3';
  const d = '/m/d.mp3';

  late WaveformHarness h;
  setUp(() => h = WaveformHarness());

  test('without a view nothing is read, even across track changes', () async {
    await h.open([a, b, c]);
    h.waveforms();
    await h.service().next();
    await h.service().jump(2);
    await h.settle();

    expect(h.reader.reads, isEmpty);
    expect(h.shown(), isNull);
  });

  test(
    'the current track is read, then the next, never both at once',
    () async {
      await h.open([a, b, c]);
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.reads, [a]);

      h.reader.found(a);
      await h.settle();
      expect(h.reader.reads, [a, b]);
      expect(h.shown()!.uri, a);

      h.reader.found(b);
      await h.settle();
      // Nothing follows the next track.
      expect(h.reader.reads, [a, b]);
      expect(h.reader.everyBegunJobWasRead, isTrue);
    },
  );

  test('a prefetch that becomes current keeps running', () async {
    await h.open([a, b, c]);
    h.waveforms().attach();
    await h.settle();
    h.reader.found(a);
    await h.settle();
    expect(h.reader.isReading(b), isTrue);

    await h.service().next();
    await h.settle();
    expect(h.reader.cancels, isEmpty);
    expect(h.shown(), isNull);

    h.reader.found(b, level: 7);
    await h.settle();
    expect(h.shown()!.uri, b);
    expect(h.shown()!.waveform.levels.single, 7);
    // The prefetch of the new next starts after it.
    expect(h.reader.reads, [a, b, c]);
  });

  test(
    'an unrelated jump cancels the job; the path loads again later',
    () async {
      await h.open([a, b, c, d]);
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.isReading(a), isTrue);

      await h.service().jump(3);
      await h.settle();
      expect(h.reader.cancels, [1]);
      expect(h.reader.reads, [a, d]);

      h.reader.found(d);
      await h.settle();
      expect(h.shown()!.uri, d);

      // Cancelled, not memoised: a is read again when it is current.
      await h.service().jump(0);
      await h.settle();
      expect(h.reader.reads, [a, d, a]);
      expect(h.reader.everyBegunJobWasRead, isTrue);
    },
  );

  test('a known waveform shows at once on a track change', () async {
    await h.open([a, b]);
    h.waveforms().attach();
    await h.settle();
    h.reader.found(a);
    await h.settle();
    h.reader.found(b);
    await h.settle();

    await h.service().next();
    expect(h.shown()!.uri, b);
    await h.service().jump(0);
    expect(h.shown()!.uri, a);
    await h.settle();
    expect(h.reader.reads, [a, b]);
  });

  test('a path with no waveform is read once, then the pump idles', () async {
    await h.open([a, b]);
    h.waveforms().attach();
    await h.settle();
    h.reader.finish(a, const WaveformAbsent());
    await h.settle();
    h.reader.finish(b, const WaveformAbsent());
    await h.settle();
    expect(h.reader.reads, [a, b]);

    await h.service().next();
    await h.service().jump(0);
    await h.settle();
    expect(h.reader.reads, [a, b]);
    expect(h.shown(), isNull);
  });

  test('the default reader ends in a bounded number of reads', () async {
    final counting = _CountingNoReader();
    h.container.dispose();
    h.container = h.create(counting);
    await h.open([a, b, c]);
    h.waveforms().attach();
    await h.settle();

    expect(counting.reads, 2);
    await h.service().next();
    await h.settle();
    expect(counting.reads, 3);
  });

  group('a temporary failure', () {
    test(
      'is asked again once per attach or track change, not in a loop',
      () async {
        await h.open([a, b]);
        h.waveforms().attach();
        await h.settle();
        h.reader.finish(a, const WaveformRetry());
        await h.settle();
        // a is skipped, b is prefetched.
        expect(h.reader.reads, [a, b]);
        h.reader.finish(b, const WaveformRetry());
        await h.settle();
        expect(h.reader.reads, [a, b]);

        h.waveforms().attach();
        await h.settle();
        expect(h.reader.reads, [a, b, a]);
        h.reader.found(a);
        await h.settle();
        expect(h.shown()!.uri, a);
        expect(h.reader.reads, [a, b, a, b]);
      },
    );

    test('is asked again after a track change and never memoised', () async {
      await h.open([a, b]);
      h.waveforms().attach();
      await h.settle();
      h.reader.finish(a, const WaveformRetry());
      await h.settle();
      h.reader.finish(b, const WaveformRetry());
      await h.settle();

      await h.service().next();
      await h.settle();
      // b is current now: asked once more; a is no longer wanted.
      expect(h.reader.reads, [a, b, b]);
      h.reader.found(b);
      await h.settle();
      expect(h.shown()!.uri, b);
    });
  });

  test('a jump to the track before keeps the job of the new next', () async {
    await h.open([a, b, c]);
    await h.service().jump(1);
    h.waveforms().attach();
    await h.settle();
    expect(h.reader.reads, [b]);

    await h.service().jump(0);
    await h.settle();
    expect(h.reader.cancels, isEmpty);
    expect(h.reader.isReading(b), isTrue);
    expect(h.shown(), isNull);

    h.reader.found(b);
    await h.settle();
    expect(h.reader.reads, [b, a]);
    h.reader.found(a);
    await h.settle();
    expect(h.shown()!.uri, a);
  });
}
