import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:kanaru/shared/track_menu_choice.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:kanaru/shared/widgets/track_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';

const _tracks = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
];

void main() {
  testWidgets('a right click shows the queue rows and the links', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await tester.tap(find.text('b'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    for (final label in [
      'Play next',
      'Add to queue',
      'Add to playlist…',
      'Show artist',
      'Show album',
      'Show in file manager',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the Menu key on a focused song row opens the same menu', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    final row = Focus.of(tester.element(find.text('b')));
    row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Show artist'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Show artist'), findsNothing);
    expect(row.hasPrimaryFocus, isTrue);
  });

  testWidgets('a queue row reaches the queue', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await tester.tap(find.text('b'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await settleIo(tester, h);

    final queue = h.container.read(playerServiceProvider).queue.tracks;
    expect([for (final t in queue) t.title], ['b']);
  });

  testWidgets('a song without artist or album greys out those links', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('plain'),
    ], location: '/songs');

    await tester.tap(find.text('plain'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    PopupMenuItem<TrackMenuChoice> item(String label) => tester.widget(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(PopupMenuItem<TrackMenuChoice>),
      ),
    );
    expect(item('Show artist').enabled, isFalse);
    expect(item('Show album').enabled, isFalse);
    expect(item('Show in file manager').enabled, isTrue);
  });

  testWidgets('the rows of an album page leave out Show album', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: albumLocation(const AlbumKey('ann', 'al')),
    );

    await tester.tap(find.text('b'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Show artist'), findsOneWidget);
    expect(find.text('Show album'), findsNothing);
    expect(find.text('Show in file manager'), findsOneWidget);
  });

  testWidgets('without onQueueAction there is no menu', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: TrackActionsRegion(
              trackId: 1,
              path: '/m/1.flac',
              onQueueAction: null,
              child: Text('row'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<TrackMenuChoice>), findsNothing);
  });

  testWidgets('the queue rows work without a router above the row', (
    tester,
  ) async {
    final picked = <QueueAction>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrackActionsRegion(
              trackId: 1,
              path: '/m/1.flac',
              onQueueAction: picked.add,
              child: const Text('row'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();

    expect(picked, [QueueAction.addToQueue]);
  });

  testWidgets('a link with no library database says something went wrong', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TrackActionsRegion(
              trackId: 1,
              path: '/m/1.flac',
              onQueueAction: (_) {},
              child: const Text('row'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show artist'));
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          showInFileManagerProvider.overrideWithValue((path) async {
            shown.add(path);
            return true;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrackActionsRegion(
              trackId: 1,
              path: '/m/1.flac',
              onQueueAction: (_) {},
              child: const Text('row'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show in file manager'));
    await tester.pumpAndSettle();

    expect(shown, ['/m/1.flac']);
  });
}
