// Times the folder and genre queries and the folder tree on a 100k-track file
// database. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/folder_queries_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/folder_queries.dart';
import 'package:kanaru/core/database/genre_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';
import 'package:kanaru/shared/natural_compare.dart';

const _total = 100000;
const _batch = 512;

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

/// A cover key of the stored shape (`ab/ab<hex>.jpg`) for [n].
String _coverKey(int n) {
  final hex = (n * 2654435761 & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '${hex.substring(0, 2)}/${hex.substring(0, 2)}$hex.jpg';
}

/// 100k files in about 18k folders three levels below the root, with long
/// non-ASCII names, numbered discs and 3 000 distinct genres. About 70% of the
/// tracks have their own cover, 20% one shared by the folder, 10% none.
List<TracksCompanion> _rows(int rootId) {
  final rnd = Random(1);
  const accents = ['Ánh', 'Sơn Tùng', 'Mỹ Tâm', 'Ünïcødé', '漢字', 'Ølsen'];
  return [
    for (var i = 0; i < _total; i++)
      () {
        final folder = i ~/ 5.5;
        final artist = folder % 2000;
        final album = folder ~/ 2000;
        final dir =
            '/home/user/Music/${accents[artist % accents.length]} Artist '
            '$artist/Album ${folder % 9} Đĩa ${album + 1}/CD ${folder % 12}';
        final roll = i % 10;
        final cover = roll < 7
            ? _coverKey(i)
            : roll < 9
            ? _coverKey(1000000 + folder)
            : null;
        return TracksCompanion.insert(
          rootId: rootId,
          path: '$dir/${rnd.nextInt(99)} Bài hát số $i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Bài $i',
          coverKey: Value(cover),
          genre: Value(i % 7 == 0 ? null : 'Genre ${rnd.nextInt(3000)}'),
          addedAt: i,
          updatedAt: i,
        );
      }(),
  ];
}

/// Median of 5 timed runs after one warm-up.
Future<int> _median(Future<void> Function() run) async {
  await run();
  final runs = <int>[];
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    await run();
    runs.add(sw.elapsedMilliseconds);
  }
  runs.sort();
  return runs[2];
}

void main() {
  test(
    'folder and genre queries on 100k tracks',
    () async {
      final dir = Directory.systemTemp.createTempSync('kanaru_bench');
      final db = LibraryDatabase(
        NativeDatabase.createInBackground(
          File('${dir.path}/library.db'),
          setup: applyLibraryPragmas,
        ),
      );
      final rows = _rows(
        (await db.addRoots(['/home/user/Music'], now: 1)).single,
      );
      for (var i = 0; i < rows.length; i += _batch) {
        await db.upsertTracks(rows.sublist(i, min(i + _batch, rows.length)));
      }

      final counts = await db.folderSongCounts();
      print('folders: ${counts.length}');
      final results = <String, int>{
        'folderSongCounts (paged paths, DB + UI isolate)': await _median(
          db.folderSongCounts,
        ),
        'rtrim GROUP BY (the SQL variant it replaced)': await _median(
          () => db
              .customSelect(
                "SELECT rtrim(path, replace(path, '/', '')) AS dir, "
                'count(*) AS n FROM tracks GROUP BY dir',
                readsFrom: {db.tracks},
              )
              .get(),
        ),
        'genreCounts (DB isolate)': await _median(db.genreCounts),
        'buildFolderTree (inline, UI isolate)': await _median(
          () async => buildFolderTree(['/home/user/Music'], counts),
        ),
        'buildFolderTree (Isolate.run, wall time)': await _median(
          () => buildFolderTreeInIsolate(['/home/user/Music'], counts),
        ),
        'folderTracks recursive, root': await _median(
          () => db.folderTracks('/home/user/Music', recursive: true),
        ),
      };
      final tracks = await db.folderTracks('/home/user/Music', recursive: true);
      final paths = [for (final t in tracks) t.path]..shuffle(Random(2));
      results['sortByNaturalPath 100k paths (Isolate.run)'] = await _median(
        () => sortByNaturalPath(paths, (p) => p),
      );
      // What the decorated sort replaces: a comparator that folds every time.
      final naive = Stopwatch()..start();
      [...paths].sort(compareNatural);
      results['naive sort with compareNatural 100k paths (1 run)'] =
          naive.elapsedMilliseconds;
      for (final e in results.entries) {
        print('${e.key}: ${e.value} ms');
      }
      await db.close();
      dir.deleteSync(recursive: true);
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
