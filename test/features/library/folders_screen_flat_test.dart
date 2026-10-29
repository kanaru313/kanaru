import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/folders/folder_grid_tile.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('b2', path: '/m/Rock/b2.flac'),
  TestTrack('b10', path: '/m/Rock/b10.flac'),
  TestTrack('c', path: '/m/Rock/CD 2/c.flac'),
  TestTrack('j', path: '/m/Jazz/j.flac'),
];

void main() {
  Finder tile(String title) => find.widgetWithText(FolderListTile, title);

  Future<LibraryHarness> openFlat(
    WidgetTester tester, [
    List<TestTrack> tracks = _tracks,
  ]) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, tracks, location: '/folders');
    await tester.tap(find.byTooltip('Folder tree'));
    await tester.pumpAndSettle();
    return h;
  }

  List<String?> texts(WidgetTester tester, Finder of) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(of: of, matching: find.byType(Text)),
    ))
      t.data,
  ];

  testWidgets('a flat row has the name, the parent line and the direct count', (
    tester,
  ) async {
    await openFlat(tester);

    expect(texts(tester, tile('CD 2')), ['CD 2', 'Rock', '1']);
    expect(texts(tester, tile('Jazz')), ['Jazz', 'm', '1']);
    // Rock counts its own two songs, not the one in CD 2.
    expect(texts(tester, tile('Rock').first), ['Rock', 'm', '2']);
  });

  testWidgets('Play next on a flat row queues its own songs only', (
    tester,
  ) async {
    final h = await openFlat(tester);

    await tester.tap(tile('Rock').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.tracks)
          t.title,
      ],
      ['b2', 'b10'],
    );
  });

  testWidgets('Play all below shows only for a flat folder with subfolders', (
    tester,
  ) async {
    final h = await openFlat(tester);

    await tester.tap(tile('Jazz'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Play all below'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(tile('Rock').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Play all below'), findsOneWidget);
    await tester.tap(find.text('Play all below'));
    await settleIo(tester, h);

    expect(
      [
        for (final t in h.container.read(playerServiceProvider).queue.tracks)
          t.title,
      ],
      ['b2', 'b10', 'c'],
    );
  });

  testWidgets(
    'a flat grid with large text and a narrow width has no overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openFlat(tester);
      await tester.tap(find.byTooltip('List'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderGridTile), findsNWidgets(3));
      expect(find.text('CD 2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 720);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
