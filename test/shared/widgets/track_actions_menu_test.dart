import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:kanaru/shared/widgets/track_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../song_modal/song_modal_test_support.dart';

const _tracks = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
];

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

/// A region around a text row, in an app without a library.
Future<void> _pumpRegion(
  WidgetTester tester, {
  required TrackListItem song,
  ValueChanged<QueueAction>? onQueueAction,
  List<Override> overrides = const [],
  bool withRouter = false,
}) async {
  // Tall enough for every row of the modal, the Song info row included.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final region = TrackActionsRegion(
    song: song,
    onQueueAction: onQueueAction,
    child: const Text('row'),
  );
  final delegates = AppLocalizations.localizationsDelegates;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: withRouter
          ? MaterialApp.router(
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, _) => Scaffold(body: region),
                  ),
                ],
              ),
              localizationsDelegates: delegates,
              supportedLocales: AppLocalizations.supportedLocales,
            )
          : MaterialApp(
              localizationsDelegates: delegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: region),
            ),
    ),
  );
}

bool _enabled(WidgetTester tester, String id) =>
    tester.widget<ContextModalActionTile>(modalAction(id)).action.enabled;

void main() {
  testWidgets('a right click shows the header, the links and the actions', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openSongModal(tester, find.text('b'));

    expect(find.byType(SongModalHeader), findsOneWidget);
    for (final label in [
      'Go to album',
      'Go to artist',
      'Go to folder',
      'Add to playlist…',
      'Add to favorites',
      'Edit tags',
      'Song info',
      'Advanced',
      'Play next',
      'Add to queue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('Song options'), findsWidgets);
  });

  testWidgets('a long press opens the modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await tester.longPress(find.text('b'));
    await settleSongModal(tester);

    expect(find.text('Go to album'), findsOneWidget);
  });

  testWidgets('the More options button opens the modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await tester.tap(find.byTooltip('More options').first);
    await settleSongModal(tester);

    expect(find.text('Go to album'), findsOneWidget);
  });

  testWidgets('the Menu key and Shift+F10 on a focused row open the modal', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    final row = Focus.of(tester.element(find.text('b')));
    row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsNothing);
    expect(row.hasPrimaryFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('the first frame shows the header before the favorite loads', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await tester.tap(find.text('b'), buttons: kSecondaryButton);
    await tester.pump();

    expect(find.byType(SongModalHeader), findsOneWidget);
    expect(_enabled(tester, 'favorite'), isFalse);
    await settleSongModal(tester);
    expect(_enabled(tester, 'favorite'), isTrue);
  });

  testWidgets('a footer button reaches the queue and closes the modal', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openSongModal(tester, find.text('b'));
    await tester.tap(find.text('Add to queue'));
    await settleIo(tester, h);

    final queue = h.container.read(playerServiceProvider).queue.tracks;
    expect([for (final t in queue) t.title], ['b']);
    expect(find.text('Go to artist'), findsNothing);
  });

  testWidgets('a song without artist or album greys out those links', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('plain'),
    ], location: '/songs');

    await openSongModal(tester, find.text('plain'));

    expect(_enabled(tester, 'artist'), isFalse);
    expect(_enabled(tester, 'album'), isFalse);
    expect(find.text('No artist'), findsOneWidget);
    expect(find.text('No album'), findsOneWidget);
    expect(find.byTooltip('Show in file manager'), findsOneWidget);
  });

  testWidgets('the rows of an album page leave out Go to album', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: albumLocation(const AlbumKey('ann', 'al')),
    );

    await openSongModal(tester, find.text('b'));

    expect(find.text('Go to artist'), findsOneWidget);
    expect(find.text('Go to album'), findsNothing);
    expect(find.text('Go to folder'), findsOneWidget);
  });

  testWidgets('without onQueueAction there is no modal', (tester) async {
    await _pumpRegion(tester, song: _song);

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.byType(ContextModalActionTile), findsNothing);
  });

  testWidgets('the queue buttons work without a router above the row', (
    tester,
  ) async {
    final picked = <QueueAction>[];
    await _pumpRegion(tester, song: _song, onQueueAction: picked.add);

    await openSongModal(tester, find.text('row'));
    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    await openSongModal(tester, find.text('row'));
    await tester.tap(find.text('Add to playlist…'));
    await tester.pumpAndSettle();

    expect(picked, [QueueAction.addToQueue, QueueAction.addToPlaylist]);
  });

  testWidgets('a link with no library database says something went wrong', (
    tester,
  ) async {
    await _pumpRegion(
      tester,
      song: _song,
      onQueueAction: (_) {},
      withRouter: true,
    );

    await openSongModal(tester, find.text('row'));
    expect(_enabled(tester, 'artist'), isFalse);
    await tester.tap(find.text('Go to folder'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. See the log for details.'),
      findsOneWidget,
    );
    expect(find.text('This song is no longer in the library'), findsNothing);
  });

  testWidgets('Show in file manager works without a router above the row', (
    tester,
  ) async {
    final shown = <String>[];
    await _pumpRegion(
      tester,
      song: _song,
      onQueueAction: (_) {},
      overrides: [
        showInFileManagerProvider.overrideWithValue((path) async {
          shown.add(path);
          return true;
        }),
      ],
    );

    await openSongModal(tester, find.text('row'));
    await tester.tap(find.byTooltip('Show in file manager'));
    await tester.pumpAndSettle();

    expect(shown, ['/m/1.flac']);
  });

  group('Find lyrics online row', () {
    const titled = TrackListItem(
      id: 1,
      path: '/m/1.flac',
      title: 'Real title',
      artist: 'Ann',
    );

    /// Opens the Advanced page of the modal of [song] on a region with or
    /// without a library.
    Future<void> openAdvanced(
      WidgetTester tester,
      TrackListItem song, {
      bool withDatabase = true,
    }) async {
      final db = LibraryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pumpRegion(
        tester,
        song: song,
        onQueueAction: (_) {},
        overrides: [
          libraryDatabaseProvider.overrideWithValue(withDatabase ? db : null),
        ],
      );
      await openSongModal(tester, find.text('row'));
      await tapModalAction(tester, 'Advanced');
    }

    testWidgets('is shown for a local song with a real title', (tester) async {
      await openAdvanced(tester, titled);
      expect(find.text('Find lyrics online…'), findsOneWidget);
    });

    testWidgets('is hidden for a stream address, which has no folder', (
      tester,
    ) async {
      const stream = TrackListItem(
        id: 1,
        path: 'https://example.org/a.mp3',
        title: 'Real title',
      );
      await _pumpRegion(tester, song: stream, onQueueAction: (_) {});
      await openSongModal(tester, find.text('row'));
      expect(find.text('Go to folder'), findsNothing);
      await tapModalAction(tester, 'Advanced');
      expect(find.text('Find lyrics online…'), findsNothing);
    });

    testWidgets('is shown for a song with no tags', (tester) async {
      await openAdvanced(
        tester,
        const TrackListItem(id: 1, path: '/m/Real.flac', title: 'Real'),
      );
      expect(find.text('Find lyrics online…'), findsOneWidget);
    });

    testWidgets('is hidden without a library database', (tester) async {
      await openAdvanced(tester, titled, withDatabase: false);
      expect(find.text('Remove from library'), findsOneWidget);
      expect(find.text('Find lyrics online…'), findsNothing);
    });

    testWidgets('is not on the first page', (tester) async {
      await openAdvanced(tester, titled);
      await tester.tap(find.byTooltip('Back'));
      await settleSongModal(tester);
      expect(find.text('Find lyrics online…'), findsNothing);
      expect(find.text('Advanced'), findsOneWidget);

      // Unmounting disposes the modal's database stream, whose timer must end
      // before the test does.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
