import 'dart:io';

import 'package:kanaru/core/indexer/tag_reader.dart';

/// A valid cover key made from [name] (hex of its characters, padded), so
/// tests can name covers instead of hashing images.
String fakeCoverKey(String name) {
  final hex = [
    for (final unit in name.codeUnits) unit.toRadixString(16).padLeft(2, '0'),
  ].join().padRight(64, '0').substring(0, 64);
  return '${hex.substring(0, 2)}/$hex.jpg';
}

/// Stands in for the Rust reader. Titles are the file name upper-cased;
/// files named `bad*` report an error. Records every path it was asked to read.
///
/// Covers are off until [coverDirectory] is set. Then a file named in
/// [coverByName] gets that cover: the thumbnail is written into the folder
/// (an hour old, like one from an earlier scan, unless it exists) and the
/// status is found; a name in [failingCovers] fails; any other file has no
/// cover.
class FakeTagReader implements TagReader {
  final List<List<String>> batches = [];
  Object? throwOnRead;

  /// Throws on the n-th call of [readBatch] counted from 1 (since the last
  /// [reset]); the earlier calls succeed.
  int? failOnBatch;

  String? coverDirectory;

  /// File name → cover name (see [fakeCoverKey]).
  final Map<String, String> coverByName = {};
  final Set<String> failingCovers = {};

  /// Total paths read so far.
  int get readCount => batches.fold(0, (sum, b) => sum + b.length);

  void reset() {
    batches.clear();
    failOnBatch = null;
  }

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    batches.add(List.of(paths));
    final error = throwOnRead;
    if (error != null) throw error;
    if (failOnBatch == batches.length) throw StateError('batch failed');
    return [
      for (final path in paths)
        path.split('/').last.startsWith('bad')
            ? _tags(path, error: 'unsupported')
            : _tags(path, title: path.split('/').last.toUpperCase()),
    ];
  }

  TrackTags _tags(String path, {String? error, String? title}) {
    final name = path.split('/').last;
    var status = CoverStatus.skipped;
    String? key;
    final dir = coverDirectory;
    if (dir != null) {
      final cover = coverByName[name];
      if (failingCovers.contains(name)) {
        status = CoverStatus.failed;
      } else if (cover != null) {
        key = fakeCoverKey(cover);
        final file = File('$dir/$key');
        if (!file.existsSync() || file.lengthSync() == 0) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync('jpeg of $cover')
            ..setLastModifiedSync(
              DateTime.now().subtract(const Duration(hours: 1)),
            );
        }
        status = CoverStatus.found;
      } else {
        status = CoverStatus.none;
      }
    }
    return TrackTags(
      path: path,
      error: error,
      title: title,
      artist: error == null ? 'Artist' : null,
      durationMs: error == null ? 1000 : null,
      cover: key,
      coverStatus: status,
    );
  }
}
