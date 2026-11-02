import 'dart:io';

import 'package:drift/native.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/playlists/m3u_file_pickers.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late Directory tmp;
  late LibraryHarness h;
  final suggested = <String>[];
  var savePath = '';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru-modal-advanced');
    suggested.clear();
    savePath = '${tmp.path}/out.m3u8';
    h = LibraryHarness(
      overrides: [
        m3uSavePickerProvider.overrideWithValue((name) async {
          suggested.add(name);
          return savePath;
        }),
      ],
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<int> open(
    WidgetTester tester, {
    List<String> titles = const ['a', 'b'],
    List<String> missing = const [],
    String name = 'Mix',
  }) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, name, titles, extraPaths: missing);
    await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);
    await tapModalAction(tester, 'advanced');
    return id;
  }

  Future<int> idByName(WidgetTester tester, String name) async {
    final all = await tester.runAsync(
      () => h.db.watchPlaylistSummaries().first,
    );
    return all!.singleWhere((p) => p.name == name).id;
  }

  group('Duplicate', () {
    testWidgets('keeps repeats, says so and stays where it is', (tester) async {
      final id = await open(tester, titles: ['a', 'b', 'a']);
      await tapModalAction(tester, 'duplicate');

      final copy = await idByName(tester, 'Mix (copy)');
      final stored = await storedPaths(tester, h, id);
      expect(await storedPaths(tester, h, copy), stored);
      expect(stored, hasLength(3));
      expect(find.text('Created “Mix (copy)”'), findsOneWidget);
      expect(modalAction('duplicate'), findsNothing, reason: 'modal closed');
    });
  });

  group('clean-up rows follow the counts', () {
    testWidgets('no repeats and nothing missing: neither row', (tester) async {
      await open(tester);
      expect(modalAction('remove-duplicates'), findsNothing);
      expect(modalAction('remove-missing'), findsNothing);
    });

    testWidgets('repeats and missing files show both, with counts', (
      tester,
    ) async {
      await open(
        tester,
        titles: ['a', 'b', 'a'],
        missing: ['/gone/x.flac', '/gone/y.flac'],
      );
      expect(modalAction('remove-duplicates'), findsOneWidget);
      expect(
        find.text('1 repeated song · keeps the first one'),
        findsOneWidget,
      );
      expect(find.text('2 songs not in your library'), findsOneWidget);
    });
  });

  group('Remove duplicates', () {
    testWidgets('keeps the first copy, no question asked', (tester) async {
      final id = await open(tester, titles: ['a', 'b', 'a', 'a']);
      final before = await storedPaths(tester, h, id);
      await tapModalAction(tester, 'remove-duplicates');

      expect(find.byType(AlertDialog), findsNothing);
      expect(await storedPaths(tester, h, id), before.sublist(0, 2));
      expect(find.text('2 duplicates removed'), findsOneWidget);
    });
  });

  group('Remove missing', () {
    testWidgets('removes at once, without a question, and counts', (
      tester,
    ) async {
      final id = await open(tester, missing: ['/gone/x.flac', '/gone/y.flac']);
      final before = await storedPaths(tester, h, id);
      await tapModalAction(tester, 'remove-missing');

      expect(find.byType(AlertDialog), findsNothing);
      expect(await storedPaths(tester, h, id), before.sublist(0, 2));
      expect(find.text('2 missing songs removed'), findsOneWidget);
    });

    testWidgets('a file that came back after the modal opened is kept', (
      tester,
    ) async {
      final id = await open(tester, missing: ['/m/back.flac']);
      // A scan stores the file while the modal is open.
      await tester.runAsync(
        () => h.db.upsertTracks([
          TracksCompanion.insert(
            rootId: 1,
            path: '/m/back.flac',
            mtimeMs: 1,
            sizeBytes: 1,
            title: 'back',
            addedAt: 1,
            updatedAt: 1,
          ),
        ]),
      );
      await tapModalAction(tester, 'remove-missing');

      expect(await storedPaths(tester, h, id), hasLength(3));
      expect(find.textContaining('missing songs removed'), findsNothing);
    });

    test(
      'only the ids read are deleted, not an entry that went missing after',
      () async {
        final db = LibraryDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final root = (await db.addRoots(['/m'], now: 1)).single;
        Future<void> track(String path) => db.upsertTracks([
          TracksCompanion.insert(
            rootId: root,
            path: path,
            mtimeMs: 1,
            sizeBytes: 1,
            title: path,
            addedAt: 1,
            updatedAt: 1,
          ),
        ]);
        await track('/m/a.flac');
        await track('/m/b.flac');
        final id = await db.createPlaylist(
          'Mix',
          now: 1,
          paths: ['/m/a.flac', '/gone.flac', '/m/b.flac'],
        );
        final ids = await db.playlistMissingEntryIds(id);
        expect(ids, hasLength(1));
        // A track row goes after the read: its entry is missing now, but was
        // not in the ids.
        await (db.delete(
          db.tracks,
        )..where((t) => t.path.equals('/m/b.flac'))).go();
        expect(await db.removePlaylistEntries(id, ids.toSet()), 1);
        expect(await db.playlistEntryPaths(id), ['/m/a.flac', '/m/b.flac']);
      },
    );
  });

  group('Export as M3U', () {
    Future<String> exportVia(WidgetTester tester, String row) async {
      await tapModalAction(tester, row);
      for (
        var i = 0;
        i < 40 && find.textContaining('Saved').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      return File(savePath).readAsStringSync();
    }

    testWidgets('both styles reach the save picker and write the file', (
      tester,
    ) async {
      await open(tester);
      final absolute = await exportVia(tester, 'export-absolute');
      expect(suggested, ['Mix.m3u8']);
      expect(
        absolute.split('\n').where((l) => l.startsWith('/m/')),
        hasLength(2),
      );
      expect(find.textContaining('Saved 2 songs to out.m3u8'), findsOneWidget);
    });

    testWidgets('relative paths do not start at the root', (tester) async {
      await open(tester);
      final relative = await exportVia(tester, 'export-relative');
      expect(suggested, ['Mix.m3u8']);
      final lines = relative.split('\n').where((l) => l.contains('.flac'));
      expect(lines, hasLength(2));
      expect(lines.any((l) => l.startsWith('/')), isFalse);
    });
  });

  group('Add all to Favorites', () {
    testWidgets('puts library songs in and skips entries without a file', (
      tester,
    ) async {
      await open(tester, missing: ['/gone/x.flac']);
      await tapModalAction(tester, 'add-all-to-favorites');

      final id = (await tester.runAsync(
        () => h.db.ensureFavoritesPlaylist(now: 1),
      ))!;
      final paths = await storedPaths(tester, h, id);
      expect(paths, hasLength(2));
      expect(paths.any((p) => p.contains('gone')), isFalse);
    });
  });
}
