import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'audio_file_types.dart';
import 'change_debouncer.dart';
import 'walk_audio_files.dart';

final _log = Logger('folder_watcher');

/// Watches one folder (not its subfolders: Dart ignores `recursive` on
/// Linux, so the watcher watches each folder itself).
typedef DirWatch = Stream<FileSystemEvent> Function(String dir);

enum WatchStatus {
  /// No watcher: the setting is off or the library is unavailable.
  off,

  /// Watching the folders of the library.
  watching,

  /// The inotify budget ran out, so nothing is watched until the setting is
  /// switched off and on again or the app restarts.
  limitReached,
}

/// `errno` of "no space left on device", which `inotify_add_watch` reports
/// when the user is out of watches.
const _enospc = 28;

/// Turns file system events in the library's folders into one call of
/// [onChange] per burst of changes: [quiet] after the last event, or at
/// latest [maxWait] after the first one of the burst.
///
/// The folders to watch come from [sync], called after every scan with the
/// folders that scan saw. One failing folder is dropped until the next
/// [sync]; running out of watches (or having more folders than [maxWatches])
/// drops them all and sets [WatchStatus.limitReached]. Pure of Flutter and
/// Riverpod; the watch and the timers are injected.
class FolderWatcher {
  FolderWatcher({
    required this._watch,
    required void Function() onChange,
    required this._maxWatches,
    TimerFactory timer = Timer.new,
    Duration quiet = const Duration(seconds: 3),
    Duration maxWait = const Duration(seconds: 60),
    Duration backoff = const Duration(seconds: 60),
  }) {
    _changes = ChangeDebouncer(
      onFire: onChange,
      isActive: () => !_disposed && _status == WatchStatus.watching,
      timer: timer,
      quiet: quiet,
      maxWait: maxWait,
      backoff: backoff,
    );
  }

  final DirWatch _watch;
  final int _maxWatches;
  late final ChangeDebouncer _changes;

  final Map<String, StreamSubscription<FileSystemEvent>> _subs = {};

  /// Folders that failed to be watched since the last [sync].
  final Set<String> _failed = {};
  final Set<StreamSubscription<FileSystemEntity>> _listings = {};
  final _statusController = StreamController<WatchStatus>.broadcast();
  WatchStatus _status = WatchStatus.watching;
  bool _disposed = false;

  WatchStatus get status => _status;

  /// Every change of [status].
  Stream<WatchStatus> get statusChanges => _statusController.stream;

  /// Number of folders watched right now.
  int get watchedCount => _subs.length;

  void _setStatus(WatchStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  /// Makes [dirs] the watched folders: the others are let go, folders that
  /// failed before get another chance.
  void sync(Iterable<String> dirs) {
    if (_disposed || _status != WatchStatus.watching) return;
    final wanted = dirs.toSet();
    _failed.clear();
    if (wanted.length > _maxWatches) {
      _giveUp('${wanted.length} folders, budget is $_maxWatches');
      return;
    }
    for (final dir in _subs.keys.toList()) {
      if (!wanted.contains(dir)) _drop(dir);
    }
    for (final dir in wanted) {
      if (_status != WatchStatus.watching) return;
      if (!_subs.containsKey(dir)) _attach(dir);
    }
  }

  /// Tells the watcher that a scan it asked for ended. A failed scan delays
  /// the next one by [backoff]; files left unread because they were still
  /// being written ([deferred]) get another scan.
  void scanEnded({required bool failed, required int deferred}) =>
      _changes.scanEnded(failed: failed, deferred: deferred);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _changes.dispose();
    await _cancelAll();
    _setStatus(WatchStatus.off);
    await _statusController.close();
  }

  // --- watches ---

