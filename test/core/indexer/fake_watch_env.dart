import 'dart:async';
import 'dart:io';

import 'package:kanaru/core/indexer/folder_watcher.dart';

/// Timers that fire only when [advance] moves the clock past them.
class FakeTimers {
  Duration _now = Duration.zero;
  final List<_FakeTimer> _timers = [];

  /// Timers that are still waiting.
  int get active => _timers.where((t) => t.isActive).length;

  Timer make(Duration duration, void Function() callback) {
    final timer = _FakeTimer(_now + duration, callback);
    _timers.add(timer);
    return timer;
  }

  void advance(Duration by) {
    final end = _now + by;
    while (true) {
      final due = _timers.where((t) => t.isActive && t.at <= end).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.at;
      next.fire();
    }
    _now = end;
    _timers.removeWhere((t) => !t.isActive);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.at, this._callback);
  final Duration at;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// One stream controller per watched folder, like inotify gives one stream
/// per `Directory.watch`.
class FakeDirWatch {
  final Map<String, StreamController<FileSystemEvent>> controllers = {};
  final List<String> opened = [];

  /// Folders whose watch fails with this error as soon as it is listened.
  final Map<String, Object> failing = {};

  Stream<FileSystemEvent> call(String dir) {
    opened.add(dir);
    final controller = StreamController<FileSystemEvent>(
      onListen: () {
        final error = failing[dir];
        if (error != null) {
          controllers[dir]!
            ..addError(error)
            ..close();
        }
      },
    );
    controllers[dir] = controller;
    return controller.stream;
  }

  bool hasListener(String dir) => controllers[dir]?.hasListener ?? false;
  bool get anyListener => controllers.values.any((c) => c.hasListener);

  void emit(String dir, FileSystemEvent event) => controllers[dir]!.add(event);
}

FileSystemException outOfWatches(String dir) => FileSystemException(
  'Failed to watch path',
  dir,
  const OSError('No space left on device', 28),
);

FileSystemException denied(String dir) => FileSystemException(
  'Failed to watch path',
  dir,
  const OSError('Permission denied', 13),
);

const quietFor = Duration(seconds: 3);

/// Lets stream events and microtasks run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

typedef Watcher = ({
  FolderWatcher watcher,
  FakeDirWatch dirs,
  FakeTimers timers,
  List<int> changes,
});

Watcher makeWatcher({int maxWatches = 100}) {
  final dirs = FakeDirWatch();
  final timers = FakeTimers();
  final changes = <int>[];
  final watcher = FolderWatcher(
    watch: dirs.call,
    onChange: () => changes.add(changes.length + 1),
    maxWatches: maxWatches,
    timer: timers.make,
  );
  return (watcher: watcher, dirs: dirs, timers: timers, changes: changes);
}
