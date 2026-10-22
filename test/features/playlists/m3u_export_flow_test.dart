import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/m3u/m3u_import.dart';
import 'package:kanaru/features/playlists/m3u_export_flow.dart';
import 'package:kanaru/features/playlists/m3u_file_pickers.dart';
import 'package:kanaru/features/playlists/m3u_import_report_dialog.dart';
import 'package:kanaru/features/playlists/playlist_routes.dart';
import 'package:kanaru/features/playlists/playlist_page_actions.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  test('the export target gets .m3u8 unless it has an M3U extension', () {
    expect(m3uExportTarget('/a/list'), '/a/list.m3u8');
    expect(m3uExportTarget('/a/list.M3U'), '/a/list.M3U');
    expect(m3uExportTarget('/a/list.m3u8'), '/a/list.m3u8');
    expect(m3uExportTarget('/a/list.txt'), '/a/list.txt.m3u8');
  });

  test('report lines are cut and cleaned', () {
    expect(m3uReportLineText('a\tb'), 'a b');
    expect(m3uReportLineText('x' * 400), hasLength(m3uReportMaxLineLength + 1));
  });

  group('export', () {
    late Directory tmp;
    late String root;
    late LibraryHarness h;
    String? picked;
    final suggested = <String>[];

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('kanaru-m3u-export-flow');
      root = await tmp.resolveSymbolicLinks();
      picked = null;
      suggested.clear();
      h = LibraryHarness(
        refreshInterval: Duration.zero,
        overrides: [
          m3uSavePickerProvider.overrideWithValue((name) async {
            suggested.add(name);
            return picked;
          }),
        ],
      );
    });
    tearDown(() => tmp.delete(recursive: true));

    Future<String?> read(WidgetTester tester, String path) =>
        tester.runAsync<String?>(() async {
          final f = File(path);
          if (!await f.exists()) return null;
          return f.readAsString();
        });

    /// Opens playlist "Mix" holding library songs a and b.
    Future<int> openMix(WidgetTester tester) async {
      await insertTracks(tester, h, [
        TestTrack('a', artist: 'Ann', path: '$root/music/a.flac'),
        TestTrack('b', path: '$root/music/b.flac'),
      ]);
      await openApp(tester, h, const []);
      final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
      goTo(tester, h, playlistLocation(id));
      await settleDb(tester);
      return id;
    }

    /// Lets real file I/O run until a snackbar or a dialog shows.
    Future<void> settleIoUi(
      WidgetTester tester, {
      bool snackbarOnly = false,
    }) async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(SnackBar).evaluate().isNotEmpty ||
            (!snackbarOnly && find.byType(AlertDialog).evaluate().isNotEmpty)) {
          break;
        }
      }
      await tester.pumpAndSettle();
    }

    Future<void> export(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await settleIoUi(tester);
    }

    testWidgets('relative export writes a playlist next to the music', (
      tester,
    ) async {
      await openMix(tester);
      picked = '$root/lists';

      await export(tester, 'Export M3U (relative paths)…');

      expect(suggested, ['Mix.m3u8']);
      expect(
        await read(tester, '$root/lists.m3u8'),
        '#EXTM3U\n#EXTINF:1,Ann - a\nmusic/a.flac\n#EXTINF:1,b\nmusic/b.flac\n',
      );
      expect(find.text('Saved 2 songs to lists.m3u8'), findsOneWidget);
    });

    testWidgets('absolute export round-trips through import', (tester) async {
      await openMix(tester);
      picked = '$root/out/Mix.m3u';
      await tester.runAsync(() async {
        await Directory('$root/out').create();
        for (final n in ['a', 'b']) {
          await File('$root/music/$n.flac').create(recursive: true);
        }
      });

      await export(tester, 'Export M3U (full paths)…');
      final result = await tester.runAsync(
        () => importM3uFile('$root/out/Mix.m3u'),
      );

      expect(result!.paths, ['$root/music/a.flac', '$root/music/b.flac']);
    });

    testWidgets('a cancelled save dialog writes nothing', (tester) async {
      await openMix(tester);

      await export(tester, 'Export M3U (full paths)…');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an existing file is replaced only after asking', (
      tester,
    ) async {
      await openMix(tester);
      final target = '$root/old.m3u8';
      await tester.runAsync(() => File(target).writeAsString('old'));
      picked = target;

      await export(tester, 'Export M3U (full paths)…');
      expect(find.text('Replace old.m3u8?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await read(tester, target), 'old');

      await export(tester, 'Export M3U (full paths)…');
      await tester.tap(find.text('Replace'));
      await settleIoUi(tester, snackbarOnly: true);
      expect(await read(tester, target), startsWith('#EXTM3U\n'));
    });

    testWidgets('Favorites offers only the two exports', (tester) async {
      await insertTracks(tester, h, [TestTrack('a', path: '$root/a.flac')]);
      await openApp(tester, h, const [], location: '/favorites');
      await tester.runAsync(
        () => h.db.setFavorite('$root/a.flac', favorite: true, now: 1),
      );
      await settleDb(tester);

      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();

      expect(find.text('Export M3U (full paths)…'), findsOneWidget);
      expect(find.text('Export M3U (relative paths)…'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete playlist'), findsNothing);
    });

    testWidgets('only entries in the library play', (tester) async {
      await insertTracks(tester, h, [TestTrack('a', path: '$root/a.flac')]);
      await openApp(tester, h, const []);
      final id = await tester.runAsync(
        () => h.db.createPlaylist(
          'Mixed',
          now: 1,
          paths: ['$root/gone.flac', '$root/a.flac'],
        ),
      );
      final page = await tester.runAsync(() => h.db.playlistPage(id!));

      final tracks = playableTracks(page!.entries, null);

      expect([for (final t in tracks) t.uri], ['$root/a.flac']);
    });
  });
}
