import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/folders/folder_counts_line.dart';
import 'package:kanaru/features/library/folders/folder_grid_tile.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:kanaru/features/library/folders/folders_provider.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('b2', path: '/m/Rock/b2.flac'),
  TestTrack('b10', path: '/m/Rock/b10.flac'),
  TestTrack('c', path: '/m/Rock/CD 2/c.flac'),
  TestTrack('d', path: '/m/Rock/CD 10/d.flac'),
  TestTrack('j', path: '/m/Jazz/j.flac'),
];

void main() {
  Finder folderTile(String title) => find.widgetWithText(FolderListTile, title);

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  /// Adds a second music folder `/n` holding a song when [songs] is true.
  Future<void> addSecondRoot(
    WidgetTester tester,
    LibraryHarness h, {
    bool songs = true,
  }) async {
    await tester.runAsync(() => h.db.addRoots(['/n'], now: 2));
    if (songs) {
      await insertTracks(tester, h, const [
        TestTrack('n1', path: '/n/Pop/n1.flac'),
      ]);
    }
  }

  testWidgets('one music folder is listed as a folder, not skipped into', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    expect(find.byType(FolderListTile), findsOneWidget);
    expect(folderTile('m'), findsOneWidget);
    expect(find.text('Rock'), findsNothing);
    expect(find.text('Jazz'), findsNothing);
  });

  testWidgets('tapping the music folder opens its page with the children', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    await tester.tap(folderTile('m'));
    await tester.pumpAndSettle();

    expect(location(h), folderLocation('/m'));
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);
  });

  testWidgets('several music folders are all listed', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await addSecondRoot(tester, h);
    await settleIo(tester, h);

    expect(find.byType(FolderListTile), findsNWidgets(2));
    expect(folderTile('m'), findsOneWidget);
    expect(folderTile('n'), findsOneWidget);
    expect(find.text('/m'), findsNothing, reason: 'names differ');
  });

  testWidgets('a music folder without songs is still listed', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, const [], location: '/folders');
    await tester.runAsync(() => h.db.addRoots(['/empty'], now: 1));
    await insertTracks(tester, h, const [TestTrack('x', path: '/m/x.flac')]);
    await settleIo(tester, h);

    expect(folderTile('empty'), findsOneWidget);
  });

  testWidgets('the counts line shows songs and folders below, recursively', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    final line = find.descendant(
      of: folderTile('m'),
      matching: find.byType(Text),
    );
    expect(
      [for (final t in tester.widgetList<Text>(line)) t.data],
      ['m', '5', '4'],
    );
  });

  testWidgets('the counts line is read out as a sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');

    expect(
      find.bySemanticsLabel(RegExp('5 songs, 4 subfolders')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('without subfolders the counts line has songs only', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, const [
      TestTrack('x', path: '/m/x.flac'),
    ], location: '/folders');

    final line = find.descendant(
      of: folderTile('m'),
      matching: find.byType(Text),
    );
    expect([for (final t in tester.widgetList<Text>(line)) t.data], ['m', '1']);
  });

  testWidgets('the tree toggle lists every folder with songs, by label', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('All folders'), findsOneWidget);
    expect(find.byType(FolderListTile), findsNWidgets(4));
    expect(find.text('m'), findsNothing, reason: 'it holds no song itself');
    expect(top(tester, 'Jazz'), lessThan(top(tester, 'Rock')));
    expect(top(tester, 'Rock'), lessThan(top(tester, 'Rock/CD 2')));
    expect(top(tester, 'Rock/CD 2'), lessThan(top(tester, 'Rock/CD 10')));

    await tester.tap(find.byTooltip('All folders'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderListTile), findsOneWidget);
  });

  testWidgets('with several roots the flat labels lead with the root name', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await addSecondRoot(tester, h);
    await settleIo(tester, h);

    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    expect(find.text('m/Jazz'), findsOneWidget);
    expect(find.text('m/Rock/CD 2'), findsOneWidget);
    expect(find.text('n/Pop'), findsOneWidget);
  });

  testWidgets('the grid toggle shows folder tiles and back', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    expect(find.byType(FolderGridTile), findsOneWidget);
    expect(find.byType(FolderListTile), findsNothing);
    expect(find.byTooltip('Grid'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);

    await tester.tap(find.byTooltip('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderListTile), findsOneWidget);
  });

  testWidgets('the view and the tree setting survive leaving the tab', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.tap(find.byTooltip('List'));
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    goTo(tester, h, '/folders');
    await tester.pumpAndSettle();

    expect(find.byType(FolderGridTile), findsNWidgets(4));
  });

  testWidgets('a folder in the grid opens its page', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('m'));
    await tester.pumpAndSettle();

    expect(location(h), folderLocation('/m'));
  });

  testWidgets('right click on a folder offers the six actions', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    await tester.tap(folderTile('m'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    for (final item in [
      'Play',
      'Shuffle',
      'Play next',
      'Add to queue',
      'Add to playlist…',
      'Create playlist',
    ]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
  });

  testWidgets('Play next on a folder queues its whole subtree in order', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    await tester.tap(folderTile('m'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.tracks)
          t.title,
      ],
      ['j', 'b2', 'b10', 'c', 'd'],
    );
  });

  testWidgets('a large text size does not overflow the grid', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    expect(find.byType(FolderGridTile), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(480, 720);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tree reloads when the library changes', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');
    expect(h.container.read(folderTreeProvider).value!.roots.single.songs, 5);

    await insertTracks(tester, h, const [
      TestTrack('k', path: '/m/Rock/k.flac'),
    ]);
    await settleIo(tester, h);

    expect(h.container.read(folderTreeProvider).value!.roots.single.songs, 6);
  });

  testWidgets('with the tree off and no songs the page says so', (
    tester,
  ) async {
    final h = LibraryHarness();
    await h.pump(tester, hasRoots: true);
    await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    goTo(tester, h, '/folders');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    expect(find.text('No folders yet'), findsOneWidget);
  });

  testWidgets('without a music folder it points to Songs', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester);
    goTo(tester, h, '/folders');
    await tester.pumpAndSettle();

    expect(find.text('Add a music folder in Songs.'), findsOneWidget);
    expect(find.byTooltip('List'), findsNothing);
    expect(find.byTooltip('Folder tree'), findsNothing);
  });

  testWidgets('music folders with the same name also show their path', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await h.pump(tester, hasRoots: true);
    await tester.runAsync(
      () => h.db.addRoots(['/a/Music', '/b/Music'], now: 1),
    );
    await insertTracks(tester, h, const [
      TestTrack('x', path: '/a/Music/x.flac'),
      TestTrack('y', path: '/b/Music/y.flac'),
    ]);
    goTo(tester, h, '/folders');
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsNWidgets(2));
    expect(find.text('/a/Music'), findsOneWidget);
    expect(find.text('/b/Music'), findsOneWidget);

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('/a/Music'), findsOneWidget);
    expect(find.byTooltip('/b/Music'), findsOneWidget);
  });

  testWidgets(
    'a dot folder holding library songs shows like any folder and has a menu',
    (tester) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, const [
        TestTrack('s', path: '/m/.secret/s.flac'),
        TestTrack('p', path: '/m/Pop/p.flac'),
      ], location: folderLocation('/m'));

      expect(find.text('.secret'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
      expect(find.byTooltip('Show hidden items'), findsNothing);

      await tester.tap(find.text('.secret'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Add to queue'), findsOneWidget);
    },
  );

  testWidgets('the folders page has no hidden items button', (tester) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');

    expect(find.byTooltip('Show hidden items'), findsNothing);
    expect(find.byTooltip('Hide hidden items'), findsNothing);
  });

  testWidgets('a narrow, large-text grid shows counts without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, [
      const TestTrack('s', path: '/m/.secret/s.flac'),
      for (var i = 0; i < 12; i++)
        TestTrack('t$i', path: '/m/.secret/d$i/t$i.flac'),
    ], location: '/folders');
    tester.view.physicalSize = const Size(360, 720);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();

    expect(find.byType(FolderGridTile), findsWidgets);
    expect(find.byType(FolderCountsLine), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dot folder is not dimmed and shows its counts', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, const [
      TestTrack('s', path: '/m/.secret/s.flac'),
      TestTrack('p', path: '/m/Pop/p.flac'),
    ], location: folderLocation('/m'));

    expect(
      find.ancestor(
        of: find.text('.secret'),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: folderTile('.secret'),
        matching: find.byType(FolderCountsLine),
      ),
      findsOneWidget,
    );
  });
}
