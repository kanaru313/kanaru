import 'package:kanaru/core/indexer/tag_reader.dart';

/// Stands in for the Rust reader. Titles are the file name upper-cased;
/// files named `bad*` report an error. Records every path it was asked to read.
class FakeTagReader implements TagReader {
  final List<List<String>> batches = [];
  Object? throwOnRead;

  /// Total paths read so far.
  int get readCount => batches.fold(0, (sum, b) => sum + b.length);

  void reset() => batches.clear();

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    batches.add(List.of(paths));
    final error = throwOnRead;
    if (error != null) throw error;
    return [
      for (final path in paths)
        path.split('/').last.startsWith('bad')
            ? TrackTags(path: path, error: 'unsupported')
            : TrackTags(
                path: path,
                title: path.split('/').last.toUpperCase(),
                artist: 'Artist',
                durationMs: 1000,
              ),
    ];
  }
}