  void _attach(String dir) {
    if (_failed.contains(dir) || _subs.containsKey(dir)) return;
    if (_subs.length >= _maxWatches) {
      _giveUp('more than $_maxWatches folders');
      return;
    }
    final Stream<FileSystemEvent> events;
    try {
      events = _watch(dir);
    } catch (error) {
      _onWatchError(dir, error);
      return;
    }
    late final StreamSubscription<FileSystemEvent> sub;
    sub = events.listen(
      (event) => _onEvent(event),
      onError: (Object error) => _onWatchError(dir, error),
      onDone: () {
        // Only a folder that closes by itself, not after an error (already
        // dropped) or a cancel, is a folder that went away.
        if (_disposed || !identical(_subs[dir], sub)) return;
        _subs.remove(dir);
        _changes.note();
      },
    );
    _subs[dir] = sub;
  }

  void _drop(String dir) {
    final sub = _subs.remove(dir);
    if (sub != null) unawaited(sub.cancel());
  }

  /// Lets go of [dir] and everything below it.
  void _dropTree(String dir) {
    for (final path in _subs.keys.toList()) {
      if (path == dir || path.startsWith('$dir/')) _drop(path);
    }
  }

  Future<void> _cancelAll() async {
    final subs = [..._subs.values, ..._listings];
    _subs.clear();
    _listings.clear();
    await Future.wait([for (final sub in subs) sub.cancel()]);
  }

  void _onWatchError(String dir, Object error) {
    if (_disposed) return;
    final code = error is FileSystemException ? error.osError?.errorCode : null;
    if (code == _enospc) {
      _giveUp('out of inotify watches');
      return;
    }
    // Permission denied, vanished folder or anything else: only this folder
    // is lost, and the stream closing after it is not a change.
    _log.fine('Cannot watch $dir: $error');
    _failed.add(dir);
    _drop(dir);
  }

  void _giveUp(String why) {
    _log.warning(
      'Folder watching stopped ($why). Raise fs.inotify.max_user_watches '
      'to watch the whole library.',
    );
    _changes.cancel();
    _setStatus(WatchStatus.limitReached);
    unawaited(_cancelAll());
  }

  /// Watches [dir] and its subfolders now, before the next scan publishes
  /// them: files copied into a new folder must not be missed.
  void _watchNewTree(String dir) {
    if (isSkippedFolder(dir)) return;
    _attach(dir);
    final prefix = dir.length;
    late final StreamSubscription<FileSystemEntity> listing;
    listing = Directory(dir)
        .list(recursive: true, followLinks: false)
        .listen(
          (entity) {
            if (entity is! Directory || _status != WatchStatus.watching) return;
            final below = entity.path.substring(prefix + 1).split('/');
            if (below.any((name) => isSkippedFolder('/$name'))) return;
            _attach(entity.path);
          },
          // A folder that cannot be listed is found by the next scan.
          onError: (Object _) {},
          onDone: () => _listings.remove(listing),
        );
    _listings.add(listing);
  }

  // --- events ---

  void _onEvent(FileSystemEvent event) {
    if (_disposed) return;
    final relevant = switch (event) {
      FileSystemCreateEvent() => _onCreated(event.path, event.isDirectory),
      FileSystemModifyEvent() =>
        event.contentChanged && isAudioFile(event.path),
      FileSystemDeleteEvent() => _onGone(event.path),
      FileSystemMoveEvent() => _onMoved(event),
    };
    if (relevant) _changes.note();
  }

  bool _isNomedia(String path) => path.endsWith('/$nomediaName');

  bool _onCreated(String path, bool isDirectory) {
    if (isDirectory) {
      if (isSkippedFolder(path)) return false;
      _watchNewTree(path);
      return true;
    }
    return isAudioFile(path) || _isNomedia(path);
  }

  /// A deleted entry: Dart reports it as a file even when it was a folder,
  /// so a watched path is a folder that went away.
  bool _onGone(String path) {
    final folder = _subs.containsKey(path);
    if (folder) _dropTree(path);
    return folder || isAudioFile(path) || _isNomedia(path);
  }

  bool _onMoved(FileSystemMoveEvent event) {
    final gone = _onGone(event.path);
    final destination = event.destination;
    if (destination == null) return gone;
    // The watch of a renamed folder still reports the old name.
    return _onCreated(destination, event.isDirectory) || gone;
  }
}
