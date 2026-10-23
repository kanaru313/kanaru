import '../database/library_database.dart'
    show LibraryDatabase, TracksCompanion;
import '../database/library_rows.dart' show TrackSnapshot;
import '../database/scan_filter_queries.dart';
import 'short_track_memo.dart';
import 'walk_audio_files.dart';

/// The minimum-duration rule for one root during one scan: which files to
/// read at all, which rows to store, and which stored tracks go because they
/// are too short. Keeps the bookkeeping out of the indexer's root loop.
class RootShortTrackRules {
  RootShortTrackRules({
    required this._memo,
    required this.minMs,
    required List<TrackSnapshot> snapshot,
  }) : _idByPath = {for (final track in snapshot) track.path: track.id};

  final ShortTrackMemo _memo;

  /// Tracks shorter than this are not stored; 0 keeps all.
  final int minMs;
  final Map<String, int> _idByPath;

  /// Ids of stored tracks found too short, to delete with the diff's own.
  final Set<int> _tooShort = {};

  /// Files left out for their length so far in this scan: skipped as
  /// remembered, or read and found short.
  int tooShortFiles = 0;

  /// The files of [toRead] still worth reading: one already found too short
  /// and unchanged is skipped, and its old row (if any) is to be deleted.
  List<WalkedFile> filterToRead(Iterable<WalkedFile> toRead) {
    final keep = <WalkedFile>[];
    for (final file in toRead) {
      if (!_memo.skips(file, minMs)) {
        keep.add(file);
        continue;
      }
      tooShortFiles++;
      if (_idByPath[file.path] case final id?) {
        _tooShort.add(id);
      }
    }
    return keep;
  }

  /// The rows of [read] (one per file of [batch], in order) to store; the
  /// stored tracks of the short ones are to be deleted.
  List<TracksCompanion> keepLongEnough(
    List<WalkedFile> batch,
    List<TracksCompanion> read,
  ) {
    final (:kept, :shortPaths) = _memo.splitShort(batch, read, minMs);
    tooShortFiles += shortPaths.length;
    for (final path in shortPaths) {
      if (_idByPath[path] case final id?) _tooShort.add(id);
    }
    return kept;
  }

  /// [diffDeletes] plus every track of [rootId] too short, found now or
  /// stored by an earlier scan with a lower minimum (those unchanged files
  /// were not read, so they are counted in [tooShortFiles] here). A stored
  /// track already in [diffDeletes] is not counted: its file is gone or left
  /// out by another rule, and that has its own count.
  Future<Set<int>> deletes(
    LibraryDatabase db,
    int rootId,
    Iterable<int> diffDeletes,
  ) async {
    final gone = diffDeletes.toSet();
    final stored = await db.shortTrackIds(rootId, minMs);
    tooShortFiles += stored
        .where((id) => !_tooShort.contains(id) && !gone.contains(id))
        .length;
    return {...gone, ..._tooShort, ...stored};
  }
}
