import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/playlists/playlist_filter_results.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/album_modal/album_more_button.dart';
import 'package:kanaru/shared/artist_modal/artist_more_button.dart';
import 'package:kanaru/shared/enqueue_tracks.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_modal/playlist_modal_test_support.dart';
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
      await tester.tap(find.byType(AlbumMoreButton));
      await tester.pumpAndSettle();
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
      await tester.tap(find.byType(ArtistMoreButton));
      await tester.pumpAndSettle();
      await expectItem(tester);
      await openMenuOf(tester, find.text('a2'));
      await expectItem(tester);
    });

    testWidgets('search song', (tester) async {
      await openSearch(tester, h, 'adele');
      await openMenuOf(tester, find.text('Hello'));
      await expectItem(tester);
    });

    testWidgets('playlist modal and row', (tester) async {
      await openApp(tester, h, ['a']);
      final id = await seedPlaylist(tester, h, 'Mix', ['a']);
      goTo(tester, h, '/playlists/$id');
      await settleDb(tester);

      await openPageModal(tester);
      expect(modalAction('add-to-playlist'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await openMenuOf(tester, find.text('a'));
      await expectItem(tester);
    });
  });

  group('a playlist row', () {
    Future<void> openMixAndTarget(WidgetTester tester) async {
      await openApp(tester, h, ['a', 'b']);
      final mix = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
      await seedPlaylist(tester, h, 'Target', [], now: 2);
      goTo(tester, h, '/playlists/$mix');
      await settleDb(tester);
    }

    Future<void> expectOnlyTarget(WidgetTester tester) async {
      await tester.tap(find.text(_item));
      await tester.pumpAndSettle();
      expect(picker, findsOneWidget);
      expect(inPicker('Target'), findsOneWidget);
      expect(inPicker('Mix'), findsNothing);
    }

    testWidgets('leaves its own playlist out of the picker', (tester) async {
      await openMixAndTarget(tester);
      await openMenuOf(tester, find.text('a'));
      await expectOnlyTarget(tester);
    });

    testWidgets('a filter result row leaves it out too', (tester) async {
      await openMixAndTarget(tester);
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(InPageSearchBox),
          matching: find.byType(TextField),
        ),
        'a',
      );
      await tester.pump(const Duration(milliseconds: 150));
      await settleDb(tester);
      await openMenuOf(
        tester,
        find.descendant(
          of: find.byType(PlaylistFilterResults),
          matching: find.text('a'),
        ),
      );
      await expectOnlyTarget(tester);
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
