import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/indexer/tracks_from_tags.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

const _file = WalkedFile(path: '/m/Song One.flac', mtimeMs: 5, sizeBytes: 7);

void main() {
  test('copies every tag and the file facts', () {
    final row = tracksFromTags(
      3,
      [_file],
      [
        const TrackTags(
          coverStatus: CoverStatus.skipped,
          path: '/m/Song One.flac',
          title: 'Tagged',
          artist: 'A; B',
          album: 'Alb',
          trackNo: 2,
          year: 2020,
          durationMs: 1234,
          sampleRate: 44100,
        ),
      ],
      99,
    ).single;

    expect(row.rootId.value, 3);
    expect(row.path.value, '/m/Song One.flac');
    expect(row.mtimeMs.value, 5);
    expect(row.sizeBytes.value, 7);
    expect(row.title.value, 'Tagged');
    expect(row.artist.value, 'A; B');
    expect(row.trackNo.value, 2);
    expect(row.year.value, 2020);
    expect(row.durationMs.value, 1234);
    expect(row.addedAt.value, 99);
    expect(row.updatedAt.value, 99);
    expect(row.scanError.value, isNull);
  });

  test('no title tag falls back to the file name', () {
    final row = tracksFromTags(
      1,
      [_file],
      [
        const TrackTags(
          coverStatus: CoverStatus.skipped,
          path: '/m/Song One.flac',
        ),
      ],
      1,
    ).single;

    expect(row.title.value, 'Song One');
    expect(row.artist.value, isNull);
    expect(row.year.value, isNull);
    expect(row.trackNo.value, isNull);
  });

  test('a read error is kept as scanError with the fallback title', () {
    final row = tracksFromTags(
      1,
      [_file],
      [
        const TrackTags(
          coverStatus: CoverStatus.skipped,
          path: '/m/Song One.flac',
          error: 'unsupported',
        ),
      ],
      1,
    ).single;

    expect(row.title.value, 'Song One');
    expect(row.scanError.value, 'unsupported');
  });

  test('a file with no tag entry is still stored', () {
    final row = tracksFromTags(1, [_file], [], 1).single;

    expect(row.title.value, 'Song One');
    expect(row.scanError.value, isNotNull);
  });

  group('cover columns', () {
    TracksCompanion rowFor(CoverStatus status, {String? cover}) =>
        tracksFromTags(
          1,
          [_file],
          [TrackTags(path: _file.path, cover: cover, coverStatus: status)],
          1,
        ).single;

    test('a found cover is stored and stamped', () {
      final row = rowFor(CoverStatus.found, cover: 'ab/ab.jpg');
      expect(row.coverKey, const Value('ab/ab.jpg'));
      expect(row.coverScanVersion, const Value(coverScanVersion));
    });

    test('no cover clears the key and is stamped', () {
      final row = rowFor(CoverStatus.none);
      expect(row.coverKey, const Value<String?>(null));
      expect(row.coverScanVersion, const Value(coverScanVersion));
    });

    test('a failed lookup keeps the key and clears the stamp', () {
      final row = rowFor(CoverStatus.failed);
      expect(row.coverKey, const Value<String?>.absent());
      expect(row.coverScanVersion, const Value(0));
    });

    test('a skipped lookup keeps the key and clears the stamp', () {
      final row = rowFor(CoverStatus.skipped);
      expect(row.coverKey, const Value<String?>.absent());
      expect(row.coverScanVersion, const Value(0));
    });

    test('a missing entry leaves both alone', () {
      final row = tracksFromTags(1, [_file], [], 1).single;
      expect(row.coverKey, const Value<String?>.absent());
      expect(row.coverScanVersion, const Value<int>.absent());
    });
  });
}
