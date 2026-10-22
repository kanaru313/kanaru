import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_actions.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/library_test_harness.dart';
import 'add_to_playlist_test_support.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  /// Opens Now Playing on [track].
  Future<void> openNowPlaying(WidgetTester tester, Track track) async {
    // The seek bar's wave never settles while music plays.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await h.container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpAndSettle();
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  final button = find.descendant(
    of: find.byType(NowPlayingScreen),
    matching: find.byTooltip('Add to playlist'),
  );

  testWidgets('a library song goes in the chosen playlist', (tester) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', const []);
    final paths = await trackPaths(tester, h);
    await settleDb(tester);
    await openNowPlaying(tester, Track(uri: paths['a']!, title: 'a'));

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(inPicker('Mix'));
    await settleDb(tester);

    expect(find.text('Added to Mix: a'), findsOneWidget);
    expect(await storedPaths(tester, h, id), [paths['a']]);
  });

  testWidgets('a song that is not in the library says so', (tester) async {
    await openApp(tester, h, ['a']);
    await seedPlaylist(tester, h, 'Mix', const []);
    await settleDb(tester);
    await openNowPlaying(
      tester,
      const Track(uri: '/elsewhere/x.mp3', title: 'x'),
    );

    await tester.tap(button);
    await settleDb(tester);

    expect(picker, findsNothing);
    expect(
      find.text(
        "This song isn't in your library, so it can't go in a playlist.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a current song the button is disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NowPlayingPlaylistButton()),
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
}
