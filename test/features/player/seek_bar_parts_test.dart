import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late FakeAudioBackend backend;

  Future<ProviderContainer> pump(WidgetTester tester, Widget bar) async {
    backend = FakeAudioBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SizedBox(width: 400, child: bar)),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.mp3', title: 'a'),
    ]);
    backend.emitDuration.add(const Duration(seconds: 100));
    await tester.pump();
    return container;
  }

  testWidgets('the bar shows both labels around the track', (tester) async {
    await pump(tester, const SeekBar());

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('1:40'), findsOneWidget);
    expect(find.byType(SeekTrack), findsOneWidget);
  });

  testWidgets('a given track sits between the labels', (tester) async {
    const key = Key('custom');
    await pump(tester, const SeekBar(track: SizedBox(key: key)));

    final elapsed = tester.getRect(find.byType(SeekElapsedLabel));
    final total = tester.getRect(find.byType(SeekDurationLabel));
    final custom = tester.getRect(find.byKey(key));
    expect(find.byType(SeekTrack), findsNothing);
    expect(custom.left, greaterThanOrEqualTo(elapsed.right));
    expect(custom.right, lessThanOrEqualTo(total.left));
  });

  testWidgets('the track alone has no text', (tester) async {
    await pump(tester, const SizedBox(height: 24, child: SeekTrack()));

    expect(
      find.descendant(of: find.byType(SeekTrack), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('the slot is the waveform track, flat without data', (
    tester,
  ) async {
    await pump(tester, const SeekBar(track: NowPlayingSeekSlot()));

    expect(find.byType(WaveformSeekTrack), findsOneWidget);
    expect(find.byType(SeekTrack), findsNothing);
  });

  testWidgets('the row is 24 px high by default', (tester) async {
    await pump(tester, const SeekBar());

    expect(tester.getSize(find.byType(SeekBar)).height, 24);
  });

  testWidgets('the row is as high as the track height it is given', (
    tester,
  ) async {
    await pump(
      tester,
      const SeekBar(track: NowPlayingSeekSlot(), trackHeight: 48),
    );

    expect(tester.getSize(find.byType(SeekBar)).height, 48);
  });

  testWidgets('a tap at the middle seeks to half the duration', (tester) async {
    await pump(tester, const SeekBar());
    backend.calls.clear();

    await tester.tapAt(
      tester.getCenter(find.byType(SeekTrack)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(backend.calls, ['seek(${const Duration(seconds: 50)})']);
  });

  testWidgets('the elapsed label follows the position by the second', (
    tester,
  ) async {
    await pump(tester, const SeekBar());

    backend.emitPosition.add(const Duration(milliseconds: 5400));
    await tester.pump();
    expect(find.text('0:05'), findsOneWidget);
  });
}
