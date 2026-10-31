import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_content_view.dart';
import 'package:kanaru/features/library/folders/folder_filter_chips.dart';
import 'package:kanaru/features/library/folders/folder_grid_tile.dart';
import 'package:kanaru/features/library/folders/folder_list_tile.dart';
import 'package:kanaru/features/library/folders/folder_page_parts.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

const _tracks = [
  TestTrack('a', path: '/m/VN/a.flac'),
  TestTrack('b', path: '/m/VN/b.flac'),
  TestTrack('x', path: '/m/VN/Den/x.flac'),
  TestTrack('y', path: '/m/VN/Den/y.flac'),
  TestTrack('z', path: '/m/VN/Amee/z.flac'),
];

void main() {
  final vn = folderLocation('/m/VN');

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  Finder heading(String label) =>
      find.widgetWithText(FolderSectionHeading, label);

  /// The rule between the folder rows and the songs of a list.
  final divider = find.byKey(folderSongsDividerKey);

  final folderRows = find.byType(FolderListTile);

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(chip(label));
    await tester.pumpAndSettle();
  }

  group('chips', () {
    testWidgets('show the counts when a page has folders and songs', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: vn);

      expect(chip('All'), findsOneWidget);
      expect(chip('Folders · 2'), findsOneWidget);
      expect(chip('Songs · 2'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(chip('All')).selected, isTrue);
    });

    testWidgets('are absent on a songs-only page', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(
        tester,
        h,
        _tracks,
        location: folderLocation('/m/VN/Den'),
      );

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(SongTile), findsNWidgets(2));
    });

    testWidgets('are absent on a folders-only page', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, const [
        TestTrack('x', path: '/m/VN/Den/x.flac'),
        TestTrack('z', path: '/m/VN/Amee/z.flac'),
      ], location: vn);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FolderGridTile), findsNWidgets(2));
    });

    testWidgets('fit a 480 px window at text scale 2 in Vietnamese', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      FolderFilter? picked;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FolderFilterChips(
              selected: FolderFilter.all,
              folderCount: 12,
              songCount: 345,
              onSelected: (f) => picked = f,
            ),
          ),
        ),
      );

      expect(chip('Tất cả'), findsOneWidget);
      expect(chip('Thư mục · 12'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');

      // The last chip is off-screen until the row scrolls.
      await tester.ensureVisible(chip('Bài hát · 345'));
      await tester.tap(chip('Bài hát · 345'));
      expect(picked, FolderFilter.songs);
    });
  });

  group('grid', () {
    testWidgets('names both sections with their counts', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: vn);

      expect(heading('Folders · 2'), findsOneWidget);
      expect(heading('Songs · 2'), findsOneWidget);
      expect(find.byType(FolderGridTile), findsNWidgets(2));
      expect(find.byType(SongTile), findsNWidgets(2));
    });

    testWidgets('Songs hides the folders and the headings', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: vn);

      await tapChip(tester, 'Songs · 2');

      expect(find.byType(FolderGridTile), findsNothing);
      expect(heading('Folders · 2'), findsNothing);
      expect(heading('Songs · 2'), findsNothing);
      expect(find.byType(SongTile), findsNWidgets(2));
    });

    testWidgets('Folders hides the songs', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: vn);

      await tapChip(tester, 'Folders · 2');

      expect(find.byType(SongTile), findsNothing);
      expect(find.byType(FolderGridTile), findsNWidgets(2));
      expect(heading('Folders · 2'), findsNothing);

      await tapChip(tester, 'All');
      expect(find.byType(SongTile), findsNWidgets(2));
    });
  });

  group('list', () {
    testWidgets('is one run of folders, a divider and songs', (tester) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, _tracks, location: vn);

      expect(heading('Folders · 2'), findsNothing);
      expect(heading('Songs · 2'), findsNothing);
      expect(divider, findsOneWidget);
      expect(folderRows, findsNWidgets(2));
      final lastFolder = tester.getBottomLeft(folderRows.last).dy;
      final dividerTop = tester.getTopLeft(divider).dy;
      final firstSong = tester.getTopLeft(find.byType(SongTile).first).dy;
      expect(lastFolder, lessThanOrEqualTo(dividerTop));
      expect(dividerTop, lessThan(firstSong));
    });

    testWidgets('has no divider while filtered', (tester) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, _tracks, location: vn);

      await tapChip(tester, 'Songs · 2');
      expect(divider, findsNothing);
      expect(folderRows, findsNothing);

      await tapChip(tester, 'Folders · 2');
      expect(divider, findsNothing);
      expect(find.byType(SongTile), findsNothing);
      expect(folderRows, findsNWidgets(2));
    });
  });

  group('flat', () {
    Future<void> flatMode(WidgetTester tester, LibraryHarness h) async {
      await tester.tap(find.byTooltip('Folder tree'));
      await tester.pumpAndSettle();
      goTo(tester, h, vn);
      await tester.pumpAndSettle();
    }

    testWidgets('lists the own songs under a Songs heading', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester, h);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FolderGridTile), findsNothing);
      expect(find.byType(FolderListTile), findsNothing);
      expect(heading('Songs · 2'), findsOneWidget);
      expect(find.byType(SongTile), findsNWidgets(2));
    });

    testWidgets('a list has no chips or divider, just the songs', (
      tester,
    ) async {
      final h = LibraryHarness(overrides: [listViewModesOverride]);
      await openWithTracks(tester, h, _tracks, location: '/folders');
      await flatMode(tester, h);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(divider, findsNothing);
      expect(folderRows, findsNothing);
      expect(heading('Songs · 2'), findsOneWidget);
      expect(find.byType(SongTile), findsNWidgets(2));
    });

    testWidgets('a folder without own songs has no heading', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, const [
        TestTrack('x', path: '/m/VN/Den/x.flac'),
      ], location: '/folders');
      await flatMode(tester, h);

      expect(find.textContaining('Songs ·'), findsNothing);
      expect(find.text('No songs in this folder'), findsOneWidget);
    });
  });

  testWidgets('a song on its own folder page offers Go to folder', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: vn);

    await openSongModal(tester, find.text('a'));

    expect(modalAction('folder'), findsOneWidget);
  });

  testWidgets('a subfolder and back start at All again', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: vn);
    await tapChip(tester, 'Songs · 2');

    goTo(tester, h, folderLocation('/m/VN/Den'));
    await tester.pumpAndSettle();
    goTo(tester, h, vn);
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(chip('All')).selected, isTrue);
    expect(find.byType(FolderGridTile), findsNWidgets(2));
  });
}
