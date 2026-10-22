import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/playlists/m3u_file_pickers.dart';
import 'package:kanaru/features/playlists/m3u_import_flow.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  group('playlistNameFromM3uFile', () {
    test('drops the extension in any case', () {
      expect(playlistNameFromM3uFile('/a/Mix.M3U8', 'New'), 'Mix');
      expect(playlistNameFromM3uFile('/a/Road trip.m3u', 'New'), 'Road trip');
      expect(playlistNameFromM3uFile('/a/notes.txt', 'New'), 'notes.txt');
    });

    test('a name left empty falls back', () {
      expect(playlistNameFromM3uFile('/a/.m3u8', 'New'), 'New');
      expect(playlistNameFromM3uFile('/a/  .m3u', 'New'), 'New');
    });

    test('control and bidi override characters become spaces', () {
      expect(playlistNameFromM3uFile('/a/x\ny\u202Ez.m3u', 'New'), 'x y z');
    });

    test('a long name is cut to 100 characters', () {
      expect(
        playlistNameFromM3uFile('/a/${'n' * 300}.m3u', 'New'),
        hasLength(100),
      );
    });
  });

  group('import', () {
    late Directory tmp;
    late String root;
    late LibraryHarness h;
    String? picked;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('kanaru-m3u-flow');
      root = await tmp.resolveSymbolicLinks();
      picked = null;
      h = LibraryHarness(
        refreshInterval: Duration.zero,
        overrides: [
          m3uOpenPickerProvider.overrideWithValue((_) async => picked),
        ],
      );
    });
    tearDown(() => tmp.delete(recursive: true));

    /// Writes a real file; widget tests run real I/O only in `runAsync`.
    Future<String> file(
      WidgetTester tester,
      String name, [
      String text = '',
    ]) async {
      final f = File('$root/$name');
      await tester.runAsync(() async {
        await f.create(recursive: true);
        await f.writeAsString(text);
      });
      return f.path;
    }

    /// Stores library tracks at [paths] (real files) and opens /playlists.
    Future<void> open(WidgetTester tester, List<String> paths) async {
      await insertTracks(tester, h, [
        for (final p in paths) TestTrack(p.split('/').last, path: p),
      ]);
      await openApp(tester, h, const [], location: '/playlists');
    }

    Future<void> tapImport(WidgetTester tester) async {
      await tester.tap(find.text('Import M3U…'));
      // The import does real file I/O while a spinner turns, so frames are
      // pumped by hand until the progress dialog is gone.
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Importing playlist…').evaluate().isEmpty) break;
      }
      await settleDb(tester);
    }

    Future<List<LibraryPlaylist>> playlists(WidgetTester tester) async =>
        (await tester.runAsync(() => h.db.watchPlaylistSummaries().first))!
            .map((s) => (id: s.id, name: s.name))
            .toList();

    testWidgets('a playlist named after the file, with a report', (
      tester,
    ) async {
      final a = await file(tester, 'music/a.flac');
      final b = await file(tester, 'music/b.flac');
      final c = await file(
        tester,
        'music/c.flac',
      ); // a file, not a library song
      picked = await file(
        tester,
        'lists/Road trip.m3u8',
        '#EXTM3U\n$a\n../music/b.flac\n../music/missing.flac\n$c\n$a\n',
      );
      await open(tester, [a, b]);

      await tapImport(tester);

      final list = await playlists(tester);
      expect(list.single.name, 'Road trip');
      expect(await storedPaths(tester, h, list.single.id), [a, b, c]);
      expect(location(h), '/playlists/${list.single.id}');
      expect(find.text('Playlist imported'), findsOneWidget);
      expect(find.textContaining('Added 3 of 5 lines'), findsOneWidget);
      expect(
        find.textContaining('1 song is not in your library'),
        findsOneWidget,
      );
      expect(find.text('1 repeated line was merged.'), findsOneWidget);
      expect(find.text('Line 4: ../music/missing.flac'), findsOneWidget);
    });

    testWidgets('a clean import only says so in a snackbar', (tester) async {
      final a = await file(tester, 'music/a.flac');
      picked = await file(tester, 'lists/Mix.m3u', '$a\n');
      await open(tester, [a]);

      await tapImport(tester);

      expect(find.text('Playlist imported'), findsNothing);
      expect(find.text('Imported 1 song into Mix'), findsOneWidget);
    });

    testWidgets('no usable line creates no playlist', (tester) async {
      picked = await file(
        tester,
        'lists/web.m3u',
        'http://example.com/a.mp3\n../missing.flac\n',
      );
      await open(tester, const []);

      await tapImport(tester);

      expect(await playlists(tester), isEmpty);
      expect(
        find.textContaining('No local music file of this playlist was found'),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled picker does nothing', (tester) async {
      await open(tester, const []);

      await tapImport(tester);

      expect(await playlists(tester), isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a folder picked as the file says it cannot be read', (
      tester,
    ) async {
      await tester.runAsync(() => Directory('$root/folder.m3u').create());
      picked = '$root/folder.m3u';
      await open(tester, const []);

      await tapImport(tester);

      expect(await playlists(tester), isEmpty);
      expect(
        find.text("Couldn't read that playlist file. See the log for details."),
        findsOneWidget,
      );
    });
  });
}

typedef LibraryPlaylist = ({int id, String name});
