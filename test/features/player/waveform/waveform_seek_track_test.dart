import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/waveform/waveform_controller.dart';
import 'package:kanaru/features/player/waveform/waveform_pictures.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';

import 'waveform_seek_track_harness.dart';

void main() {
  final h = WaveSlotHarness();

  testWidgets('without data it shows the straight track, 48 px high', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();

    expect(flatLayer, findsOneWidget);
    expect(fadeLayer, findsNothing);
    expect(tester.getSize(find.byType(WaveformSeekTrack)).height, 48);
  });

  testWidgets('a waveform that is already loaded shows at once, no fade', (
    tester,
  ) async {
    await h.start(tester);
    // Another view loaded it earlier.
    final early = h.container.read(waveformControllerProvider.notifier)
      ..attach();
    await tester.pump();
    await h.deliver(trackA);
    early.detach();
    await tester.pump();

    await h.mount();

    expect(flatLayer, findsNothing);
    expect(fadeLayer, findsOneWidget);
    expect(h.barsOpacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('data arriving later fades the bars in over 200 ms', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();
    expect(h.reader.isReading(trackA.uri), isTrue);

    await h.deliver(trackA);
    expect(flatLayer, findsOneWidget);
    expect(h.barsOpacity, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(h.barsOpacity, closeTo(0.5, 0.1));
    expect(flatLayer, findsOneWidget);

    await tester.pumpAndSettle();
    expect(h.barsOpacity, 1);
    expect(flatLayer, findsNothing);
  });

  testWidgets('with animations off the bars replace the track at once', (
    tester,
  ) async {
    await h.start(tester, reduceMotion: true);
    await h.mount();

    await h.deliver(trackA);

    expect(h.barsOpacity, 1);
    expect(flatLayer, findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a waveform before the duration: flat, then fade, then one '
      'recording per duration', (tester) async {
    await h.start(tester, duration: null);
    await h.mount();
    await h.deliver(trackA);
    expect(fadeLayer, findsNothing);
    expect(flatLayer, findsOneWidget);
    final before = WaveformPictures.recordings;

    await h.emitDuration(const Duration(seconds: 180));
    expect(fadeLayer, findsOneWidget);
    await tester.pumpAndSettle();
    expect(flatLayer, findsNothing);
    expect(WaveformPictures.recordings, before + 1);

    // The duration is corrected: the bars are recorded again, with no fade.
    await h.emitDuration(const Duration(seconds: 200));
    expect(h.barsOpacity, 1);
    expect(WaveformPictures.recordings, before + 2);
  });

  testWidgets('a cached waveform shows at once on a track change', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();
    await h.deliver(trackA);
    await h.deliver(trackB); // the prefetch of the next track
    await tester.pumpAndSettle();

    await h.player.next();
    await h.emitDuration(const Duration(minutes: 3));

    expect(fadeLayer, findsOneWidget);
    expect(flatLayer, findsNothing);
    expect(h.barsOpacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a waveform read after the track change still fades in', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();
    await h.deliver(trackA);
    await tester.pumpAndSettle();

    await h.player.next();
    await h.emitDuration(const Duration(minutes: 3));
    expect(fadeLayer, findsNothing);
    await h.deliver(trackB);

    expect(flatLayer, findsOneWidget);
    expect(h.barsOpacity, 0);
    await tester.pumpAndSettle();
    expect(h.barsOpacity, 1);
    expect(flatLayer, findsNothing);
  });

  testWidgets('a waveform of another track is never drawn', (tester) async {
    await h.start(
      tester,
      tracks: [trackB],
      overrides: [
        waveformControllerProvider.overrideWith(StaleWaveformController.new),
      ],
    );
    await h.mount();

    expect(fadeLayer, findsNothing);
    expect(flatLayer, findsOneWidget);
  });

  testWidgets('after a track change the previous track bars are gone', (
    tester,
  ) async {
    await h.start(tester);
    await h.mount();
    await h.deliver(trackA);
    await tester.pumpAndSettle();
    expect(fadeLayer, findsOneWidget);

    await h.player.openTracks([trackB]);
    await h.emitDuration(const Duration(minutes: 3));

    expect(fadeLayer, findsNothing);
    expect(flatLayer, findsOneWidget);
    expect(h.reader.isReading(trackB.uri), isTrue);

    await h.deliver(trackB);
    await tester.pumpAndSettle();
    expect(fadeLayer, findsOneWidget);
    expect(flatLayer, findsNothing);
  });
}
