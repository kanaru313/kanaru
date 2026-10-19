import 'dart:convert';
import 'dart:io';

import 'log_file_rotation.dart';

/// The log file of one session, unbuffered: every line is written to the
/// file at once, because nothing runs when the app quits to flush a buffer.
///
/// Several Kanaru processes can run at once (a Debug build next to an
/// installed one). The first one takes an exclusive lock on `kanaru.lock`
/// and owns the shared set: it rotates `kanaru.log` → `kanaru.log.1` …
/// `kanaru.log.<maxFiles - 1>` at startup and whenever the file grows past
/// [maxBytes]. The others write `kanaru-<pid>.log` and touch nothing else;
/// past [maxBytes] they keep one backup, `kanaru-<pid>.log.1`.
///
/// The lock sits on its own file because a lock follows the inode: on
/// `kanaru.log` it would move to `kanaru.log.1` with the rename.
///
/// POSIX locks belong to the process, not to the descriptor: closing ANY
/// descriptor of `kanaru.lock` in this process (copying or zipping the log
/// directory, a second [RotatingLogFile]) silently gives the lock up. Code
/// that reads the log directory, such as a log export, must skip
/// `kanaru.lock`.
///
/// When a rotation finds the log directory or the lock deleted behind its
/// back (`rm -rf ~/.cache`), it creates them again and takes the lock again.
/// Between rotations nothing is checked, so lines written after such a
/// deletion are lost until the file next fills up.
///
/// Never throws: an I/O error turns the sink off, and [failure] says why.
class RotatingLogFile {
  RotatingLogFile(
    this.directory, {
    this.maxFiles = 5,
    this.maxBytes = 10 * 1024 * 1024,
    this.header,
    int? processId,
  }) : _pid = processId ?? pid,
       _limit = maxBytes;

  static const sharedName = 'kanaru.log';
  static const lockName = 'kanaru.lock';

  /// How many `kanaru-<pid>.log` files of other instances to keep.
  static const keptInstanceFiles = 4;

  final String directory;

  /// Files of the shared set, the current one included.
  final int maxFiles;
  final int maxBytes;

  /// Written first in every file started by a rotation while the app runs,
  /// so each file says which version and process wrote it. The caller
  /// writes it itself at startup.
  final String? header;
  final int _pid;

  RandomAccessFile? _lock;
  RandomAccessFile? _out;
  int _size = 0;

  /// Size at which the next write rotates. Grows when a rotation fails, so
  /// a file that cannot be moved is not tried again on every line.
  int _limit;
  bool _ownsSharedSet = false;
  String _filePath = '';
  String _realDirectory = '';

  /// The file being written, `null` while the sink is off.
  String? get path => _out == null ? null : _filePath;

  /// The error that turned the sink off, if any.
  Object? failure;

  bool get isOpen => _out != null;

  /// Whether this process holds the lock and writes `kanaru.log`.
  bool get ownsSharedSet => _ownsSharedSet;

  /// Opens the sink. Returns whether it is on.
  bool open() {
    try {
      _prepare();
      if (_ownsSharedSet) {
        rotateNumbered(directory, sharedName, maxFiles);
        pruneInstanceFiles(directory, keptInstanceFiles);
      }
      _openOutput();
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  /// Appends [line] and a newline. Does nothing while the sink is off.
  /// Returns `false` when the sink is off, or turned off by this write.
  bool write(String line) {
    if (_out == null) return false;
    try {
      final bytes = utf8.encode('$line\n');
      if (_size > 0 && _size + bytes.length > _limit) _startOver();
      _append(bytes);
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  /// Closes the file and releases the lock.
  void close() {
    final out = _out;
    _out = null;
    _ownsSharedSet = false;
    try {
      out?.closeSync();
    } catch (_) {}
    _releaseLock();
  }

  /// Creates the directory, takes the lock if it is free and picks the file.
  void _prepare() {
    Directory(directory).createSync(recursive: true);
    _realDirectory = Directory(directory).resolveSymbolicLinksSync();
    _ownsSharedSet = _tryLock();
    _filePath =
        '$directory/${_ownsSharedSet ? sharedName : 'kanaru-$_pid.log'}';
  }

  bool _tryLock() {
    RandomAccessFile? lock;
    try {
      lock = File('$directory/$lockName').openSync(mode: FileMode.append);
      lock.lockSync(FileLock.exclusive); // Fails at once when held.
      _lock = lock;
      return true;
    } on FileSystemException {
      // Held by another process, or not even openable: write our own file.
      try {
        lock?.closeSync();
      } catch (_) {}
      return false;
    }
  }

  void _releaseLock() {
    final lock = _lock;
    _lock = null;
    try {
      lock?.closeSync(); // Closing releases the lock.
    } catch (_) {}
  }

  void _openOutput() {
    final out = File(_filePath).openSync(mode: FileMode.append);
    _out = out;
    _size = out.lengthSync();
  }

  void _append(List<int> bytes) {
    _out!.writeFromSync(bytes);
    _size += bytes.length;
  }

  /// The current file is full. The owner rotates the shared set, another
  /// instance moves its own file to `.1`. A rotation that cannot move a
  /// file leaves the current one in place and is tried again after another
  /// [maxBytes].
  void _startOver() {
    final names = _ownsSharedSet
        ? [lockName, sharedName]
        : [_filePath.substring(directory.length + 1)];
    final lost = holdsDeletedFile(_realDirectory, names);
    _out!.closeSync();
    _out = null;
    if (lost) {
      _releaseLock();
      _prepare();
    }
    final moved = _ownsSharedSet
        ? rotateNumbered(directory, sharedName, maxFiles)
        : keepOneBackup(_filePath);
    _openOutput();
    _limit = moved ? maxBytes : _size + maxBytes;
    final header = this.header;
    if (moved && header != null) _append(utf8.encode('$header\n'));
  }

  void _fail(Object error) {
    failure = error;
    close();
  }
}
