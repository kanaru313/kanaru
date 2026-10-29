import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/folder_queries.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/library/folders/folder_art.dart';
import 'package:kanaru/features/library/folders/folder_content_view.dart';
import 'package:kanaru/features/library/folders/folder_header.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:kanaru/features/library/folders/folder_page_parts.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/hover_underline_links.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
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

final _rock = folderLocation('/m/Rock');

void main() {
  List<String> queued(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Queue actions'));
    await tester.pumpAndSettle();
  }

  Finder onPage(String text) => find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.text(text),
  );

  Finder inHeader(Finder matching) =>
      find.descendant(of: find.byType(FolderHeader), matching: matching);

  RenderParagraph crumbLine(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: inHeader(find.byType(HoverUnderlineLinks)),
          matching: find.byType(RichText),
        )
        .first,
  );

  /// The breadcrumb line of the header, as the text it shows.
  String crumbs(WidgetTester tester) => crumbLine(tester).text.toPlainText();

  /// Moves the mouse onto the first occurrence of [word] in the breadcrumb
  /// and clicks it.
  Future<void> clickCrumb(WidgetTester tester, String word) async {
    final line = crumbLine(tester);
    final start = line.text.toPlainText().indexOf(word);
    final box = line
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
        )
        .first;
    final at = line.localToGlobal(box.toRect().center);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(at);
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await tester.pumpAndSettle();
  }

  Future<void> flatMode(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();
  }

  testWidgets('the header names the folder, its breadcrumb and its counts', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    expect(inHeader(find.text('Rock')), findsOneWidget);
    expect(crumbs(tester), 'm › Rock');
    expect(find.text('/m/Rock'), findsNothing);
    expect(find.byTooltip('/m/Rock'), findsOneWidget);
    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Text),
      ),
    );
    expect([for (final t in texts) t.data], containsAllInOrder(['4', '2']));
  });

  testWidgets('shows the subfolders, then the songs, both in natural order', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: _rock);
    double top(String text) => tester.getTopLeft(onPage(text)).dy;

    expect(
      find.byType(FolderSectionHeading),
      findsNothing,
      reason: 'a list has no headings',
    );
    expect(find.byType(FolderListTile), findsNWidgets(2));
    final rule = find.byKey(folderSongsDividerKey);
    expect(rule, findsOneWidget);
    double divider() => tester.getTopLeft(rule).dy;
    expect(top('CD 2'), lessThan(top('CD 10')));
    expect(top('CD 10'), lessThan(divider()));
    expect(divider(), lessThan(top('b2')));
    expect(top('b2'), lessThan(top('b10')));
    expect(find.text('c'), findsNothing, reason: 'a song of a subfolder');
    expect(find.text('j'), findsNothing);
  });

  testWidgets('a song plays the folder songs from it', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.text('b10'));
    await tester.pump();

    expect(queued(h), ['b2', 'b10']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'b10');
  });

  testWidgets('Play queues the whole subtree in natural path order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await settleIo(tester, h);

    expect(queued(h), ['b2', 'b10', 'c', 'd']);
    expect(h.container.read(playerServiceProvider).queue.current?.title, 'b2');
  });

  testWidgets('Shuffle queues the subtree shuffled', (tester) async {
    final h = LibraryHarness(
      overrides: [
        playerServiceProvider.overrideWith(
          () => PlayerService(random: Random(3)),
        ),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
    await settleIo(tester, h);

    expect(queued(h), ['b2', 'b10', 'c', 'd']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('Play leaves a queue opened while it was reading alone', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    final h = LibraryHarness(interceptor: gate);
    await openWithTracks(tester, h, _tracks, location: _rock);

    final release = gate.holdNext('path >= ?1');
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/other.mp3'),
    ]);
    release();
    await settleIo(tester, h);

    expect(queued(h), ['other']);
  });

  testWidgets('the more menu queues the subtree behind the playing song', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    await h.container.read(playerServiceProvider.notifier).openTracks([
      Track.fromPath('/other.mp3'),
    ]);

    await openMore(tester);
    expect(find.text('Play'), findsOneWidget, reason: 'only the header button');
    await tester.tap(find.text('Add to queue'));
    await settleIo(tester, h);
    expect(queued(h), ['other', 'b2', 'b10', 'c', 'd']);

    await openMore(tester);
    await tester.tap(find.text('Play next'));
    await settleIo(tester, h);
    expect(queued(h), ['other', 'b2', 'b10', 'c', 'd', 'b2', 'b10', 'c', 'd']);
  });

  testWidgets('a subfolder offers the menu too', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.text('CD 2'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await settleIo(tester, h);

    expect(queued(h), ['c']);
  });

  Future<List<String>> playlistPaths(LibraryHarness h, String name) async {
    final cards = await h.db.playlistCards();
    final card = cards.singleWhere((c) => c.playlist.name == name);
    final page = await h.db.playlistPage(card.playlist.id);
    return [for (final e in page!.entries) e.path];
  }

  testWidgets(
    'Create playlist asks with the folder name and saves the subtree',
    (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: _rock);

      await openMore(tester);
      await tester.tap(find.text('Create playlist'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Rock');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIo(tester, h);

      final paths = await tester.runAsync(() => playlistPaths(h, 'Rock'));
      expect(paths, [
        '/m/Rock/b2.flac',
        '/m/Rock/b10.flac',
        '/m/Rock/CD 2/c.flac',
        '/m/Rock/CD 10/d.flac',
      ]);
      expect(find.text('Added to Rock: Rock'), findsOneWidget);
    },
  );

  testWidgets('cancelling the name dialog creates nothing', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await openMore(tester);
    await tester.tap(find.text('Create playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(h.db.playlistCards), isEmpty);
  });

  testWidgets('Create playlist on a folder without songs only says so', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.runAsync(() => h.db.addRoots(['/empty'], now: 2));
    await insertTracks(tester, h, const [TestTrack('k', path: '/m/k.flac')]);
    await settleIo(tester, h);
    // Same folder the list shows, as a node of no songs.
    await tester.tap(
      find.widgetWithText(FolderListTile, 'empty'),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create playlist'));
    await tester.pumpAndSettle();

    expect(find.text('No songs in this folder'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await tester.runAsync(h.db.playlistCards), isEmpty);
  });

  testWidgets('a broken key or an unknown folder shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders/%21%21');
    expect(find.text('Folder not found'), findsOneWidget);

    goTo(tester, h, folderLocation('/m/nope'));
    await tester.pumpAndSettle();
    expect(find.text('Folder not found'), findsOneWidget);
  });

  testWidgets('a folder emptied by a rescan shows not found', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: folderLocation('/m/Jazz'),
    );
    expect(find.text('j'), findsOneWidget);

    await tester.runAsync(() async {
      final rows = await h.db.folderTracks('/m/Jazz', recursive: true);
      await h.db.deleteTracksById([for (final r in rows) r.id]);
    });
    await settleIo(tester, h);

    expect(find.text('Folder not found'), findsOneWidget);
  });

  testWidgets('a subfolder opens as its own page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await tester.tap(find.text('CD 2'));
    await tester.pumpAndSettle();

    expect(location(h), folderLocation('/m/Rock/CD 2'));
    expect(crumbs(tester), 'm › Rock › CD 2');
    expect(find.text('c'), findsOneWidget);
    expect(find.text('b2'), findsNothing);
    expect(find.byType(FolderListTile), findsNothing);
  });

  testWidgets('back and forward move between a folder and its subfolder', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    await tester.tap(find.text('CD 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(location(h), _rock);
    expect(find.text('b2'), findsOneWidget);

    await tester.tap(find.byTooltip('Forward'));
    await tester.pumpAndSettle();
    expect(find.text('c'), findsOneWidget);
    expect(find.text('b2'), findsNothing);
  });

  testWidgets('with the tree off the page lists songs only', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();

    goTo(tester, h, _rock);
    await tester.pumpAndSettle();

    expect(find.byType(FolderListTile), findsNothing);
    expect(find.textContaining('Folders ·'), findsNothing);
    expect(find.text('b2'), findsOneWidget);
  });

  testWidgets('Play follows the folder order, not the plain text order', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('album-deluxe', path: '/m/Order/Album (Deluxe)/y.flac'),
      TestTrack('album', path: '/m/Order/Album/x.flac'),
      TestTrack('a-z', path: '/m/Order/a-z/3.flac'),
      TestTrack('a-b', path: '/m/Order/a b/2.flac'),
      TestTrack('a', path: '/m/Order/a/1.flac'),
    ], location: folderLocation('/m/Order'));

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await settleIo(tester, h);

    expect(queued(h), ['a', 'a-b', 'a-z', 'album', 'album-deluxe']);
  });

  testWidgets('Play waits for an Add to queue still reading', (tester) async {
    final gate = GatedQueryInterceptor();
    final h = LibraryHarness(interceptor: gate);
    await openWithTracks(tester, h, _tracks, location: _rock);

    final release = gate.holdNext('path >= ?1');
    await openMore(tester);
    await tester.tap(find.text('Add to queue'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    release();
    await settleIo(tester, h);

    expect(queued(h), ['b2', 'b10', 'c', 'd']);
  });

  testWidgets('a music folder without songs opens as an empty folder', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.runAsync(() => h.db.addRoots(['/empty'], now: 2));
    await insertTracks(tester, h, const [TestTrack('k', path: '/m/k.flac')]);
    await settleIo(tester, h);

    goTo(tester, h, folderLocation('/empty'));
    await tester.pumpAndSettle();

    expect(find.text('No songs in this folder'), findsOneWidget);
    expect(find.text('Folder not found'), findsNothing);
    expect(crumbs(tester), 'empty');
    expect(find.byTooltip('/empty'), findsOneWidget);
  });

  testWidgets('a dot folder of the library opens as a normal page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('s', path: '/m/.secret/s.flac'),
    ], location: folderLocation('/m/.secret'));

    expect(find.text('Hidden'), findsNothing);
    expect(onPage('s'), findsOneWidget);
    expect(find.byTooltip('Show hidden items'), findsNothing);
    expect(find.byTooltip('Queue actions'), findsOneWidget);
  });

  testWidgets('a dot folder that is not in the library shows not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: folderLocation('/m/.x'));

    expect(find.text('Folder not found'), findsOneWidget);
  });

  testWidgets('a breadcrumb folder opens its page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(
      tester,
      h,
      _tracks,
      location: folderLocation('/m/Rock/CD 2'),
    );
    await clickCrumb(tester, 'Rock');

    expect(location(h), _rock);
  });

  testWidgets('with one music folder the first crumb opens Folders', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);
    await clickCrumb(tester, 'm');

    expect(location(h), foldersPath);
  });

  testWidgets('with several music folders the first crumb opens its page', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/folders');
    await tester.runAsync(() => h.db.addRoots(['/n'], now: 2));
    await insertTracks(tester, h, const [TestTrack('k', path: '/n/k.flac')]);
    await settleIo(tester, h);
    goTo(tester, h, _rock);
    await tester.pumpAndSettle();
    await clickCrumb(tester, 'm');

    expect(location(h), folderLocation('/m'));
  });

  group('flat', () {
    testWidgets('the breadcrumb is plain text and the count is direct', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, folderLocation('/m/Rock/CD 2'));
      await tester.pumpAndSettle();
      await clickCrumb(tester, 'Rock');

      expect(location(h), folderLocation('/m/Rock/CD 2'));
      expect(crumbs(tester), 'm › Rock › CD 2');
    });

    testWidgets('the header counts only the songs in the folder', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      expect(inHeader(find.text('2')), findsOneWidget);
      expect(inHeader(find.text('4')), findsNothing);
      expect(
        tester.widget<FolderArt>(inHeader(find.byType(FolderArt))).direct,
        isTrue,
      );
      expect(find.textContaining('Folders ·'), findsNothing);
    });

    testWidgets('Play queues the songs in the folder only', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await settleIo(tester, h);

      expect(queued(h), ['b2', 'b10']);
    });

    testWidgets('the more menu queues the songs in the folder only', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      await openMore(tester);
      await tester.tap(find.text('Add to queue'));
      await settleIo(tester, h);

      expect(queued(h), ['b2', 'b10']);
    });

    testWidgets('Shuffle queues the songs in the folder only', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
      await settleIo(tester, h);

      expect(queued(h), unorderedEquals(['b2', 'b10']));
    });

    testWidgets('Create playlist saves the songs in the folder only', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      await openMore(tester);
      await tester.tap(find.text('Create playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settleIo(tester, h);

      final paths = await tester.runAsync(() => playlistPaths(h, 'Rock'));
      expect(paths, ['/m/Rock/b2.flac', '/m/Rock/b10.flac']);
    });

    testWidgets('Play all below plays the whole subtree', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      await openMore(tester);
      await tester.tap(find.text('Play all below'));
      await settleIo(tester, h);

      expect(queued(h), ['b2', 'b10', 'c', 'd']);
    });

    testWidgets('a folder without subfolders has no Play all below', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester);
      goTo(tester, h, folderLocation('/m/Jazz'));
      await tester.pumpAndSettle();

      await openMore(tester);

      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Play all below'), findsNothing);
    });

    testWidgets('a folder without songs of its own disables Play', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, const [
        TestTrack('c', path: '/m/Rock/CD 2/c.flac'),
      ], location: '/folders');
      await flatMode(tester);
      goTo(tester, h, _rock);
      await tester.pumpAndSettle();

      final play = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Play'),
      );
      final shuffle = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Shuffle'),
      );
      expect(find.byTooltip('Queue actions'), findsOneWidget);
      await openMore(tester);
      expect(find.text('Play all below'), findsOneWidget);
      expect(find.text('Add to queue'), findsNothing);
      expect(find.text('Create playlist'), findsNothing);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(play.onPressed, isNull);
      expect(shuffle.onPressed, isNull);
      expect(find.text('No songs in this folder'), findsOneWidget);
      expect(find.textContaining('Songs ·'), findsNothing);
    });
  });

  testWidgets('the tree menu has no Play all below', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: _rock);

    await openMore(tester);

    expect(find.text('Add to queue'), findsOneWidget);
    expect(find.text('Play all below'), findsNothing);
  });
}
