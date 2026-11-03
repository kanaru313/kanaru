import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/queue_history_queries.dart';
import 'package:kanaru/core/database/queue_history_writes.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_more_button.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/queue_history_screen.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/page_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  /// Saves a queue of the stored tracks titled [titles] at [now].
  Future<int> seedQueue(
    WidgetTester tester,
    List<String> titles, {
    int now = 1,
    List<String> extraPaths = const [],
  }) async {
    final paths = await trackPaths(tester, h);
    await tester.runAsync(
      () => h.db.recordQueueSnapshot([
        for (final t in titles) paths[t]!,
        ...extraPaths,
      ], now: now),
    );
    final snapshots = await tester.runAsync(h.db.queueSnapshots);
    return snapshots!.firstWhere((s) => s.savedAt == now).id;
  }

  List<String> queueTitles() => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  /// [title] as the page title, not as the sidebar label.
  Finder pageTitle(String title) => find.descendant(
    of: find.byType(PageScaffold),
    matching: find.text(title),
  );

  Finder row() => find.byType(QueueSnapshotRow);

  testWidgets('with nothing saved the page says how it fills', (tester) async {
    await openApp(tester, h, ['a'], location: '/queue-history');
    expect(find.text('No queue history yet'), findsOneWidget);
  });

  testWidgets('lists saved queues newest first with their song count', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b', 'c']);
    final older = DateTime(2026, 3, 4, 9, 5).millisecondsSinceEpoch;
    final newer = DateTime(2026, 10, 22, 21, 30).millisecondsSinceEpoch;
    await seedQueue(tester, ['a', 'b'], now: older);
    await seedQueue(tester, ['c', 'b', 'a'], now: newer);
    goTo(tester, h, '/queue-history');
    await settleDb(tester);

    expect(row(), findsNWidgets(2));
    final first = tester.getTopLeft(find.text('Oct 22, 2026 · 21:30')).dy;
    final second = tester.getTopLeft(find.text('Mar 4, 2026 · 09:05')).dy;
    expect(first, lessThan(second));
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('2 songs'), findsOneWidget);
  });

  testWidgets('play replaces the queue with the saved one', (tester) async {
    await openApp(tester, h, ['a', 'b', 'c']);
    await seedQueue(tester, ['c', 'a'], extraPaths: ['/gone/x.flac']);
    goTo(tester, h, '/queue-history');
    await settleDb(tester);

    await tester.tap(find.byTooltip('Play'));
    await settleDb(tester);
    expect(queueTitles(), ['c', 'a']);
  });

  testWidgets('a right click opens the Queue modal', (tester) async {
    await openApp(tester, h, ['a', 'b', 'c']);
    await seedQueue(tester, ['a', 'b', 'c']);
    goTo(tester, h, '/queue-history');
    await settleDb(tester);

    await tester.tap(row(), buttons: kSecondaryButton);
    await settleModal(tester);
    expect(
      find.byKey(const ValueKey('context-modal-action-play-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-modal-action-delete')),
      findsOneWidget,
    );
  });

  testWidgets('a saved queue page opens the Queue modal from its button', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b']);
    final id = await seedQueue(tester, ['a', 'b']);
    goTo(tester, h, '/queue-history/$id');
    await settleDb(tester);

    expect(find.byType(PlaylistMoreButton), findsOneWidget);
    expect(find.byTooltip('Playlist actions'), findsNothing);
    await tester.tap(find.byType(PlaylistMoreButton));
    await settleModal(tester);
    expect(
      find.byKey(const ValueKey('context-modal-action-play-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-modal-action-edit')),
      findsNothing,
    );
  });

  testWidgets('a queue history row menu button says More options', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b']);
    await seedQueue(tester, ['a', 'b']);
    goTo(tester, h, '/queue-history');
    await settleDb(tester);

    expect(
      find.descendant(of: row(), matching: find.byTooltip('More options')),
      findsOneWidget,
    );
    // The tooltip is on the row's ⋮ itself.
    expect(
      find.descendant(
        of: find.descendant(
          of: row(),
          matching: find.byTooltip('More options'),
        ),
        matching: find.byIcon(AppIcons.more),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a saved queue row modal says Remove from queue', (tester) async {
    await openApp(tester, h, ['a', 'b']);
    final id = await seedQueue(tester, ['a', 'b']);
    goTo(tester, h, '/queue-history/$id');
    await settleDb(tester);

    await tester.tap(
      find.byType(PlaylistEntryTile).first,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Remove from queue'), findsOneWidget);
    expect(find.text('Remove from playlist'), findsNothing);
  });

  testWidgets('a row opens the saved queue, named by when it was saved', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b']);
    final when = DateTime(2026, 10, 22, 21, 30).millisecondsSinceEpoch;
    final id = await seedQueue(tester, ['b', 'a'], now: when);
    goTo(tester, h, '/queue-history');
    await settleDb(tester);

    await tester.tap(find.text('Oct 22, 2026 · 21:30'));
    await settleDb(tester);
    expect(find.byType(PlaylistEntryTile), findsNWidgets(2));
    expect(shownTitles(tester), ['b', 'a']);
    expect(find.text('Oct 22, 2026 · 21:30'), findsOneWidget);
    expect(h.container.read(playerServiceProvider).queue.isEmpty, isTrue);

    await tester.tap(find.text('a'));
    await settleDb(tester);
    expect(queueTitles(), ['b', 'a']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'a');
    expect(id, isPositive);
  });

  testWidgets('an ordinary playlist id is not a saved queue', (tester) async {
    await openApp(tester, h, ['a', 'b']);
    final id = await seedPlaylist(tester, h, 'Mine', ['a', 'b']);
    goTo(tester, h, '/queue-history/$id');
    await settleDb(tester);
    expect(find.text('Queue not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    expect(find.text('Playlist not found'), findsNothing);
    expect(pageTitle('Queues'), findsOneWidget);

    goTo(tester, h, '/queue-history/abc');
    await settleDb(tester);
    expect(find.text('Queue not found'), findsOneWidget);
  });

  /// Removes row [index] of the open saved queue through its song modal.
  Future<void> removeQueueRow(WidgetTester tester, int index) async {
    await tester.tap(
      find.byType(PlaylistEntryTile).at(index),
      buttons: kSecondaryButton,
    );
    await settleModal(tester);
    await tester.tap(find.text('Remove from queue'));
    await tester.pump();
  }

  testWidgets('removing every song names the queue in the empty state', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b']);
    final id = await seedQueue(tester, ['a', 'b']);
    goTo(tester, h, '/queue-history/$id');
    await settleDb(tester);

    await removeQueueRow(tester, 0);
    await settleDb(tester);
    await removeQueueRow(tester, 0);
    await settleDb(tester);

    expect(find.text('This queue is empty'), findsOneWidget);
    expect(
      find.text(
        'All its songs were removed. You can delete it from the ⋮ menu.',
      ),
      findsOneWidget,
    );
    expect(find.text('This playlist is empty'), findsNothing);
  });

  testWidgets('a failed removal says the queue was not saved', (tester) async {
    await openApp(tester, h, ['a', 'b']);
    final id = await seedQueue(tester, ['a', 'b']);
    goTo(tester, h, '/queue-history/$id');
    await settleDb(tester);
    await breakWrites(tester, h, 'playlist_entries', 'DELETE');

    await removeQueueRow(tester, 0);
    await settleDb(tester);

    expect(
      find.text("Couldn't save the queue. See the log for details."),
      findsOneWidget,
    );
    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsNothing,
    );
    expect(find.byType(PlaylistEntryTile), findsNWidgets(2));
  });

  testWidgets('without a library the page says so', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    goTo(tester, h, '/queue-history');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the library"), findsOneWidget);
    expect(pageTitle('Queues'), findsOneWidget);
    expect(pageTitle('Playlists'), findsNothing);
  });
}
