import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/features/player/queue/queue_sheet_host.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

/// Frames pumped per scenario, 16 ms apart, with a position tick every
/// [_ticksEvery] frames.
const _frames = 120;
const _ticksEvery = 6;

/// What the shell cost over the measured frames.
typedef _ShellWork = ({int paints, int rebuilds, int micros});

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  /// Starts the app with a track queued, playing unless [playing] is false
  /// (a playing seek bar animates forever, so nothing would settle).
  Future<void> pumpPlayingApp(
    WidgetTester tester, {
    bool playing = true,
    bool disableAnimations = false,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/music/First Song.flac'),
    ]);
    backend.emitDuration.add(const Duration(minutes: 4));
    if (playing) backend.emitPlaying.add(true);
    await tester.pump();
  }

  /// Pumps [_frames] frames while position ticks arrive and counts the paints
  /// and rebuilds inside the shell (the first [QueueSheetHost], which the
  /// shell builds before the Now Playing overlay).
  Future<_ShellWork> measureShell(WidgetTester tester) async {
    final shell = find
        .byType(QueueSheetHost, skipOffstage: false)
        .first
        .evaluate()
        .single;
    final shellRender = shell.findRenderObject()!;
    var paints = 0;
    var rebuilds = 0;

    bool underShell(RenderObject? object) {
      for (var node = object; node != null; node = node.parent) {
        if (identical(node, shellRender)) return true;
      }
      return false;
    }

    debugProfilePaintsEnabled = true;
    debugOnProfilePaint = (object) {
      if (underShell(object)) paints++;
    };
    debugOnRebuildDirtyWidget = (element, _) {
      var inShell = identical(element, shell);
      element.visitAncestorElements((ancestor) {
        inShell = inShell || identical(ancestor, shell);
        return !inShell;
      });
      if (inShell) rebuilds++;
    };
    addTearDown(() {
      debugProfilePaintsEnabled = false;
      debugOnProfilePaint = null;
      debugOnRebuildDirtyWidget = null;
    });

    final stopwatch = Stopwatch()..start();
    for (var frame = 0; frame < _frames; frame++) {
      if (frame % _ticksEvery == 0) {
        backend.emitPosition.add(Duration(milliseconds: frame * 16));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();
    debugProfilePaintsEnabled = false;
    debugOnProfilePaint = null;
    debugOnRebuildDirtyWidget = null;
    return (
      paints: paints,
      rebuilds: rebuilds,
      micros: stopwatch.elapsedMicroseconds,
    );
  }

  testWidgets('the shell is not rebuilt or repainted while Now Playing is open '
      'and playing', (tester) async {
    await pumpPlayingApp(tester);
    // Control: the shell does paint while Now Playing is closed.
    final closed = await measureShell(tester);
    expect(closed.paints, greaterThan(0));

    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pump();
    // Past the slide, so only steady-state frames are counted.
    await tester.pump(const Duration(seconds: 1));
    final open = await measureShell(tester);

    expect(open.rebuilds, 0);
    expect(open.paints, 0);
  });

  group('drawing the shell', () {
    final shellDrawn = find.byType(Sidebar);
    void open() => container.read(nowPlayingOpenProvider.notifier).open();
    void close() => container.read(nowPlayingOpenProvider.notifier).close();

    testWidgets('stops once the slide-in finished and resumes when closing', (
      tester,
    ) async {
      await pumpPlayingApp(tester, playing: false);
      expect(shellDrawn, findsOneWidget);

      open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(shellDrawn, findsOneWidget, reason: 'still sliding in');

      await tester.pump(nowPlayingSlideDuration);
      expect(shellDrawn, findsNothing, reason: 'fully covered');

      close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(shellDrawn, findsOneWidget, reason: 'sliding out');

      await tester.pump(nowPlayingSlideDuration);
      expect(shellDrawn, findsOneWidget);
    });

    testWidgets('never stops when closed while still sliding in', (
      tester,
    ) async {
      await pumpPlayingApp(tester, playing: false);

      open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      close();
      await tester.pump();
      expect(shellDrawn, findsOneWidget);

      await tester.pump(nowPlayingSlideDuration);
      expect(shellDrawn, findsOneWidget);
    });

    testWidgets('follows the open state at once with reduced motion', (
      tester,
    ) async {
      await pumpPlayingApp(tester, playing: false, disableAnimations: true);

      open();
      await tester.pump();
      expect(shellDrawn, findsNothing);

      close();
      await tester.pump();
      expect(shellDrawn, findsOneWidget);
    });
  });
}
