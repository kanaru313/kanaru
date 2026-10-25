import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'waveform_harness.dart';

void main() {
  const a = '/m/a.mp3';
  const b = '/m/b.mp3';

  late WaveformHarness h;
  setUp(() => h = WaveformHarness());

  group('errors and edges', () {
    test(
      'a throwing reader gives null, logs no path, and the next runs',
      () async {
        final records = <LogRecord>[];
        final previous = Logger.root.level;
        Logger.root.level = Level.ALL;
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(() async {
          await sub.cancel();
          Logger.root.level = previous;
        });
        h.reader.throwing.add(a);

        await h.open([a, b]);
        h.waveforms().attach();
        await h.settle();

        expect(h.shown(), isNull);
        expect(h.reader.reads, [a, b]);
        final ours = records.where((r) => r.loggerName == 'waveform').toList();
        expect(ours, hasLength(1));
        expect(ours.single.message, isNot(contains('/m/')));
        expect(h.reader.everyBegunJobWasRead, isTrue);
      },
    );

    test('a track that is not a local file is not read', () async {
      await h.open(['https://example.test/a.mp3']);
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.reads, isEmpty);
      expect(h.shown(), isNull);
    });

    test('a file:// uri is read by its path', () async {
      await h.open(['file:///m/a.mp3']);
      h.waveforms().attach();
      await h.settle();
      expect(h.reader.reads, [a]);
      h.reader.found(a);
      await h.settle();
      expect(h.shown()!.uri, 'file:///m/a.mp3');
    });

    test(
      'disposing the container cancels the job and drops its result',
      () async {
        await h.open([a, b]);
        h.waveforms().attach();
        await h.settle();

        h.container.dispose();
        await h.settle();
        expect(h.reader.cancels, [1]);
        expect(h.reader.isReading(a), isFalse);
        expect(h.reader.reads, [a]);
        expect(h.reader.everyBegunJobWasRead, isTrue);
      },
    );
  });

  test('disposing while a job is starting still reads the job', () async {
    h.reader.holdBegin = Completer<void>();
    await h.open([a, b]);
    h.waveforms().attach();
    await h.settle();
    expect(h.reader.begun, isEmpty);

    h.container.dispose();
    h.reader.holdBegin!.complete();
    await h.settle();
    expect(h.reader.begun, [1]);
    expect(h.reader.everyBegunJobWasRead, isTrue);
    expect(h.reader.cancels, [1]);
  });
}
