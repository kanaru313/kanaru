import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_indexer.dart';

/// A [LibraryIndexer] whose progress a test sets step by step with [emit];
/// [scan] only counts the calls.
class ScriptedIndexer extends LibraryIndexer {
  int scans = 0;

  /// The `quiet` argument of the last [scan].
  bool? lastQuiet;

  @override
  Future<void> scan({bool quiet = false}) async {
    scans++;
    lastQuiet = quiet;
  }

  void emit(IndexerState next) => state = next;
}
