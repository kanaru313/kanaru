import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_actions.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../../core/stats/gated_query_interceptor.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Finder heartIn(Type parent) => find.descendant(
    of: find.byType(parent),
    matching: find.byType(NowPlayingFavoriteButton),
  );

  IconButton iconButton(WidgetTester tester, Finder heart) => tester.widget(
    find.descendant(of: heart, matching: find.byType(IconButton)),
  );

  Future<void> play(WidgetTester tester, Track track) async {
    // The seek bar's wave never settles while music plays.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await h.container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpAndSettle();
  }

  Future<bool> stored(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => h.db.isFavorite(path)))!;

  testWidgets('the heart likes and unlikes the playing song everywhere', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final path = (await trackPaths(tester, h))['a']!;
    await settleDb(tester);
    await play(tester, Track(uri: path, title: 'a'));
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
    final inScreen = heartIn(NowPlayingScreen);
    expect(iconButton(tester, inScreen).isSelected, isFalse);
    expect(
      find.descendant(
        of: inScreen,
        matching: find.byTooltip('Add to favorites'),
      ),
      findsOneWidget,
    );

    await tester.tap(inScreen);
    await settleDb(tester);

    expect(await stored(tester, path), isTrue);
    expect(iconButton(tester, inScreen).isSelected, isTrue);
    expect(
      find.descendant(
        of: inScreen,
        matching: find.byTooltip('Remove from favorites'),
      ),
      findsOneWidget,
    );
    // No snackbar: the heart itself shows the change.
    expect(find.byType(SnackBar), findsNothing);

    // The player bar heart follows the same store.
    h.container.read(nowPlayingOpenProvider.notifier).close();
    await tester.pumpAndSettle();
    final inBar = heartIn(PlayerBar);
    expect(iconButton(tester, inBar).isSelected, isTrue);
    await tester.tap(inBar);
    await settleDb(tester);
    expect(await stored(tester, path), isFalse);
    expect(iconButton(tester, inBar).isSelected, isFalse);
  });

  testWidgets('a change made elsewhere shows on the heart', (tester) async {
    await openApp(tester, h, ['a']);
    final path = (await trackPaths(tester, h))['a']!;
    await settleDb(tester);
    await play(tester, Track(uri: path, title: 'a'));

    await tester.runAsync(() => h.db.setFavorite(path, favorite: true, now: 1));
    await settleDb(tester);

    expect(iconButton(tester, heartIn(PlayerBar)).isSelected, isTrue);
  });

  testWidgets('two quick presses end where they started', (tester) async {
    await openApp(tester, h, ['a']);
    final path = (await trackPaths(tester, h))['a']!;
    await settleDb(tester);
    await play(tester, Track(uri: path, title: 'a'));
    final heart = heartIn(PlayerBar);

    await tester.tap(heart);
    await tester.pump();
    expect(iconButton(tester, heart).isSelected, isTrue);
    await tester.tap(heart);
    await tester.pump();
    expect(iconButton(tester, heart).isSelected, isFalse);
    await settleDb(tester);
    await settleDb(tester);

    expect(await stored(tester, path), isFalse);
    expect(iconButton(tester, heart).isSelected, isFalse);
  });

  testWidgets('a press on the next song during a write is written too', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    h = LibraryHarness(refreshInterval: Duration.zero, interceptor: gate);
    await openApp(tester, h, ['a', 'b']);
    final paths = await trackPaths(tester, h);
    await settleDb(tester);
    await play(tester, Track(uri: paths['a']!, title: 'a'));
    final heart = heartIn(PlayerBar);

    // Hold the write for a while the song changes and b is liked.
    final release = gate.holdNext('SELECT 1 FROM playlist_entries e');
    await tester.tap(heart);
    await settleDb(tester);
    expect(gate.count('SELECT 1 FROM playlist_entries e'), 1);
    await play(tester, Track(uri: paths['b']!, title: 'b'));
    expect(iconButton(tester, heart).isSelected, isFalse);
    await tester.tap(heart);
    await tester.pump();
    expect(iconButton(tester, heart).isSelected, isTrue);
    // Not read back here: a read would wait behind the held write.

    release();
    await settleDb(tester);
    await settleDb(tester);

    expect(await stored(tester, paths['a']!), isTrue);
    expect(await stored(tester, paths['b']!), isTrue);
    expect(iconButton(tester, heart).isSelected, isTrue);
  });

  testWidgets('a failed write keeps the newer press on the next song', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    h = LibraryHarness(refreshInterval: Duration.zero, interceptor: gate);
    await openApp(tester, h, ['a', 'b']);
    final paths = await trackPaths(tester, h);
    await settleDb(tester);
    await play(tester, Track(uri: paths['a']!, title: 'a'));
    final heart = heartIn(PlayerBar);

    // Hold the write for a while the song changes and b is liked, then make
    // it fail: the failure must not drop the newer press on b.
    final release = gate.holdNext('SELECT 1 FROM playlist_entries e');
    gate.failNext('SELECT DISTINCT path FROM playlist_entries');
    await tester.tap(heart);
    await settleDb(tester);
    expect(gate.count('SELECT 1 FROM playlist_entries e'), 1);
    await play(tester, Track(uri: paths['b']!, title: 'b'));
    expect(iconButton(tester, heart).isSelected, isFalse);
    await tester.tap(heart);
    await tester.pump();
    expect(iconButton(tester, heart).isSelected, isTrue);
    // Not read back here: a read would wait behind the held write.

    release();
    await settleDb(tester);
    await settleDb(tester);

    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsOneWidget,
    );
    expect(await stored(tester, paths['a']!), isFalse);
    expect(await stored(tester, paths['b']!), isTrue);
    expect(iconButton(tester, heart).isSelected, isTrue);
  });

  testWidgets('a favorites read error leaves the heart usable', (tester) async {
    h = LibraryHarness(
      refreshInterval: Duration.zero,
      overrides: [
        favoritePathsProvider.overrideWith(
          (ref) => Stream<Set<String>>.error(StateError('read failed')),
        ),
      ],
    );
    await openApp(tester, h, ['a']);
    final path = (await trackPaths(tester, h))['a']!;
    await settleDb(tester);
    await play(tester, Track(uri: path, title: 'a'));
    final heart = heartIn(PlayerBar);
    expect(iconButton(tester, heart).onPressed, isNotNull);

    await tester.tap(heart);
    await settleDb(tester);

    expect(await stored(tester, path), isTrue);
    expect(iconButton(tester, heart).isSelected, isTrue);
  });

  testWidgets('a song outside the library cannot be liked', (tester) async {
    await openApp(tester, h, ['a']);
    await settleDb(tester);
    await play(tester, const Track(uri: '/elsewhere/x.mp3', title: 'x'));
    final heart = heartIn(PlayerBar);

    await tester.tap(heart);
    await settleDb(tester);

    expect(
      find.text(
        "This song isn't in your library, so it can't go in a playlist.",
      ),
      findsOneWidget,
    );
    expect(await stored(tester, '/elsewhere/x.mp3'), isFalse);
    expect(iconButton(tester, heart).isSelected, isFalse);
  });

  testWidgets('a liked song that left the library can still be unliked', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    await settleDb(tester);
    const gone = '/elsewhere/gone.mp3';
    await tester.runAsync(() => h.db.setFavorite(gone, favorite: true, now: 1));
    await play(tester, const Track(uri: gone, title: 'gone'));
    await settleDb(tester);
    final heart = heartIn(PlayerBar);
    expect(iconButton(tester, heart).isSelected, isTrue);

    await tester.tap(heart);
    await settleDb(tester);

    expect(await stored(tester, gone), isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the wide bar fits the heart at 720 px; compact has none', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final path = (await trackPaths(tester, h))['a']!;
    tester.view.physicalSize = const Size(720, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await play(tester, Track(uri: path, title: 'a'));

    expect(heartIn(PlayerBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerBar), findsOneWidget);
    expect(heartIn(PlayerBar), findsNothing);
  });

  testWidgets('without a library the heart is disabled', (tester) async {
    final container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.mp3', title: 'a'),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NowPlayingFavoriteButton()),
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
}
