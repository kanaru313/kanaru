import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/waveform/waveform_pictures.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';

import 'waveform_seek_track_harness.dart';

void main() {
  final h = WaveSlotHarness();

  /// Mounts the track with the bars of track A showing.
  Future<void> showBars(WidgetTester tester, {double width = 400}) async {
    await h.start(tester);
    await h.mount(width: width);
    await h.deliver(trackA);
    await tester.pumpAndSettle();
    expect(flatLayer, findsNothing);
  }

  testWidgets('twenty position ticks record the bars once', (tester) async {
    await showBars(tester);
    final before = WaveformPictures.recordings;

    for (var i = 1; i <= 20; i++) {
      h.backend.emitPosition.add(Duration(milliseconds: i * 250));
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(WaveformPictures.recordings, before);
    expect(fadeLayer, findsOneWidget);
  });

  testWidgets('a new width records the bars once more', (tester) async {
    await showBars(tester);
    final before = WaveformPictures.recordings;

    await h.mount(width: 300);

    expect(WaveformPictures.recordings, before + 1);
    expect(tester.getSize(find.byType(WaveformSeekTrack)).width, 300);
  });

  testWidgets('a tap at the middle seeks to half the duration', (tester) async {
    await showBars(tester);
    h.backend.calls.clear();

    await tester.tapAt(
      tester.getCenter(find.byType(WaveformSeekTrack)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(h.backend.calls, ['seek(${const Duration(seconds: 90)})']);
  });

  testWidgets('hovering shows the time under the pointer', (tester) async {
    await showBars(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.byType(WaveformSeekTrack)));
    await tester.pump();

    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('a hidden track still loads and schedules no frame on ticks', (
    tester,
  ) async {
    await h.start(tester);
    Widget ticker(bool on, Widget child) =>
        TickerMode(enabled: on, child: child);
    await h.mount(wrap: (child) => ticker(false, child));
    expect(h.reader.isReading(trackA.uri), isTrue);

    h.backend.emitPosition.add(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 250));
    h.backend.emitPosition.add(const Duration(seconds: 31));
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);

    // Data that lands while hidden builds nothing and starts no fade...
    await h.deliver(trackA);
    expect(tester.binding.transientCallbackCount, 0);
    expect(fadeLayer, findsNothing);

    // ...it runs once the tickers are back.
    await h.mount(wrap: (child) => ticker(true, child));
    await tester.pumpAndSettle();
    expect(h.barsOpacity, 1);
    expect(flatLayer, findsNothing);
  });

  testWidgets('unmounting detaches without an error and cancels the read', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();
    expect(h.reader.isReading(trackA.uri), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(h.reader.cancels, isNotEmpty);
    expect(h.reader.isReading(trackA.uri), isFalse);
  });

  testWidgets('swapping the track for another in one frame cancels nothing', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount(slotKey: const Key('first'));
    expect(h.reader.isReading(trackA.uri), isTrue);

    // A new key unmounts the old track and mounts a new one in one frame.
    await h.mount(slotKey: const Key('second'));

    expect(h.reader.cancels, isEmpty);
    expect(h.reader.isReading(trackA.uri), isTrue);
    expect(tester.takeException(), isNull);
  });
}
