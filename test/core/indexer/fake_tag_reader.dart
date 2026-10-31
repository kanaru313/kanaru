import 'dart:async';
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
/// files named `bad*` report a permanent error, `flaky*` a transient one,
/// and `.dsf`/`.dff` files come back without tags or error like real DSD.
/// Records every path it was asked to read, tags and covers apart.
///
/// Covers are skipped until [coverDirectory] is set. Then a file named in
/// [coverByName] gets that cover: the thumbnail is written into the folder
/// (an hour old, like one from an earlier scan, unless it exists) and the
/// status is found; a name in [failingCovers] fails; any other file has no
/// cover. A cover batch holding a name in [hangingCovers] waits for
/// [releaseHangingCovers]; [throwOnCovers] makes every cover batch throw.
class FakeTagReader implements TagReader {
  final List<List<String>> batches = [];
  final List<List<String>> coverBatches = [];
  Object? throwOnRead;
  Object? throwOnCovers;

  /// Throws on the n-th call of [readBatch] counted from 1 (since the last
  /// [reset]); the earlier calls succeed.
  int? failOnBatch;

  String? coverDirectory;

  /// File name → duration in ms, for files that should not read as 1000 ms.
  final Map<String, int> durationByName = {};

  /// File names whose read reports a permanent error.
  final Set<String> permanentReads = {};

  /// File names whose read reports a transient error.
  final Set<String> failingReads = {};

  /// File name → raw release date the fake reports for it (none by default).
  final Map<String, String> releaseDateByName = {};

  /// File name → cover name (see [fakeCoverKey]).
  final Map<String, String> coverByName = {};
  final Set<String> failingCovers = {};
  final Set<String> hangingCovers = {};
  Completer<void>? _hang;

  /// Total paths read so far.
  int get readCount => batches.fold(0, (sum, b) => sum + b.length);

  /// Total paths whose cover was looked for so far.
  int get coverCount => coverBatches.fold(0, (sum, b) => sum + b.length);

  void reset() {
    batches.clear();
    coverBatches.clear();
    failOnBatch = null;
  }

  /// Lets a hanging cover batch return (its files then get their covers).
  void releaseHangingCovers() {
    hangingCovers.clear();
    _hang?.complete();
    _hang = null;
  }

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    batches.add(List.of(paths));
    final error = throwOnRead;
    if (error != null) throw error;
    if (failOnBatch == batches.length) throw StateError('batch failed');
    return [
      for (final path in paths)
        switch (path.split('/').last.toLowerCase()) {
          final name when name.startsWith('bad') => _tags(
            path,
            error: 'permanent:v1:unsupported',
          ),
          final name when permanentReads.contains(name) => _tags(
            path,
            error: 'permanent:v1:unsupported',
          ),
          final name
              when name.startsWith('flaky') || failingReads.contains(name) =>
            _tags(path, error: 'Permission denied'),
          final name when name.endsWith('.dsf') || name.endsWith('.dff') =>
            _tags(path),
          _ => _tags(path, title: path.split('/').last.toUpperCase()),
        },
    ];
  }

  TrackTags _tags(String path, {String? error, String? title}) => TrackTags(
    path: path,
    error: error,
    title: title,
    artist: error == null ? 'Artist' : null,
    durationMs: error == null
        ? durationByName[path.split('/').last] ?? 1000
        : null,
    releaseDate: error == null ? releaseDateByName[path.split('/').last] : null,
  );

  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async {
    coverBatches.add(List.of(paths));
    final error = throwOnCovers;
    if (error != null) throw error;
    if (paths.any((p) => hangingCovers.contains(p.split('/').last))) {
      await (_hang ??= Completer<void>()).future;
    }
    return [for (final path in paths) _cover(path)];
  }

  TrackCover _cover(String path) {
    final dir = coverDirectory;
    if (dir == null) return TrackCover(path: path, status: CoverStatus.skipped);
    final name = path.split('/').last;
    final cover = coverByName[name];
    if (failingCovers.contains(name)) {
      return TrackCover(path: path, status: CoverStatus.failed);
    }
    if (cover == null) return TrackCover(path: path, status: CoverStatus.none);
    final key = fakeCoverKey(cover);
    final file = File('$dir/$key');
    if (!file.existsSync() || file.lengthSync() == 0) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync('jpeg of $cover')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
    }
    return TrackCover(path: path, cover: key, status: CoverStatus.found);
  }
}
