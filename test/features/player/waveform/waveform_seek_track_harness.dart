import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/waveform/waveform.dart';
import 'package:kanaru/core/waveform/waveform_controller.dart';
import 'package:kanaru/features/player/seek_track_painter.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/fake_audio_backend.dart';
import '../../../core/waveform/fake_waveform_reader.dart';

const trackA = Track(uri: '/music/a.flac', title: 'a');
const trackB = Track(uri: '/music/b.flac', title: 'b');

/// A waveform of [level] spanning [length].
Waveform loudWaveform({
  int level = 200,
  Duration length = const Duration(minutes: 3),
}) => Waveform(
  levels: Uint8List.fromList(List.filled(100, level)),
  length: length,
);

final flatLayer = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SeekTrackPainter,
);
final fadeLayer = find.descendant(
  of: find.byType(WaveformSeekTrack),
  matching: find.byType(FadeTransition),
);

/// The waveform track alone on a fake player and a fake waveform reader.
class WaveSlotHarness {
  late ProviderContainer container;
  late FakeAudioBackend backend;
  late FakeWaveformReader reader;

  PlayerService get player => container.read(playerServiceProvider.notifier);

  /// Opacity of the bars' fade layer.
  double get barsOpacity =>
      tester.widget<FadeTransition>(fadeLayer).opacity.value;

  late WidgetTester tester;

  Future<void> start(
    WidgetTester t, {
    Duration? duration = const Duration(minutes: 3),
    bool reduceMotion = false,
    List<Override> overrides = const [],
    List<Track> tracks = const [trackA, trackB],
  }) async {
    tester = t;
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    reader = FakeWaveformReader();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        waveformReaderProvider.overrideWithValue(reader),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await player.openTracks(tracks);
    if (duration != null) backend.emitDuration.add(duration);
  }

  /// Mounts the track [width] wide; the same call with another width resizes
  /// it. [wrap] puts something around it, such as a `TickerMode`. A new
  /// [slotKey] replaces the track with a new one in the same frame.
  Future<void> mount({
    double width = 400,
    Widget Function(Widget child)? wrap,
    Key? slotKey,
  }) async {
    final slot = Center(
      child: SizedBox(
        width: width,
        child: WaveformSeekTrack(key: slotKey),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: wrap == null ? slot : wrap(slot)),
        ),
      ),
    );
    await settle();
  }

  /// Lets reads begin and finish and the rebuilds they cause run.
  Future<void> settle() async {
    await tester.pump();
    await tester.pump();
  }

  /// Ends the read of [track] with [waveform] and lets the track react.
  Future<void> deliver(Track track, [Waveform? waveform]) async {
    reader.finish(track.uri, WaveformFound(waveform ?? loudWaveform()));
    await settle();
  }

  Future<void> emitDuration(Duration d) async {
    backend.emitDuration.add(d);
    await settle();
  }
}

/// A controller whose state is the waveform of track A, whatever plays.
class StaleWaveformController extends WaveformController {
  @override
  PlayingWaveform? build() {
    super.build();
    return (uri: trackA.uri, waveform: loudWaveform());
  }
}
