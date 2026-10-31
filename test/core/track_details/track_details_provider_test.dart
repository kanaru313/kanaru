import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/extra_tags.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/track_details/release_date.dart';
import 'package:kanaru/core/track_details/track_details.dart';
import 'package:kanaru/core/track_details/track_details_provider.dart';

void main() {
  late LibraryDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: LibraryStartup(db: db).overrides);
    await db.addRoots(['/m'], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> insert({String? extra}) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          rootId: 1,
          path: '/m/a.flac',
          mtimeMs: 1,
          sizeBytes: 2048,
          title: 'Halo',
          addedAt: 5,
          updatedAt: 6,
          artist: const Value('Beyonce'),
          year: const Value(2008),
          extraTags: Value(extra),
        ),
      );

  Future<TrackDetails?> next(int id) {
    final done = Completer<TrackDetails?>();
    final sub = container.listen(trackDetailsProvider(id), (_, value) {
      if (value.hasValue && !done.isCompleted) done.complete(value.value);
    }, fireImmediately: true);
    addTearDown(sub.close);
    return done.future;
  }

  test('maps the row, the parsed release date and the play totals', () async {
    final id = await insert(extra: encodeExtraTags(releaseDate: '2008-11-14'));
    await db.customStatement(
      'INSERT INTO play_stats (path, play_count, first_played_at, '
      "last_played_at) VALUES ('/m/a.flac', 3, 10, 30)",
    );

    final details = await next(id);

    expect(details!.title, 'Halo');
    expect(details.localPath, '/m/a.flac');
    expect(details.artist, 'Beyonce');
    expect(details.year, 2008);
    expect(
      details.releaseDate,
      const ReleaseDate(year: 2008, month: 11, day: 14),
    );
    expect(details.sizeBytes, 2048);
    expect(details.addedAtMs, 5);
    expect(details.playCount, 3);
    expect(details.firstPlayedAt, 10);
    expect(details.lastPlayedAt, 30);
  });

  test('a row without extra tags has no release date', () async {
    final id = await insert();
    final details = await next(id);
    expect(details!.releaseDate, isNull);
    expect(details.year, 2008);
    expect(details.playCount, 0);
  });

  test('an unknown id gives null', () async {
    expect(await next(999), isNull);
  });

  test('writes to another track do not re-emit, plays do', () async {
    final id = await insert();
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            rootId: 1,
            path: '/m/b.flac',
            mtimeMs: 1,
            sizeBytes: 1,
            title: 'Other',
            addedAt: 1,
            updatedAt: 1,
          ),
        );
    final seen = <TrackDetails?>[];
    final sub = container.listen(trackDetailsProvider(id), (_, value) {
      if (value.hasValue) seen.add(value.value);
    }, fireImmediately: true);
    addTearDown(sub.close);
    await next(id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final base = seen.length;

    await db.customStatement(
      "UPDATE tracks SET title = 'Z' WHERE path = '/m/b.flac'",
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.length, base);

    await db.customInsert(
      'INSERT INTO play_stats (path, play_count, first_played_at, '
      "last_played_at) VALUES ('/m/a.flac', 1, 10, 10)",
      updates: {db.playStats},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.last!.playCount, 1);
  });
}
