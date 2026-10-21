import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
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
      [const TrackTags(path: '/m/Song One.flac')],
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
      [const TrackTags(path: '/m/Song One.flac', error: 'unsupported')],
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

  test('rows keep their cover key and are left for the cover pass', () {
    for (final tags in [
      [const TrackTags(path: '/m/Song One.flac', title: 'T')],
      <TrackTags>[],
    ]) {
      final row = tracksFromTags(1, [_file], tags, 1).single;
      expect(row.coverKey, const Value<String?>.absent());
      expect(row.coverScanVersion, const Value(0));
    }
  });
}
