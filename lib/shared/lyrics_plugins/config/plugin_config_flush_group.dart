import 'dart:async';

import 'package:flutter/foundation.dart';

/// An editor that may hold an edit not saved yet and can save it on demand.
abstract interface class PluginConfigFlushable {
  /// Whether the editor holds something that is not saved (a pending edit, or
  /// a save under way).
  bool get dirty;

  /// Saves what the editor holds and waits until it is saved. True when the
  /// latest content is saved with no error.
  Future<bool> flush();
}

/// A set of [PluginConfigFlushable] editors saved together: a footer shows
/// its button while [anyDirty] and calls [flushAll] before it acts.
class PluginConfigFlushGroup {
  final Set<PluginConfigFlushable> _members = {};
  final ValueNotifier<bool> _anyDirty = ValueNotifier(false);
  bool _disposed = false;

  /// Whether any member is dirty.
  ValueListenable<bool> get anyDirty => _anyDirty;

  /// Adds [member]. Its dirtiness counts once it calls [refresh].
  void register(PluginConfigFlushable member) => _members.add(member);

  /// Removes [member]. The change is told after the frame's tree work, since
  /// a member leaves while the tree is torn down.
  void unregister(PluginConfigFlushable member) {
    if (_disposed || !_members.remove(member)) return;
    scheduleMicrotask(refresh);
  }

  /// Recomputes [anyDirty]; call when a member's dirtiness may have changed.
  void refresh() {
    if (_disposed) return;
    _anyDirty.value = _members.any((m) => m.dirty);
  }

  /// Saves every member and waits for all. True only when every one saved.
  /// An exception of a member counts as not saved.
  Future<bool> flushAll() async {
    final results = await Future.wait([
      for (final member in _members.toList())
        member.flush().catchError((Object _) => false),
    ]);
    refresh();
    return results.every((ok) => ok);
  }

  void dispose() {
    _disposed = true;
    _members.clear();
    _anyDirty.dispose();
  }
}
