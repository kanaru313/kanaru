import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plugin_runtime/plugin_runtime.dart';

/// Stops a running unit of work of one plugin. Call it when the run ends,
/// however it ends; calling it again does nothing.
typedef PluginRunUnregister = void Function();

/// The running script runs of each plugin, so an uninstall or an update can
/// cancel them first. A run registers its [PluginCancel] when it starts and
/// unregisters when it ends.
///
/// While an update or uninstall of a plugin is changing it, the plugin is
/// blocked: [register] returns null, and the caller skips that run. Register
/// before reading the plugin's record or package, so a run that gets past the
/// block sees the finished change. The block is lifted when the change ends;
/// after an uninstall the record is gone or removed, which the caller checks.
class PluginRunRegistry {
  PluginRunRegistry({this.cancelWait = const Duration(seconds: 1)});

  /// Longest wait in [cancelAll] for the cancelled runs to end.
  final Duration cancelWait;

  final Map<String, Set<_Entry>> _runs = {};
  final Map<String, int> _blocks = {};

  /// Records a running run of [installId]. The returned function removes it.
  /// Returns null while [installId] is blocked: do not run.
  PluginRunUnregister? register(String installId, PluginCancel cancel) {
    if (isBlocked(installId)) return null;
    final entry = _Entry(cancel);
    _runs.putIfAbsent(installId, () => {}).add(entry);
    return () {
      if (entry.done.isCompleted) return;
      entry.done.complete();
      final set = _runs[installId];
      set?.remove(entry);
      if (set != null && set.isEmpty) _runs.remove(installId);
    };
  }

  bool isBlocked(String installId) => (_blocks[installId] ?? 0) > 0;

  /// Refuses new runs of [installId] until the matching [unblock]. Calls
  /// nest.
  void block(String installId) =>
      _blocks[installId] = (_blocks[installId] ?? 0) + 1;

  void unblock(String installId) {
    final left = (_blocks[installId] ?? 0) - 1;
    if (left <= 0) {
      _blocks.remove(installId);
    } else {
      _blocks[installId] = left;
    }
  }

  /// How many runs of [installId] are registered.
  int runningCount(String installId) => _runs[installId]?.length ?? 0;

  /// Cancels every registered run of [installId] and waits until they have
  /// unregistered, but at most [cancelWait]. Runs that do not end in time are
  /// left: the guarded database writes refuse what they try to save.
  Future<void> cancelAll(String installId) async {
    final entries = List.of(_runs[installId] ?? const <_Entry>{});
    if (entries.isEmpty) return;
    for (final entry in entries) {
      entry.cancel.cancel();
    }
    await Future.wait([for (final entry in entries) entry.done.future])
        .timeout(cancelWait, onTimeout: () => const <void>[]);
  }
}

class _Entry {
  _Entry(this.cancel);

  final PluginCancel cancel;
  final Completer<void> done = Completer<void>();
}

/// The one registry of the app. Runs register here; uninstall and update
/// cancel through it.
final pluginRunRegistryProvider = Provider<PluginRunRegistry>(
  (ref) => PluginRunRegistry(),
);
