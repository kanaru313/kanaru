import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_indexer.dart';

/// A [LibraryIndexer] whose progress a test sets step by step with [emit];
/// [scan] only counts the calls.
class ScriptedIndexer extends LibraryIndexer {
  int scans = 0;

  @override
  Future<void> scan() async => scans++;

  void emit(IndexerState next) => state = next;
}
