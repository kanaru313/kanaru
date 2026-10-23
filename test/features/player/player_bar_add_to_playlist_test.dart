import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import '../playlists/add_to_playlist_test_support.dart';
import '../playlists/playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  final button = find.descendant(
    of: find.byType(PlayerBar),
    matching: find.byTooltip('Add to playlist'),
  );

  Future<void> play(WidgetTester tester, Track track) async {
    await h.container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpAndSettle();
  }

  testWidgets('the wide bar adds the current library song to a playlist', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', const []);
    final paths = await trackPaths(tester, h);
    await settleDb(tester);
    await play(tester, Track(uri: paths['a']!, title: 'a'));

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(inPicker('Mix'));
    await settleDb(tester);

    expect(await storedPaths(tester, h, id), [paths['a']]);
  });

  testWidgets('a song outside the library says so, with no picker', (
    tester,
  ) async {
    await openApp(tester, h, ['a']);
    await settleDb(tester);
    await play(tester, const Track(uri: '/elsewhere/x.mp3', title: 'x'));

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

  testWidgets('the compact bar has no such button', (tester) async {
    await openApp(tester, h, ['a']);
    final paths = await trackPaths(tester, h);
    tester.view.physicalSize = const Size(400, 800);
    await play(tester, Track(uri: paths['a']!, title: 'a'));

    expect(find.byType(PlayerBar), findsOneWidget);
    expect(button, findsNothing);
  });
}
