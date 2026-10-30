import 'dart:async';

import 'repo_operation_results.dart';

/// De-duplicates running installs and updates and tells which plugins are
/// being updated. Two calls with one key share one run (one download, one
/// write); the key is dropped when the run ends, however it ends.
class RepoRunTracker {
  final _runs = <String, Future<RepoPluginResult>>{};
  final _updatingIds = <String>{};
  final _changes = StreamController<Set<String>>.broadcast();

  /// Install ids being updated right now.
  Set<String> get updating => Set.unmodifiable(_updatingIds);

  /// The whole [updating] set, emitted each time it changes (read [updating]
  /// for the value before the first event). The set is empty again once every
  /// started update has ended, whether it succeeded, failed or was skipped.
  Stream<Set<String>> get updatingChanges => _changes.stream;

  /// Runs [run] unless a run with [key] is going; then that one is returned.
  /// With [updatingId] the id is in [updating] while the run lasts.
  Future<RepoPluginResult> share(
    String key,
    Future<RepoPluginResult> Function() run, {
    String? updatingId,
  }) {
    final running = _runs[key];
    if (running != null) return running;
    if (updatingId != null) _setUpdating(updatingId, true);
    return _runs[key] = run().whenComplete(() {
      // A block body: returning the removed future would make it wait on itself.
      _runs.remove(key);
      if (updatingId != null) _setUpdating(updatingId, false);
    });
  }

  void _setUpdating(String id, bool on) {
    final changed = on ? _updatingIds.add(id) : _updatingIds.remove(id);
    if (changed && !_changes.isClosed) _changes.add(updating);
  }

  Future<void> dispose() => _changes.close();
}
