import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/database/library_database.dart';

import 'library_test_harness.dart';

/// A track row as the indexer writes it, for inserting straight into the
/// test database.
class TestTrack {
  const TestTrack(
    this.title, {
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.disc,
    this.track,
    this.durationMs = 1000,
    this.addedAt = 1,
    this.coverKey,
    this.genre,
    this.path,
  });

  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? year;
  final int? disc;
  final int? track;
  final int? durationMs;
  final int addedAt;
  final String? coverKey;
  final String? genre;

  /// Where the file is; a path of its own under the root `/m` when null.
  final String? path;
}

/// Stores [tracks] under the root `/m` (added if missing), with paths
/// unique to this call.
Future<void> insertTracks(
  WidgetTester tester,
  LibraryHarness h,
  List<TestTrack> tracks,
) async {
  await tester.runAsync(() async {
    final roots = await h.db.roots();
    final rootId = roots.isEmpty
        ? (await h.db.addRoots(['/m'], now: 1)).single
        : roots.first.id;
    final batch = _batches++;
    await h.db.upsertTracks([
      for (final (i, t) in tracks.indexed)
        TracksCompanion.insert(
          rootId: rootId,
          path: t.path ?? '/m/$batch/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: t.title,
          artist: Value(t.artist),
          album: Value(t.album),
          albumArtist: Value(t.albumArtist),
          year: Value(t.year),
          discNo: Value(t.disc),
          trackNo: Value(t.track),
          durationMs: Value(t.durationMs),
          addedAt: t.addedAt,
          updatedAt: t.addedAt,
          coverKey: Value(t.coverKey),
          genre: Value(t.genre),
        ),
    ]);
  });
}

var _batches = 0;

/// Opens the app on [location] with a root and [tracks] already stored.
Future<void> openWithTracks(
  WidgetTester tester,
  LibraryHarness h,
  List<TestTrack> tracks, {
  required String location,
}) async {
  await insertTracks(tester, h, tracks);
  await h.pump(tester, hasRoots: true);
  goTo(tester, h, location);
  await tester.pumpAndSettle();
}

void goTo(WidgetTester tester, LibraryHarness h, String location) =>
    h.container.read(routerProvider).go(location);

/// The current router location.
String location(LibraryHarness h) => h.container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();
