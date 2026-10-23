// Times the playlist page on 1k, 10k and 50k entry playlists over a 50k-track
// file database, through the same background isolate the app uses: the first
// read, the read again after a move and after a removal, and the first frame
// with rows. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/playlist_page_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_entries_view.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/playlist_screen.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';
import 'package:material_ui/material_ui.dart';

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

const _tracks = 50000;
const _sizes = [1000, 10000, 50000];
const _batch = 512;
const _runs = 5;

/// One entry in 50 points at a file that is not in the library.
String _entryPath(int i) =>
    i % 50 == 49 ? '/gone/lost $i.mp3' : _trackPath(i % _tracks);

String _trackPath(int i) =>
    '/home/user/Music/Nghệ sĩ ${i % 900}/Album ${i % 4000}/$i Bài hát số $i.flac';

/// Best and median of [_runs] timed runs after one warm-up, in ms.
Future<({double best, double median})> _time(
  Future<void> Function() run,
) async {
  await run();
  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final sw = Stopwatch()..start();
    await run();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  return (best: times.first / 1000, median: times[_runs ~/ 2] / 1000);
}

String _fmt(({double best, double median}) t) =>
    'median ${t.median.toStringAsFixed(1)} ms, best ${t.best.toStringAsFixed(1)} ms';

late Directory _dir;
late LibraryDatabase _db;
final _ids = <int, int>{};

Widget _app(Widget child) => ProviderScope(
  overrides: [
    ...LibraryStartup(db: _db, hasRoots: true).overrides,
    libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

PlaylistEntriesView _view(PlaylistPage page) => PlaylistEntriesView(
  page: page,
  onMove: (_, _) async => true,
  onRemove: (_) {},
  onPlayFrom: (_, _) {},
);

/// Pumps, with short real waits for the database isolate, until a row shows.
Future<void> _pumpUntilRows(WidgetTester tester) async {
  while (find.byType(PlaylistEntryTile).evaluate().isEmpty) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    _dir = Directory.systemTemp.createTempSync('kanaru_playlist_bench');
    _db = LibraryDatabase(
      NativeDatabase.createInBackground(
        File('${_dir.path}/library.db'),
        setup: applyLibraryPragmas,
      ),
    );
    final root = (await _db.addRoots(['/home/user/Music'], now: 1)).single;
    final rnd = Random(1);
    final rows = [
      for (var i = 0; i < _tracks; i++)
        TracksCompanion.insert(
          rootId: root,
          path: _trackPath(i),
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Bài hát số $i',
          artist: Value('Nghệ sĩ ${i % 900}'),
          album: Value('Album ${i % 4000}'),
          durationMs: Value(120000 + rnd.nextInt(240000)),
          coverKey: Value(i % 3 == 0 ? null : 'cover${i % 4000}'),
          addedAt: i,
          updatedAt: i,
        ),
    ];
    for (var i = 0; i < rows.length; i += _batch) {
      await _db.upsertTracks(rows.sublist(i, min(i + _batch, rows.length)));
    }
    // Shuffled so entry order is not track order, as in an imported M3U.
    final order = List.generate(_sizes.last, (i) => i)..shuffle(Random(2));
    for (final size in _sizes) {
      _ids[size] = await _db.createPlaylist(
        'Mix $size',
        now: size,
        paths: [for (final i in order.take(size)) _entryPath(i)],
      );
    }
  });

  tearDownAll(() async {
    if (!_enabled) return;
    await _db.close();
    _dir.deleteSync(recursive: true);
  });

  test(
    'playlistPage reads',
    () async {
      for (final size in _sizes) {
        final id = _ids[size]!;
        // The first read of this playlist, before any warm-up.
        final cold = Stopwatch()..start();
        final page = (await _db.playlistPage(id))!;
        cold.stop();
        expect(page.entries, hasLength(size));
        print(
          '[$size] playlistPage first read (1 run, cold): '
          '${(cold.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms',
        );
        print(
          '[$size] playlistPage: ${_fmt(await _time(() => _db.playlistPage(id)))}',
        );

        // A move of the middle entry back and forth, then the read the page
        // does after it.
        final middle = page.entries[size ~/ 2].entryId;
        var to = size ~/ 4;
        print(
          '[$size] movePlaylistEntry write: ${_fmt(await _time(() async {
            await _db.movePlaylistEntry(id, middle, to);
            to = to == size ~/ 4 ? size ~/ 2 : size ~/ 4;
          }))}',
        );
        await _db.movePlaylistEntry(id, middle, to);
        print(
          '[$size] playlistPage after a move: '
          '${_fmt(await _time(() => _db.playlistPage(id)))}',
        );

        // One removal per run, each followed by the read.
        var next = size ~/ 3;
        final removeAndRead = await _time(() async {
          await _db.removePlaylistEntries(id, {page.entries[next++].entryId});
          await _db.playlistPage(id);
        });
        print(
          '[$size] removePlaylistEntries + playlistPage: ${_fmt(removeAndRead)}',
        );
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  for (final size in _sizes) {
    testWidgets(
      '[$size] playlist page first frame',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final id = _ids[size]!;
        final page = (await tester.runAsync(() => _db.playlistPage(id)))!;

        // The app shell is mounted once; each run swaps only the page in.
        final slot = ValueNotifier<Widget>(const SizedBox());
        addTearDown(slot.dispose);
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<Widget>(
              valueListenable: slot,
              builder: (_, child, _) => child,
            ),
          ),
        );
        Future<List<int>> timed(
          Widget Function() page, {
          bool waitForDb = false,
          bool clearFirst = true,
        }) async {
          final times = <int>[];
          for (var i = 0; i <= _runs; i++) {
            if (clearFirst) {
              slot.value = const SizedBox();
              await tester.pump();
            }
            final sw = Stopwatch()..start();
            slot.value = page();
            await tester.pump();
            if (waitForDb) await _pumpUntilRows(tester);
            if (i > 0) times.add(sw.elapsedMicroseconds);
          }
          return times..sort();
        }

        // The whole route: provider, query on the database isolate, rows.
        final route = await timed(
          () => PlaylistScreen(routeId: '$id'),
          waitForDb: true,
        );
        // The UI isolate only: build and lay out a page already read.
        final build = await timed(() => _view(page));
        // A reload after an edit: same view, a new page object.
        final reload = await timed(
          () => _view(
            PlaylistPage(playlist: page.playlist, entries: [...page.entries]),
          ),
          clearFirst: false,
        );
        slot.value = const SizedBox();
        await tester.pump();

        String ms(List<int> t) =>
            'median ${(t[_runs ~/ 2] / 1000).toStringAsFixed(1)} ms, '
            'best ${(t.first / 1000).toStringAsFixed(1)} ms';
        print('[$size] PlaylistScreen to first row: ${ms(route)}');
        print('[$size] PlaylistEntriesView build of a read page: ${ms(build)}');
        print(
          '[$size] PlaylistEntriesView rebuild with a new page: ${ms(reload)}',
        );
      },
      skip: !_enabled,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
