import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'plugin_log_paths.dart';
import 'plugin_run_log_event.dart';
import 'store/plugin_install_id.dart' show pluginInstallIdPattern;

export 'plugin_run_log_event.dart';

final _log = Logger('lyrics_plugin');

/// Largest size of `<installId>.jsonl` before it moves to `.jsonl.1`.
const pluginRunLogMaxBytes = 512 * 1024;

/// Writes the per-plugin JSON Lines files of [directory] (the caller gives
/// it; this class resolves no data path). A file is `<installId>.jsonl`,
/// appended one event per line through one serial writer per file, and moved
/// to `<installId>.jsonl.1` (replacing the older one) before it would pass
/// [maxBytes]. A write failure is logged once and swallowed: a log never
/// fails a lookup.
class PluginRunLog {
  PluginRunLog(this.directory, {this.maxBytes = pluginRunLogMaxBytes});

  final Directory directory;
  final int maxBytes;

  // Writes queue per file path, across instances.
  static final _tails = <String, Future<void>>{};

  // How many times the logs of an id were deleted. A write remembers the
  // number it was queued under and is dropped when the logs were deleted in
  // between; a write queued after the delete (a revived plugin keeps its id)
  // sees the new number and goes through.
  static final _deletions = <String, int>{};
  bool _reportedFailure = false;

  /// Completes when every write and delete queued so far has finished. The
  /// run code does not wait for its log writes; tests do.
  @visibleForTesting
  static Future<void> idle() => Future.wait(List.of(_tails.values));

  /// The file of [installId], or `null` when it is not a plugin id.
  File? fileOf(String installId) => pluginInstallIdPattern.hasMatch(installId)
      ? File('${directory.path}${Platform.pathSeparator}$installId.jsonl')
      : null;

  /// Adds [event] to the plugin's file with every [config] value of at least
  /// four characters replaced by `***`. Nothing is written for a run that
  /// neither failed nor printed, or that was cancelled. Completes after the
  /// write; never throws.
  Future<void> write(
    PluginRunLogEvent event, {
    Map<String, String> config = const {},
  }) {
    if (event.kind == pluginRunOkKind && event.console.isEmpty) {
      return Future.value();
    }
    // A run the user or an uninstall stopped is not a plugin fault.
    if (event.kind == pluginRunAbandonedKind) return Future.value();
    final file = fileOf(event.installId);
    if (file == null) return Future.value();
    final line = '${jsonEncode(event.toJson(config))}\n';
    final queuedUnder = _deletions[event.installId] ?? 0;
    return _enqueue(file, () async {
      if ((_deletions[event.installId] ?? 0) != queuedUnder) return;
      await _append(file, line);
    });
  }

  /// Deletes the plugin's log files inside the file's write queue. Writes
  /// queued before this call are dropped (not written and deleted after),
  /// so none can bring the file back; writes queued after it are written
  /// normally. Never throws.
  Future<void> deleteLogs(String installId) {
    final file = fileOf(installId);
    if (file == null) return Future.value();
    _deletions[installId] = (_deletions[installId] ?? 0) + 1;
    return _enqueue(file, () async {
      await deleteLyricsPluginLogs(
        directory,
        installId,
        onFailure: () => _reportFailure(const FileSystemException()),
      );
    });
  }

  Future<void> _enqueue(File file, Future<void> Function() job) {
    final previous = _tails[file.path] ?? Future<void>.value();
    final done = previous.then((_) => job());
    _tails[file.path] = done;
    return done.whenComplete(() {
      if (identical(_tails[file.path], done)) _tails.remove(file.path);
    });
  }

  void _reportFailure(Object e) {
    if (_reportedFailure) return;
    _reportedFailure = true;
    // The type only: the text would carry a path.
    _log.warning('Could not write a plugin log: ${e.runtimeType}');
  }

  Future<void> _append(File file, String line) async {
    try {
      await directory.create(recursive: true);
      final size = await file.exists() ? await file.length() : 0;
      if (size > 0 && size + utf8.encode(line).length > maxBytes) {
        final old = File('${file.path}.1');
        if (await old.exists()) await old.delete();
        await file.rename(old.path);
      }
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } on Object catch (e) {
      _reportFailure(e);
    }
  }
}
