import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';

import '../library_test_harness.dart';
import '../browse_test_data.dart';

/// A track with a stored language tag ([language] null: untagged).
class LangTrack {
  const LangTrack(this.title, this.language, {this.album, this.albumArtist});

  final String title;
  final String? language;
  final String? album;
  final String? albumArtist;
}

/// Opens the app on [location] with a root and [tracks] stored.
Future<void> openWithLanguages(
  WidgetTester tester,
  LibraryHarness h,
  List<LangTrack> tracks, {
  required String location,
}) async {
  await tester.runAsync(() async {
    final ids = await h.db.addRoots(['/m'], now: 1);
    await h.db.upsertTracks([
      for (final (i, t) in tracks.indexed)
        TracksCompanion.insert(
          rootId: ids.single,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: t.title,
          album: Value(t.album),
          albumArtist: Value(t.albumArtist),
          durationMs: const Value(1000),
          addedAt: 1,
          updatedAt: 1,
          language: Value(t.language),
        ),
    ]);
  });
  await h.pump(tester, hasRoots: true);
  goTo(tester, h, location);
  await tester.pumpAndSettle();
}
