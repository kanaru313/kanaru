import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Widget? lyrics}) async {
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NowPlayingScreen(lyrics: lyrics),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final toggle = find.byTooltip('Lyrics only');
  const lyrics = SizedBox.expand(child: Center(child: Text('LYRICS')));

  testWidgets('the lyrics-only button is hidden without lyrics', (
    tester,
  ) async {
    await pump(tester);

    expect(toggle, findsNothing);
    expect(find.byType(TrackArtwork), findsOneWidget);
  });

  testWidgets('with lyrics the cover takes the left half', (tester) async {
    await pump(tester, lyrics: lyrics);

    expect(toggle, findsOneWidget);
    expect(find.text('LYRICS'), findsOneWidget);
    expect(tester.getCenter(find.text('LYRICS')).dx, closeTo(960, 1));
    expect(tester.getCenter(find.byType(TrackArtwork)).dx, closeTo(320, 1));
  });

  testWidgets('the button sits at the top left and toggles the layout', (
    tester,
  ) async {
    await pump(tester, lyrics: lyrics);
    final button = tester.getRect(toggle);
    expect(button.left, lessThan(80));
    expect(button.top, lessThan(64));

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // No cover: a compact, centered title and artist over the lyrics.
    expect(find.byType(TrackArtwork), findsNothing);
    final title = tester.getRect(find.text('First Song'));
    expect(title.center.dx, closeTo(640, 1));
    expect(tester.getCenter(find.text('Artist')).dx, closeTo(640, 1));
    expect(title.top, lessThan(120));
    final text = tester.widget<Text>(find.text('First Song'));
    expect(text.style?.fontWeight, FontWeight.bold);
    // The lyrics fill the area below, across the whole width.
    expect(tester.getCenter(find.text('LYRICS')).dx, closeTo(640, 1));
    expect(tester.getCenter(find.text('LYRICS')).dy, greaterThan(title.bottom));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(TrackArtwork), findsOneWidget);
  });

  testWidgets('the button hides with the rest of the header', (tester) async {
    await pump(tester, lyrics: lyrics);

    await tester.pump(const Duration(seconds: 4));

    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: toggle, matching: find.byType(AnimatedOpacity)).first,
    );
    expect(opacity.opacity, 0);
  });
}
