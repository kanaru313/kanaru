import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/enqueue_tracks.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../search/search_test_data.dart';
import 'add_to_playlist_test_support.dart';
import 'playlist_test_data.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
];

const _item = 'Add to playlist…';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<void> expectItem(WidgetTester tester) async {
    expect(find.text(_item), findsOneWidget);
    expect(find.text('Play next'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);
    // Close the menu again.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  Future<void> headerMenu(
    WidgetTester tester, {
    String tooltip = 'Queue actions',
  }) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  group('every menu offers it', () {
    testWidgets('song row', (tester) async {
      await openWithTracks(tester, h, _tracks, location: '/songs');
      await openMenuOf(tester, find.text('a1'));
      await expectItem(tester);
    });

    testWidgets('album tile', (tester) async {
      await openWithTracks(tester, h, _tracks, location: '/albums');
      await openMenuOf(tester, find.text('Alpha'));
      await expectItem(tester);
    });

    testWidgets('album page header and track', (tester) async {
      await openWithTracks(
        tester,
        h,
        _tracks,
        location: albumLocation(const AlbumKey('ann', 'alpha')),
      );
      await headerMenu(tester);
      await expectItem(tester);
      await openMenuOf(tester, find.text('a2'));
      await expectItem(tester);
    });

    testWidgets('artist row, page header and song', (tester) async {
      await openWithTracks(tester, h, _tracks, location: '/artists');
      await openMenuOf(tester, find.text('Ann'));
      await expectItem(tester);

      goTo(tester, h, artistLocation('ann'));
      await tester.pumpAndSettle();
      await headerMenu(tester);
      await expectItem(tester);
      await openMenuOf(tester, find.text('a2'));
      await expectItem(tester);
    });

    testWidgets('search song', (tester) async {
      await openSearch(tester, h, 'adele');
      await openMenuOf(tester, find.text('Hello'));
      await expectItem(tester);
    });

    testWidgets('playlist header and row', (tester) async {
      await openApp(tester, h, ['a']);
      final id = await seedPlaylist(tester, h, 'Mix', ['a']);
      goTo(tester, h, '/playlists/$id');
      await settleDb(tester);

      await headerMenu(tester, tooltip: 'Playlist actions');
      await expectItem(tester);
      await openMenuOf(tester, find.text('a'));
      await expectItem(tester);
    });
  });

  testWidgets('enqueueTracks refuses it, as it is no queue action', (
    tester,
  ) async {
    late WidgetRef ref;
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (c, r, _) {
              ref = r;
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      () => enqueueTracks(
        ref,
        ScaffoldMessenger.of(context),
        context.l10n,
        QueueAction.addToPlaylist,
        () async => <Track>[],
        'x',
      ),
      throwsArgumentError,
    );
  });
}
