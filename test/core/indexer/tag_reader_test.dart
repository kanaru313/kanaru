import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';

/// Stands in for the native reader; shows the generated [TrackTags] can be
/// built and compared in plain `flutter test`, with no native library loaded.
class _FakeTagReader implements TagReader {
  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async => [
    for (final path in paths)
      path.endsWith('.bad')
          ? TrackTags(path: path, error: 'unsupported')
          : TrackTags(path: path, title: 'Song', durationMs: 1500, year: 2019),
  ];

  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async => [
    for (final path in paths) TrackCover(path: path, status: CoverStatus.none),
  ];
}

void main() {
  test('generated TrackTags is constructible without the native library', () {
    const tags = TrackTags(path: '/music/a.flac', title: 'A', trackNo: 3);

    expect(tags.path, '/music/a.flac');
    expect(tags.title, 'A');
    expect(tags.trackNo, 3);
    expect(tags.artist, isNull);
    expect(tags.error, isNull);
    expect(
      tags,
      const TrackTags(path: '/music/a.flac', title: 'A', trackNo: 3),
    );
  });

  test('a TagReader returns one entry per path in order', () async {
    final result = await _FakeTagReader().readBatch([
      '/m/1.flac',
      '/m/2.bad',
      '/m/3.mp3',
    ]);

    expect(result.map((t) => t.path), ['/m/1.flac', '/m/2.bad', '/m/3.mp3']);
    expect(result[1].error, 'unsupported');
    expect(result[0].durationMs, 1500);
  });
}
