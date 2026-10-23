// Times the playlist page on 1k, 10k and 50k entry playlists over a 50k-track
// file database, through the same background isolate the app uses: opening
// (header and first page of rows), reading again after a move and after a
// removal, the queue read when a row is tapped, and the first frame with rows.
// The whole-playlist read (`playlistPage`, used by M3U export) is timed too.
// Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/playlist_page_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_song_paging.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_page_queries.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_entries_view.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/features/playlists/playlist_page_actions.dart';
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

/// 50k entries, none of whose files is in the library.
late int _allMissing;

/// 50k entries of library tracks without a cover.
late int _noCovers;

/// One page of rows, as the list reads them.
const _page = 100;

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

PlaylistEntriesView _view(PlaylistPageHead head) => PlaylistEntriesView(
  head: head,
  loadRows: (start, count) =>
      _db.playlistEntriesAt(head.playlist.id, start, count),
  onMove: (_, _) async => true,
  onRemove: (_) async => true,
  onSettled: () => 0,
  onPlayFrom: (_, _) async {},
);

/// What the page reads after an edit: the header and the two pages a
/// screen shows.
Future<void> _reread(int id, int at) async {
  await _db.playlistPageHead(id);
  await _db.playlistEntriesAt(id, at, _page);
  await _db.playlistEntriesAt(id, at + _page, _page);
}

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
    // Duplicates are allowed: 50k entries over the 16 667 coverless tracks.
    final coverless = [for (var i = 0; i < _tracks; i += 3) _trackPath(i)];
    _noCovers = await _db.createPlaylist(
      'No covers',
      now: 1,
      paths: [
        for (var i = 0; i < _sizes.last; i++) coverless[i % coverless.length],
      ],
    );
    _allMissing = await _db.createPlaylist(
      'All missing',
      now: 2,
      paths: [for (var i = 0; i < _sizes.last; i++) '/gone/lost $i.mp3'],
    );
  });

  tearDownAll(() async {
    if (!_enabled) return;
    await _db.close();
    _dir.deleteSync(recursive: true);
  });

  test(
    'playlist page reads',
    () async {
      for (final size in _sizes) {
        final id = _ids[size]!;
        // The first open of this playlist, before any warm-up.
        final cold = Stopwatch()..start();
        final head = (await _db.playlistPageHead(id))!;
        await _db.playlistEntriesAt(id, 0, _page);
        cold.stop();
        expect(head.playlist.entryCount, size);
        print(
          '[$size] open (head + first page, 1 run, cold): '
          '${(cold.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms',
        );
        print(
          '[$size] playlistPageHead: ${_fmt(await _time(() => _db.playlistPageHead(id)))}',
        );
        print(
          '[$size] open (head + first page): ${_fmt(await _time(() async {
            await _db.playlistPageHead(id);
            await _db.playlistEntriesAt(id, 0, _page);
          }))}',
        );
        print(
          '[$size] playlistEntriesAt middle page: '
          '${_fmt(await _time(() => _db.playlistEntriesAt(id, size ~/ 2, _page)))}',
        );
        print(
          '[$size] playlistPage (whole playlist, M3U export): ${_fmt(await _time(() => _db.playlistPage(id)))}',
        );

        // A move of the middle entry back and forth, then what the page
        // reads after it.
        final middle = (await _db.playlistEntriesAt(
          id,
          size ~/ 2,
          1,
        )).single.entry.entryId;
        var to = size ~/ 4;
        print(
          '[$size] movePlaylistEntry write: ${_fmt(await _time(() async {
            await _db.movePlaylistEntry(id, middle, to);
            to = to == size ~/ 4 ? size ~/ 2 : size ~/ 4;
          }))}',
        );
        await _db.movePlaylistEntry(id, middle, to);
        print(
          '[$size] reread after a move (head + 2 pages): ${_fmt(await _time(() => _reread(id, size ~/ 4)))}',
        );

        // One removal per run, each followed by the reread.
        final victims = [
          for (final e in await _db.playlistEntriesAt(id, size ~/ 3, 2 * _page))
            e.entry.entryId,
        ];
        var next = 0;
        print(
          '[$size] removePlaylistEntries write: ${_fmt(await _time(() => _db.removePlaylistEntries(id, {victims[next++]})))}',
        );
        print(
          '[$size] remove + reread (head + 2 pages): ${_fmt(await _time(() async {
            await _db.removePlaylistEntries(id, {victims[next++]});
            await _reread(id, size ~/ 3);
          }))}',
        );

        // A tap on a row: the playable tracks, the start index and the
        // queue entries (the last two on the UI isolate).
        print(
          '[$size] playlistPlayableTracks: ${_fmt(await _time(() => _db.playlistPlayableTracks(id)))}',
        );
        print(
          '[$size] tap to queue (read + start + Track list): ${_fmt(await _time(() async {
            final playable = await _db.playlistPlayableTracks(id);
            final start = playableStartIndex(playable, middle, size ~/ 4);
            final tracks = [for (final p in playable) playlistTrack(p.track, '/covers')];
            expect(start, isNotNull);
            expect(tracks, isNotEmpty);
          }))}',
        );
      }

      // The worst cases of the header: the collage and the playable check
      // find nothing and scan the whole playlist.
      print(
        '[50000 all missing] playlistPageHead: ${_fmt(await _time(() => _db.playlistPageHead(_allMissing)))}',
      );
      print(
        '[50000 no covers] playlistPageHead: ${_fmt(await _time(() => _db.playlistPageHead(_noCovers)))}',
      );
      // The Songs page reads its whole queue on a tap too; the reference.
      final firstSong = (await _db.songIds()).first;
      print(
        '[50000 songs] songQueueFrom (Songs tap): ${_fmt(await _time(() => _db.songQueueFrom(firstSong)))}',
      );
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
        final head = (await tester.runAsync(() => _db.playlistPageHead(id)))!;

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
        // The view with a header already read, until its first rows.
        final build = await timed(() => _view(head), waitForDb: true);
        // A reload after an edit: same view, a new header object (the rows
        // on screen stay drawn while they are read again).
        final reload = await timed(
          () => _view(
            PlaylistPageHead(
              playlist: head.playlist,
              coverKeys: head.coverKeys,
              hasPlayable: head.hasPlayable,
            ),
          ),
          clearFirst: false,
        );
        slot.value = const SizedBox();
        await tester.pump();

        String ms(List<int> t) =>
            'median ${(t[_runs ~/ 2] / 1000).toStringAsFixed(1)} ms, '
            'best ${(t.first / 1000).toStringAsFixed(1)} ms';
        print('[$size] PlaylistScreen to first row: ${ms(route)}');
        print(
          '[$size] PlaylistEntriesView to first row (header read): ${ms(build)}',
        );
        print(
          '[$size] PlaylistEntriesView rebuild with a new header: ${ms(reload)}',
        );
      },
      skip: !_enabled,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
