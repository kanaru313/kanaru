import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  Widget app(ProviderContainer container, Widget? lyrics) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NowPlayingScreen(lyrics: lyrics),
        ),
      );

  Future<ProviderContainer> pump(WidgetTester tester, {Widget? lyrics}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.flac', title: 'First Song', artist: 'Artist'),
    ]);
    await tester.pumpWidget(app(container, lyrics));
    await tester.pumpAndSettle();
    return container;
  }

  final cover = find.descendant(
    of: find.byType(NowPlayingTrackColumn),
    matching: find.byType(TrackArtwork),
  );
  const lyrics = SizedBox.expand(child: Center(child: Text('LYRICS')));

  testWidgets('without lyrics the side pane is the queue alone', (
    tester,
  ) async {
    await pump(tester);

    expect(find.widgetWithText(Tab, 'Lyrics'), findsNothing);
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(cover, findsOneWidget);
  });

  testWidgets('with lyrics they open in the second column, beside the cover', (
    tester,
  ) async {
    await pump(tester, lyrics: lyrics);

    expect(find.widgetWithText(Tab, 'Lyrics'), findsOneWidget);
    expect(find.text('LYRICS'), findsOneWidget);
    final column = tester.getRect(find.byType(NowPlayingTrackColumn));
    expect(tester.getCenter(cover).dx, closeTo(column.center.dx, 1));
    expect(tester.getCenter(find.text('LYRICS')).dx, greaterThan(column.right));
    // The cover stays whether or not lyrics are there.
    expect(cover, findsOneWidget);
  });

  testWidgets('the header fades out while the lyrics and the cover stay', (
    tester,
  ) async {
    await pump(tester, lyrics: lyrics);

    await tester.pump(const Duration(seconds: 4));

    final opacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byTooltip('Close Now Playing'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(opacity.opacity, 0);
    // The columns stay.
    expect(find.text('LYRICS'), findsOneWidget);
    expect(cover, findsOneWidget);
  });

  testWidgets('tabs slide with animations on, also when lyrics come and go', (
    tester,
  ) async {
    // Animations are on here: the test binding does not ask for reduced
    // motion unless told to.
    final container = await pump(tester, lyrics: lyrics);

    await tester.tap(find.widgetWithText(Tab, 'Now playing'));
    await tester.pump(const Duration(milliseconds: 100));
    // Lyrics leave while the slide is still running.
    await tester.pumpWidget(app(container, null));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(app(container, lyrics));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(Tab, 'Lyrics'), findsOneWidget);
    // The Queue tab the user picked is still the one shown.
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('LYRICS'), findsNothing);
  });
}
